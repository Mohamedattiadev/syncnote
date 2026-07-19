// AI service — OpenRouter streaming, mirrors Flutter version.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';

class ChatMsg {
  final String role;
  String content;
  ChatMsg(this.role, this.content);
}

class AiCfg {
  final String apiKey;
  final String model;
  final int maxTokens;
  const AiCfg({required this.apiKey, required this.model, this.maxTokens = 2048});
  bool get valid => apiKey.trim().startsWith('sk-or-');
}

/// Where the config was found — used by the status pane so user can debug
/// missing keys (env vs file vs missing).
enum AiSource { env, file, none }

AiSource lastAiSource = AiSource.none;

/// Loads AI config: multiple env var names → ~/.config/syncnote/ai.json.
AiCfg? loadAi() {
  // Try several env var names people commonly use
  const envNames = [
    'OPENROUTER_KEY',
    'OPENROUTER_API_KEY',
    'SYNCNOTE_OPENROUTER_KEY',
  ];
  String envKey = '';
  for (final name in envNames) {
    final v = Platform.environment[name];
    if (v != null && v.trim().isNotEmpty) {
      envKey = v.trim();
      break;
    }
  }
  final envModel =
      Platform.environment['OPENROUTER_MODEL'] ?? 'openai/gpt-4o-mini';
  if (envKey.isNotEmpty) {
    lastAiSource = AiSource.env;
    return AiCfg(apiKey: envKey, model: envModel);
  }
  final home = Platform.environment['HOME'] ?? '.';
  final f = File('$home/.config/syncnote/ai.json');
  if (!f.existsSync()) {
    lastAiSource = AiSource.none;
    return null;
  }
  try {
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    lastAiSource = AiSource.file;
    return AiCfg(
      apiKey: m['apiKey'] as String? ?? '',
      model: m['model'] as String? ?? 'openai/gpt-4o-mini',
      maxTokens: (m['maxTokens'] as int?) ?? 2048,
    );
  } catch (_) {
    lastAiSource = AiSource.none;
    return null;
  }
}

void saveAi(AiCfg cfg) {
  final home = Platform.environment['HOME'] ?? '.';
  final f = File('$home/.config/syncnote/ai.json');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(jsonEncode({
    'apiKey': cfg.apiKey,
    'model': cfg.model,
    'maxTokens': cfg.maxTokens,
  }));
}

Stream<String> streamChat(AiCfg cfg, List<ChatMsg> msgs) async* {
  final req = await HttpClient().postUrl(Uri.parse(_endpoint));
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Authorization', 'Bearer ${cfg.apiKey}');
  req.headers.set('HTTP-Referer', 'https://github.com/ati/syncnote');
  req.headers.set('X-Title', 'SyncNote CLI');
  req.write(jsonEncode({
    'model': cfg.model,
    'messages': msgs.map((m) => {'role': m.role, 'content': m.content}).toList(),
    'stream': true,
    'max_tokens': cfg.maxTokens,
  }));
  final resp = await req.close();
  if (resp.statusCode >= 400) {
    final body = await resp.transform(utf8.decoder).join();
    throw Exception('http ${resp.statusCode}: $body');
  }
  await for (final chunk in resp.transform(utf8.decoder)) {
    for (final line in chunk.split('\n')) {
      final t = line.trim();
      if (!t.startsWith('data:')) continue;
      final payload = t.substring(5).trim();
      if (payload == '[DONE]') return;
      if (payload.isEmpty) continue;
      try {
        final obj = jsonDecode(payload) as Map<String, dynamic>;
        final choices = obj['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta']
            as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } catch (_) {}
    }
  }
}
