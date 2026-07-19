// Command palette — Ctrl+K opens a fuzzy jump-to-anything overlay.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../widgets/fade_scale_route.dart';
import 'editor_screen.dart';

/// A single command in the palette.
class PaletteCommand {
  final String id;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback action;
  const PaletteCommand({
    required this.id,
    required this.icon,
    required this.label,
    required this.action,
    this.subtitle,
  });
}

/// Show as full-screen modal. Filters notes + built-in actions.
Future<void> showCommandPalette(BuildContext context, WidgetRef ref) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'palette',
    barrierColor: AppTheme.base.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, a, b) => const _PaletteDialog(),
    transitionBuilder: (_, anim, b, child) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
      child: FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
      ),
    ),
  );
}

class _PaletteDialog extends ConsumerStatefulWidget {
  const _PaletteDialog();
  @override
  ConsumerState<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends ConsumerState<_PaletteDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Item> _items(List<Note> notes) {
    final q = _query.text.trim().toLowerCase();
    final actions = <_Item>[
      _Item.command(PaletteCommand(
        id: 'new',
        icon: Icons.add_circle_outline,
        label: 'new note',
        subtitle: 'create a new note',
        action: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(FadeScalePageRoute(
              builder: (_) => const EditorScreen()));
        },
      )),
      _Item.command(PaletteCommand(
        id: 'sign_out',
        icon: Icons.logout,
        label: 'sign out',
        action: () async {
          Navigator.of(context).pop();
          await ref.read(authProvider)?.signOut();
        },
      )),
    ];
    final noteItems = notes.map((n) => _Item.note(n)).toList();
    var all = [...actions, ...noteItems];
    if (q.isNotEmpty) {
      all = all.where((i) => _matches(i, q)).toList();
      all.sort((a, b) => _score(b, q).compareTo(_score(a, q)));
    }
    return all;
  }

  bool _matches(_Item i, String q) {
    final s = i.searchable.toLowerCase();
    // fuzzy: every char in q must appear in order in s
    int idx = 0;
    for (final ch in q.characters) {
      final f = s.indexOf(ch, idx);
      if (f < 0) return false;
      idx = f + 1;
    }
    return true;
  }

  int _score(_Item i, String q) {
    final s = i.searchable.toLowerCase();
    if (s.startsWith(q)) return 100;
    if (s.contains(q)) return 60;
    return 10;
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e, List<_Item> items) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() =>
          _selected = (_selected + 1).clamp(0, items.length - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, items.length - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter && items.isNotEmpty) {
      _execute(items[_selected]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _execute(_Item item) {
    switch (item.kind) {
      case _ItemKind.command:
        item.command!.action();
        break;
      case _ItemKind.note:
        Navigator.of(context).pop();
        Navigator.of(context).push(
          FadeScalePageRoute(builder: (_) => EditorScreen(note: item.note)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final notes = notesAsync.asData?.value ?? const <Note>[];
    final items = _items(notes);
    _selected = _selected.clamp(0, items.isEmpty ? 0 : items.length - 1);

    final screen = MediaQuery.of(context).size;
    final maxW = 640.0;
    final maxH = screen.height * 0.6;
    // Build categorized item list with headers
    final actionItems = items.where((i) => i.kind == _ItemKind.command).toList();
    final noteItemsFiltered = items.where((i) => i.kind == _ItemKind.note).toList();

    return Align(
      alignment: const Alignment(0, -0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.overlay.withValues(alpha: 0.6), width: 1),
            ),
            child: Focus(
              onKeyEvent: (n, e) => _onKey(n, e, items),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppTheme.muted, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            focusNode: _focus,
                            onChanged: (_) => setState(() => _selected = 0),
                            style: const TextStyle(color: AppTheme.text, fontSize: 15),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              hintText: 'Jump to note or run command…',
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.overlay,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('esc',
                              style: TextStyle(color: AppTheme.muted, fontSize: 11, letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppTheme.overlay.withValues(alpha: 0.5)),
                  Flexible(
                    child: items.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(32),
                            child: const Text('no matches',
                                style: TextStyle(color: AppTheme.muted)),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              if (actionItems.isNotEmpty) ...[
                                const _SectionHeader('ACTIONS'),
                                ...actionItems.asMap().entries.map((e) => _Row(
                                      item: e.value,
                                      selected: items.indexOf(e.value) == _selected,
                                      onTap: () => _execute(e.value),
                                    )),
                              ],
                              if (noteItemsFiltered.isNotEmpty) ...[
                                const _SectionHeader('NOTES'),
                                ...noteItemsFiltered.map((it) => _Row(
                                      item: it,
                                      selected: items.indexOf(it) == _selected,
                                      onTap: () => _execute(it),
                                    )),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 160.ms).scaleXY(begin: 0.97, end: 1.0, duration: 200.ms, curve: Curves.easeOutCubic);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
      );
}

enum _ItemKind { command, note }

class _Item {
  final _ItemKind kind;
  final PaletteCommand? command;
  final Note? note;
  const _Item.command(PaletteCommand this.command)
      : kind = _ItemKind.command,
        note = null;
  const _Item.note(Note this.note)
      : kind = _ItemKind.note,
        command = null;

  String get searchable => kind == _ItemKind.command
      ? '${command!.label} ${command!.subtitle ?? ''}'
      : '${note!.title} ${note!.body} ${note!.tags.join(' ')}';
}

class _Row extends StatelessWidget {
  final _Item item;
  final bool selected;
  final VoidCallback onTap;
  const _Row({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = item.kind == _ItemKind.command
        ? item.command!.icon
        : (item.note!.kind == NoteKind.link
            ? Icons.link
            : item.note!.kind == NoteKind.file
                ? Icons.description_outlined
                : Icons.notes_outlined);
    final label = item.kind == _ItemKind.command
        ? item.command!.label
        : (item.note!.title.isEmpty ? '(untitled)' : item.note!.title);
    final subtitle = item.kind == _ItemKind.command
        ? item.command!.subtitle
        : item.note!.body.replaceAll('\n', ' ');

    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? AppTheme.primary : AppTheme.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.text,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14)),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Text('↵ open',
                    style: TextStyle(
                        color: AppTheme.primary.withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
