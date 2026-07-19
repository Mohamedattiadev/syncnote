// Bottom-nav shell. Chat is the home tab.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import 'ai_chat_screen.dart';
import 'ai_settings_screen.dart';
import 'command_palette.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _idx = 0; // 0=chat, 1=notes, 2=tasks, 3=settings

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
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_idx),
                child: switch (_idx) {
                  0 => const AiChatScreen(),
                  1 => const HomeScreen(),
                  2 => const TasksScreen(),
                  _ => const AiSettingsScreen(),
                },
              ),
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
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        height: 62,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.overlay, width: 1),
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.auto_awesome_outlined,
              label: 'Chat',
              selected: current == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.article_outlined,
              label: 'Notes',
              selected: current == 1,
              onTap: () => onTap(1),
            ),
            _NavItem(
              icon: Icons.task_alt,
              label: 'Tasks',
              selected: current == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: current == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : AppTheme.muted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
                color: selected ? AppTheme.text : AppTheme.muted,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
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
