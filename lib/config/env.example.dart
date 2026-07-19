// Rename to env.dart and fill in your Supabase project details.
// Or pass at build:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_YOUR_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && !supabaseUrl.contains('YOUR-');
}
