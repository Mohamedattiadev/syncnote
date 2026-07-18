import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'config/theme.dart';
import 'providers.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/setup_wizard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  runApp(const ProviderScope(child: SyncNoteApp()));
}

class SyncNoteApp extends ConsumerWidget {
  const SyncNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SyncNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();
  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _skipWizard = false;

  @override
  Widget build(BuildContext context) {
    // Not configured → wizard (or demo home if skipped).
    if (!Env.isConfigured) {
      return _skipWizard
          ? Stack(
              children: [
                const MainShell(),
                Positioned(
                  bottom: 16, right: 16,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.settings),
                    label: const Text('setup supabase'),
                    onPressed: () => setState(() => _skipWizard = false),
                  ),
                ),
              ],
            )
          : SetupWizardWithSkip(onSkip: () => setState(() => _skipWizard = true));
    }
    // Configured. Show login until signed in.
    final session = ref.watch(sessionProvider);
    return session != null ? const MainShell() : const LoginScreen();
  }
}

class SetupWizardWithSkip extends StatelessWidget {
  final VoidCallback onSkip;
  const SetupWizardWithSkip({super.key, required this.onSkip});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SetupWizard(),
        Positioned(
          top: 8, right: 8,
          child: TextButton.icon(
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('try demo mode'),
            onPressed: onSkip,
          ),
        ),
      ],
    );
  }
}
