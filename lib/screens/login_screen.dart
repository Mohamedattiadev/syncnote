import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final auth = ref.read(authProvider);
      if (auth == null) throw StateError('supabase not configured');
      if (_signUp) {
        await auth.signUpWithEmail(_email.text.trim(), _password.text);
      } else {
        await auth.signInWithEmail(_email.text.trim(), _password.text);
      }
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.note_alt_outlined, size: 56, color: AppTheme.primary),
                const SizedBox(height: 12),
                const Text('SyncNote',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('notes that sync everywhere',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(_err!, style: const TextStyle(color: AppTheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.base),
                        )
                      : Text(_signUp ? 'create account' : 'sign in'),
                ),
                TextButton(
                  onPressed: () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp ? 'have account? sign in' : 'need account? sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

