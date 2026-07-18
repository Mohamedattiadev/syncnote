// AI service — OpenRouter chat completions with streaming.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';

class OrModel {
  final String id;
  final String label;
  final String vendor;
  final String? note;
  const OrModel(this.id, this.label, this.vendor, {this.note});
}

/// Popular OpenRouter models — curated for the picker.
const kModels = <OrModel>[
  OrModel('anthropic/claude-3.5-haiku', 'Claude 3.5 Haiku', 'Anthropic', note: 'cheap + fast'),
  OrModel('anthropic/claude-3.5-sonnet', 'Claude 3.5 Sonnet', 'Anthropic', note: 'balanced'),
  OrModel('openai/gpt-4o-mini', 'GPT-4o mini', 'OpenAI', note: 'cheap'),
  OrModel('openai/gpt-4o', 'GPT-4o', 'OpenAI'),
  OrModel('google/gemini-flash-1.5', 'Gemini Flash 1.5', 'Google', note: 'very cheap'),
  OrModel('meta-llama/llama-3.3-70b-instruct', 'Llama 3.3 70B', 'Meta', note: 'open'),
  OrModel('deepseek/deepseek-chat', 'DeepSeek Chat', 'DeepSeek', note: 'cheapest'),
];

class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

class AiConfig {
  final String apiKey;
  final String model;
  final String? systemPrompt;

  const AiConfig({
    required this.apiKey,
    required this.model,
    this.systemPrompt,
  });

  bool get isValid => apiKey.trim().startsWith('sk-or-');

  AiConfig copyWith({String? apiKey, String? model, String? systemPrompt}) =>
      AiConfig(
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        systemPrompt: systemPrompt ?? this.systemPrompt,
      );
}

class AiService {
  final AiConfig config;
  AiService(this.config);

  Stream<String> chatStream(List<ChatMessage> history) async* {
    final msgs = <ChatMessage>[
      if (config.systemPrompt != null && config.systemPrompt!.isNotEmpty)
        ChatMessage('system', config.systemPrompt!),
      ...history,
    ];
    final req = http.Request('POST', Uri.parse(_endpoint));
    req.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
      'HTTP-Referer': 'https://github.com/ati/syncnote',
      'X-Title': 'SyncNote',
    });
    req.body = jsonEncode({
      'model': config.model,
      'messages': msgs.map((m) => m.toMap()).toList(),
      'stream': true,
      'max_tokens': 2048,
    });
    final client = http.Client();
    try {
      final resp = await client.send(req);
      if (resp.statusCode >= 400) {
        final body = await resp.stream.bytesToString();
        throw Exception('http ${resp.statusCode}: $body');
      }
      await for (final chunk in resp.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final t = line.trim();
          if (!t.startsWith('data:')) continue;
          final payload = t.substring(5).trim();
          if (payload == '[DONE]') return;
          if (payload.isEmpty) continue;
          try {
            final obj = jsonDecode(payload) as Map<String, dynamic>;
            final delta = ((obj['choices'] as List?)?.first
                as Map<String, dynamic>?)?['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}
