import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'models/note.dart';
import 'services/ai.dart';
import 'services/ai_settings.dart';
import 'services/auth.dart';
import 'services/mock_repo.dart';
import 'services/notes_repo.dart';

final supabaseProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.isConfigured) return null;
  return Supabase.instance.client;
});

final authProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client == null) return null;
  return AuthService(client);
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth == null) return const Stream.empty();
  return auth.changes;
});

final sessionProvider = Provider<Session?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth == null) return null;
  final state = ref.watch(authStateProvider);
  return state.asData?.value?.session ?? auth.session;
});

/// Repo — real Supabase if configured + signed in, else in-memory demo.
final notesRepoProvider = Provider<NotesRepo>((ref) {
  final client = ref.watch(supabaseProvider);
  if (client != null && client.auth.currentUser != null) {
    return SupabaseNotesRepo(client);
  }
  return MockRepoAdapter(MockNotesRepo());
});

final notesStreamProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(notesRepoProvider).watchAll(),
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final paletteIdProvider = StateProvider<String>((ref) => 'doom-one');

final aiSettingsStoreProvider = Provider<AiSettingsStore>((ref) => AiSettingsStore());

final aiConfigProvider = FutureProvider<AiConfig?>((ref) async {
  return ref.watch(aiSettingsStoreProvider).load();
});

final aiServiceProvider = Provider<AiService?>((ref) {
  final cfg = ref.watch(aiConfigProvider).asData?.value;
  if (cfg == null || !cfg.isValid) return null;
  return AiService(cfg);
});
