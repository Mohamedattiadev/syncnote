// Bottom-nav shell. Chat is the home tab.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import 'ai_chat_screen.dart';
import 'ai_settings_screen.dart';
import 'command_palette.dart';
import 'home_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _idx = 0; // 0=chat, 1=notes, 2=settings

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExit(context);
        if (ok && context.mounted) Navigator.of(context).maybePop();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              showCommandPalette(context, ref),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              showCommandPalette(context, ref),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: IndexedStack(
              index: _idx,
              children: const [
                AiChatScreen(),
                HomeScreen(),
                AiSettingsScreen(),
              ],
            ),
            bottomNavigationBar: _BottomNav(
              current: _idx,
              onTap: (i) => setState(() => _idx = i),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.overlay),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.auto_awesome_outlined,
              activeIcon: Icons.auto_awesome,
              label: 'chat',
              selected: current == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.notes_outlined,
              activeIcon: Icons.notes,
              label: 'notes',
              selected: current == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.tune,
              activeIcon: Icons.tune,
              label: 'settings',
              selected: current == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected ? AppTheme.base : AppTheme.muted,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.base : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmExit(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Row(
        children: [
          Icon(Icons.exit_to_app, color: AppTheme.warning),
          SizedBox(width: 8),
          Text('exit SyncNote?'),
        ],
      ),
      content: const Text('Your notes stay synced. You can come back anytime.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('stay'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('exit'),
        ),
      ],
    ),
  );
  return ok == true;
}
