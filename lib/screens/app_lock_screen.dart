import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/app_lock.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _tryingAgain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attempt());
  }

  Future<void> _attempt() async {
    setState(() => _tryingAgain = true);
    final ok = await AppLock.unlock();
    if (ok && mounted) widget.onUnlocked();
    if (mounted) setState(() => _tryingAgain = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.overlay),
              ),
              child: const Icon(Icons.fingerprint, size: 56, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text('SyncNote is locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('unlock with biometrics',
                style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: Text(_tryingAgain ? 'unlocking…' : 'unlock'),
              onPressed: _tryingAgain ? null : _attempt,
            ),
          ],
        ),
      ),
    );
  }
}
