import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/themes.dart';
import '../providers.dart';

class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(paletteIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in kAllPalettes)
          _ThemeTile(
            palette: p,
            selected: p.id == current,
            onTap: () async {
              ref.read(paletteIdProvider.notifier).state = p.id;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('palette_id', p.id);
            },
          ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? palette.primary.withValues(alpha: 0.15) : palette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? palette.primary : palette.overlay,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Swatches
                Row(
                  children: [
                    for (final c in [
                      palette.base,
                      palette.surface,
                      palette.primary,
                      palette.accent,
                      palette.success,
                      palette.warning,
                      palette.error,
                    ])
                      Container(
                        width: 14,
                        height: 32,
                        color: c,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.name,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        palette.id,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: palette.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
