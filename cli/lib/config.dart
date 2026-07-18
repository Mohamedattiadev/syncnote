// Config loader — env vars → .env.local → lib/config/env.dart.

import 'dart:convert';
import 'dart:io';

class SupabaseConfig {
  final String url;
  final String key;
  const SupabaseConfig(this.url, this.key);
}

class Env {
  static SupabaseConfig load() {
    var url = Platform.environment['SUPABASE_URL'] ?? '';
    var key = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || key.isEmpty) {
      for (final p in ['.env.local', '../.env.local']) {
        final f = File(p);
        if (!f.existsSync()) continue;
        for (final line in f.readAsLinesSync()) {
          final t = line.trim();
          if (t.isEmpty || t.startsWith('#')) continue;
          final i = t.indexOf('=');
          if (i < 0) continue;
          final k = t.substring(0, i).trim();
          final v = t.substring(i + 1).trim();
          if (k == 'SUPABASE_URL' && url.isEmpty) url = v;
          if (k == 'SUPABASE_ANON_KEY' && key.isEmpty) key = v;
        }
        if (url.isNotEmpty && key.isNotEmpty) break;
      }
    }

    if (url.isEmpty || key.isEmpty) {
      for (final p in ['lib/config/env.dart', '../lib/config/env.dart']) {
        final f = File(p);
        if (!f.existsSync()) continue;
        final src = f.readAsStringSync();
        final u = RegExp(r"'(https://[^']+\.supabase\.co)'").firstMatch(src);
        final k = RegExp(r"'(sb_publishable_[^']+|eyJ[^']+)'").firstMatch(src);
        if (url.isEmpty && u != null) url = u.group(1)!;
        if (key.isEmpty && k != null) key = k.group(1)!;
        if (url.isNotEmpty && key.isNotEmpty) break;
      }
    }

    if (url.isEmpty || url.contains('YOUR-') || key.isEmpty) {
      stderr.writeln('SyncNote CLI: missing Supabase config.');
      stderr.writeln('run ./setup.sh at repo root, or set SUPABASE_URL + SUPABASE_ANON_KEY');
      exit(2);
    }
    return SupabaseConfig(url, key);
  }
}

class TokenStore {
  final String path;
  TokenStore(this.path);

  factory TokenStore.userScope() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return TokenStore('$home/.config/syncnote/session.json');
  }

  File get _f => File(path);

  Map<String, dynamic>? read() {
    if (!_f.existsSync()) return null;
    try {
      return jsonDecode(_f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void write(Map<String, dynamic> data) {
    _f.parent.createSync(recursive: true);
    _f.writeAsStringSync(jsonEncode(data));
  }

  void clear() {
    if (_f.existsSync()) _f.deleteSync();
  }
}
