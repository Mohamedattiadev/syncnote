// Icon-only left navigation rail for wide screens. Fabric-inspired.
//
// Sections: Chat · Notes · Tasks · Stats · Settings
// Avatar top, sign-out bottom. Labels appear on hover as tooltips.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers.dart';

class LeftRail extends ConsumerWidget {
  final int current;
  final ValueChanged<int> onTap;
  final int noteBadge;
  final int taskBadge;
  const LeftRail({
    super.key,
    required this.current,
    required this.onTap,
    this.noteBadge = 0,
    this.taskBadge = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth?.user;
    final initial = _initialFor(user?.email);
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.overlay, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            _Avatar(initial: initial),
            const SizedBox(height: 24),
            _RailIcon(
              icon: Icons.auto_awesome_outlined,
              label: 'Chat',
              selected: current == 0,
              onTap: () => onTap(0),
            ),
            _RailIcon(
              icon: Icons.article_outlined,
              label: 'Notes',
              selected: current == 1,
              badge: noteBadge > 0 ? noteBadge : null,
              onTap: () => onTap(1),
            ),
            _RailIcon(
              icon: Icons.task_alt,
              label: 'Tasks',
              selected: current == 2,
              badge: taskBadge > 0 ? taskBadge : null,
              onTap: () => onTap(2),
            ),
            _RailIcon(
              icon: Icons.bar_chart_rounded,
              label: 'Stats',
              selected: current == 3,
              onTap: () => onTap(3),
            ),
            _RailIcon(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: current == 4,
              onTap: () => onTap(4),
            ),
            const Spacer(),
            _RailIcon(
              icon: Icons.logout,
              label: 'Sign out',
              selected: false,
              onTap: () => auth?.signOut(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _initialFor(String? email) {
    if (email == null || email.isEmpty) return '?';
    return email.substring(0, 1).toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  const _Avatar({required this.initial});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.overlay,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppTheme.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  const _RailIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
              if (badge != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 12, minHeight: 12),
                    child: Text(
                      badge! > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: AppTheme.base,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
