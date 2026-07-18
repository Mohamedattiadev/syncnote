import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  const EditorScreen({super.key, this.note});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tagsCtrl;
  bool _dirty = false;
  bool _saving = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _tagsCtrl = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    for (final c in [_title, _body, _tagsCtrl]) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  /// Turn `- [ ] task` and `- [x] task` into markdown links so onTapLink fires.
  /// Each task line gets href `task:<lineIdx>`.
  String _renderChecklistLine(String text) {
    final lines = text.split('\n');
    final out = <String>[];
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i];
      final m = RegExp(r'^(\s*)-\s+\[( |x|X)\]\s+(.*)$').firstMatch(l);
      if (m == null) {
        out.add(l);
        continue;
      }
      final indent = m.group(1) ?? '';
      final done = (m.group(2) ?? ' ').toLowerCase() == 'x';
      final rest = m.group(3) ?? '';
      final box = done ? '☑' : '☐';
      final visual = done ? '~~$rest~~' : rest;
      out.add('$indent- [$box](task:$i) $visual');
    }
    return out.join('\n');
  }

  void _toggleTask(int lineIdx) {
    final lines = _body.text.split('\n');
    if (lineIdx < 0 || lineIdx >= lines.length) return;
    lines[lineIdx] = lines[lineIdx].replaceFirstMapped(
      RegExp(r'\[( |x|X)\]'),
      (m) => m.group(1) == ' ' ? '[x]' : '[ ]',
    );
    _body.text = lines.join('\n');
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepoProvider);
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (widget.note == null) {
        await repo.create(
          title: _title.text.trim(),
          body: _body.text,
          tags: tags,
        );
      } else {
        await repo.update(widget.note!.copyWith(
          title: _title.text.trim(),
          body: _body.text,
          tags: tags,
        ));
      }
      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('discard changes?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('keep editing')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('discard')),
            ],
          ),
        );
        if (!context.mounted) return;
        if (ok == true) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'new note' : 'edit'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check_box_outlined),
              tooltip: 'insert task',
              onPressed: () {
                final cur = _body.selection.baseOffset.clamp(0, _body.text.length);
                final t = _body.text;
                final prefix = t.substring(0, cur);
                final needsNewline = prefix.isNotEmpty && !prefix.endsWith('\n');
                final insertion = '${needsNewline ? '\n' : ''}- [ ] ';
                _body.text = prefix + insertion + t.substring(cur);
                _body.selection = TextSelection.collapsed(
                  offset: cur + insertion.length,
                );
                setState(() => _dirty = true);
              },
            ),
            IconButton(
              icon: Icon(_preview ? Icons.edit_note : Icons.visibility),
              tooltip: _preview ? 'edit' : 'preview',
              onPressed: () => setState(() => _preview = !_preview),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check, color: AppTheme.success),
                tooltip: 'save',
                onPressed: _save,
              ),
          ],
        ),
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          },
          child: Focus(
            autofocus: true,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'title',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Divider(color: AppTheme.overlay, height: 20),
                  TextField(
                    controller: _tagsCtrl,
                    decoration: const InputDecoration(
                      hintText: 'tags (comma-separated)',
                      prefixIcon: Icon(Icons.tag, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _preview
                        ? Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.overlay),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: SelectionArea(
                              child: Markdown(
                                data: _body.text.isEmpty
                                    ? '_(empty)_'
                                    : _renderChecklistLine(_body.text),
                                onTapLink: (text, href, title) {
                                  if (href != null && href.startsWith('task:')) {
                                    _toggleTask(int.parse(href.substring(5)));
                                  }
                                },
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                      color: AppTheme.text, height: 1.5),
                                  h1: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold),
                                  h2: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                  h3: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  code: const TextStyle(
                                      color: AppTheme.warning,
                                      backgroundColor: AppTheme.base,
                                      fontFamily: 'monospace'),
                                  codeblockDecoration: BoxDecoration(
                                    color: AppTheme.base,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  a: const TextStyle(
                                      color: AppTheme.primary,
                                      decoration:
                                          TextDecoration.underline),
                                  blockquoteDecoration: const BoxDecoration(
                                    border: Border(
                                        left: BorderSide(
                                            color: AppTheme.accent,
                                            width: 3)),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : TextField(
                            controller: _body,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(height: 1.5),
                            decoration: const InputDecoration(
                              hintText:
                                  'write your note (markdown supported)…',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
