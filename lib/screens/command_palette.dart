// Command palette — Ctrl+K opens a fuzzy jump-to-anything overlay.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
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
  await showDialog(
    context: context,
    barrierColor: AppTheme.base.withValues(alpha: 0.85),
    builder: (_) => const _PaletteDialog(),
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
          Navigator.of(context).push(MaterialPageRoute(
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
          MaterialPageRoute(builder: (_) => EditorScreen(note: item.note)),
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

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Focus(
        onKeyEvent: (n, e) => _onKey(n, e, items),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
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
                        hintText: 'jump to note or run command…',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.overlay,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('esc',
                        style: TextStyle(
                            color: AppTheme.muted, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.overlay, height: 1),
            Flexible(
              child: items.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      child: const Text('no matches',
                          style: TextStyle(color: AppTheme.muted)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, i) => _Row(
                        item: items[i],
                        selected: i == _selected,
                        onTap: () => _execute(items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
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
      color: selected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: selected ? AppTheme.primary : AppTheme.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: AppTheme.text,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14)),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (item.kind == _ItemKind.command)
                Text('⌘',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
