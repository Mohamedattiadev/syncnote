import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai.dart';

class AiSettingsStore {
  static const _key = 'ai_config_v2';

  Future<AiConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AiConfig(
        apiKey: m['apiKey'] as String? ?? '',
        model: m['model'] as String? ?? kModels.first.id,
        systemPrompt: m['systemPrompt'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AiConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'apiKey': cfg.apiKey,
        'model': cfg.model,
        'systemPrompt': cfg.systemPrompt,
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
