import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;
  AuthService(this._client);

  Session? get session => _client.auth.currentSession;
  User? get user => _client.auth.currentUser;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signUpWithEmail(String email, String password) =>
      _client.auth.signUp(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();
}
