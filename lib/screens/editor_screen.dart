// Editor — Notion-block layout.
//   * No appbar in focus mode (minimal floating focus toggle only).
//   * 24pt semi-bold title, tracking -0.01em, auto-focus on empty note.
//   * Body line-height 1.7 for breathe.
//   * Tags as chip-list at BOTTOM.
//   * Meta footer sticky at bottom with wider padding.
//   * Floating pill toolbar above keyboard on mobile.

import 'dart:async';

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
  late final FocusNode _titleFocus;
  late final FocusNode _bodyFocus;
  bool _dirty = false;
  bool _saving = false;
  bool _preview = false;
  bool _focusMode = false;
  Timer? _autoSaveTimer;
  DateTime? _lastSaved;
  Note? _editingNote; // real-time updated after auto-save

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _tagsCtrl = TextEditingController(text: widget.note?.tags.join(', ') ?? '');
    _titleFocus = FocusNode();
    _bodyFocus = FocusNode();
    _editingNote = widget.note;
    for (final c in [_title, _body, _tagsCtrl]) {
      c.addListener(_onEdit);
    }
    // Auto-focus title on new/empty note.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = widget.note?.title ?? '';
      if (t.trim().isEmpty) {
        _titleFocus.requestFocus();
      }
    });
  }

  void _onEdit() {
    if (!_dirty) setState(() => _dirty = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 700), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_saving) return;
    final title = _title.text.trim();
    final bodyText = _body.text;
    if (title.isEmpty && bodyText.trim().isEmpty) return;
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    try {
      final repo = ref.read(notesRepoProvider);
      if (_editingNote == null || _editingNote!.id == 'draft') {
        final created = await repo.create(
          title: title,
          body: bodyText,
          tags: tags,
        );
        setState(() {
          _editingNote = created;
          _dirty = false;
          _lastSaved = DateTime.now();
        });
      } else {
        await repo.update(_editingNote!.copyWith(
          title: title,
          body: bodyText,
          tags: tags,
        ));
        setState(() {
          _dirty = false;
          _lastSaved = DateTime.now();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_dirty) unawaited(_autoSave());
    _title.dispose();
    _body.dispose();
    _tagsCtrl.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

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

  void _wrap(String before, String after) {
    final sel = _body.selection;
    final text = _body.text;
    if (!sel.isValid) return;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final selected = text.substring(start, end);
    final replacement = '$before$selected$after';
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
          offset: start + before.length + selected.length),
    );
    setState(() => _dirty = true);
  }

  void _prefixLine(String prefix) {
    final text = _body.text;
    final cur = _body.selection.baseOffset.clamp(0, text.length);
    var lineStart = cur;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    _body.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: cur + prefix.length),
    );
    setState(() => _dirty = true);
  }

  String _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '0 w';
    final words = trimmed.split(RegExp(r'\s+')).length;
    final readMin = (words / 200).ceil();
    return '$words w · ${readMin}m read';
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
    final isWide = MediaQuery.of(context).size.width >= 900;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('discard changes?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('keep editing')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('discard')),
            ],
          ),
        );
        if (!context.mounted) return;
        if (ok == true) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: _focusMode
            ? null
            : AppBar(
                title: Row(
                  children: [
                    Text(widget.note == null ? 'new note' : 'edit'),
                    const SizedBox(width: 8),
                    Text(
                      _wordCount(_body.text),
                      style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  _SaveStatus(
                      dirty: _dirty, lastSaved: _lastSaved, saving: _saving),
                  const SizedBox(width: 4),
                  if (_editingNote != null)
                    IconButton(
                      icon: Icon(
                        _editingNote!.pinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color:
                            _editingNote!.pinned ? AppTheme.warning : null,
                      ),
                      tooltip: _editingNote!.pinned ? 'unpin' : 'pin',
                      onPressed: () async {
                        final updated = _editingNote!
                            .copyWith(pinned: !_editingNote!.pinned);
                        setState(() => _editingNote = updated);
                        await ref
                            .read(notesRepoProvider)
                            .update(updated);
                      },
                    ),
                  IconButton(
                    icon: Icon(_preview ? Icons.edit_note : Icons.visibility),
                    tooltip: _preview ? 'edit' : 'preview',
                    onPressed: () => setState(() => _preview = !_preview),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'focus mode',
                    onPressed: () => setState(() => _focusMode = true),
                  ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary),
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
        bottomNavigationBar: (_editingNote == null || _focusMode)
            ? null
            : _MetaFooter(note: _editingNote!),
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _save,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
                _wrap('**', '**'),
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
                _wrap('**', '**'),
            const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
                _wrap('_', '_'),
            const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
                _wrap('_', '_'),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                _wrap('[', '](url)'),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
                _wrap('[', '](url)'),
            const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
                setState(() => _preview = !_preview),
            const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () =>
                setState(() => _preview = !_preview),
          },
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxContent = isWide ? 780.0 : constraints.maxWidth;
                    final horizPad = isWide ? 32.0 : 20.0;
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContent),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                              horizPad,
                              _focusMode ? 24 : 16,
                              horizPad,
                              120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Hero(
                                tag:
                                    'note-title-${widget.note?.id ?? "new"}',
                                flightShuttleBuilder:
                                    (_, _, _, _, _) => Material(
                                  color: Colors.transparent,
                                  child: Text(
                                    _title.text.isEmpty
                                        ? 'Untitled'
                                        : _title.text,
                                    style: const TextStyle(
                                        color: AppTheme.text,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.24),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: TextField(
                                    controller: _title,
                                    focusNode: _titleFocus,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.24,
                                        height: 1.25),
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _bodyFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                      hintText: 'Untitled',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: AppTheme.overlay
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 20),
                              _preview
                                  ? _buildPreview()
                                  : TextField(
                                      controller: _body,
                                      focusNode: _bodyFocus,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.7,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Start writing…',
                                        hintStyle: TextStyle(
                                          color: AppTheme.muted
                                              .withValues(alpha: 0.6),
                                          height: 1.7,
                                          fontSize: 16,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                              const SizedBox(height: 32),
                              _TagsChipInput(controller: _tagsCtrl),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_focusMode)
                Positioned(
                  top: 12,
                  right: 12,
                  child: SafeArea(
                    child: Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(9999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9999),
                        onTap: () => setState(() => _focusMode = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: AppTheme.overlay),
                          ),
                          child: const Icon(Icons.fullscreen_exit,
                              color: AppTheme.muted, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_focusMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Center(child: _FloatingToolbar(
                        onBold: () => _wrap('**', '**'),
                        onItalic: () => _wrap('_', '_'),
                        onCode: () => _wrap('`', '`'),
                        onH: () => _prefixLine('## '),
                        onList: () => _prefixLine('- '),
                        onTask: () => _prefixLine('- [ ] '),
                        onLink: () => _wrap('[', '](url)'),
                      )),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.overlay),
      ),
      padding: const EdgeInsets.all(20),
      child: SelectionArea(
        child: Markdown(
          data: _body.text.isEmpty
              ? '_(empty)_'
              : _renderChecklistLine(_body.text),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          onTapLink: (text, href, title) {
            if (href != null && href.startsWith('task:')) {
              _toggleTask(int.parse(href.substring(5)));
            }
          },
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: AppTheme.text, fontSize: 16, height: 1.7),
            h1: const TextStyle(
                color: AppTheme.accent,
                fontSize: 28,
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
              borderRadius: BorderRadius.circular(8),
            ),
            a: const TextStyle(
                color: AppTheme.primary,
                decoration: TextDecoration.underline),
            blockquoteDecoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: AppTheme.accent, width: 4)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingToolbar extends StatelessWidget {
  final VoidCallback onBold, onItalic, onCode, onH, onList, onTask, onLink;
  const _FloatingToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onCode,
    required this.onH,
    required this.onList,
    required this.onTask,
    required this.onLink,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppTheme.overlay),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(Icons.format_bold, 'bold', onBold),
          _pill(Icons.format_italic, 'italic', onItalic),
          _pill(Icons.code, 'code', onCode),
          _pill(Icons.title, 'heading', onH),
          _pill(Icons.format_list_bulleted, 'list', onList),
          _pill(Icons.check_box_outlined, 'task', onTask),
          _pill(Icons.link, 'link', onLink),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      color: AppTheme.text,
    );
  }
}

class _TagsChipInput extends StatefulWidget {
  final TextEditingController controller;
  const _TagsChipInput({required this.controller});
  @override
  State<_TagsChipInput> createState() => _TagsChipInputState();
}

class _TagsChipInputState extends State<_TagsChipInput> {
  bool _adding = false;
  final _addCtrl = TextEditingController();

  List<String> _parse() => widget.controller.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  void _write(List<String> tags) {
    widget.controller.text = tags.join(', ');
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _parse();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final t in tags)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppTheme.overlay),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('#$t',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(
                      () => _write(tags.where((x) => x != t).toList())),
                  borderRadius: BorderRadius.circular(9999),
                  child: const Icon(Icons.close,
                      size: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        if (_adding)
          SizedBox(
            width: 140,
            child: TextField(
              controller: _addCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'new tag',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: (v) {
                final t = v.trim();
                if (t.isNotEmpty && !tags.contains(t)) {
                  tags.add(t);
                  _write(tags);
                }
                _addCtrl.clear();
                setState(() => _adding = false);
              },
            ),
          )
        else
          InkWell(
            onTap: () => setState(() => _adding = true),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: AppTheme.overlay),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 12, color: AppTheme.muted),
                  SizedBox(width: 4),
                  Text('add tag',
                      style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SaveStatus extends StatelessWidget {
  final bool dirty;
  final bool saving;
  final DateTime? lastSaved;
  const _SaveStatus(
      {required this.dirty, required this.saving, this.lastSaved});
  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;
    if (saving) {
      icon = Icons.sync;
      color = AppTheme.warning;
      tooltip = 'saving…';
    } else if (dirty) {
      icon = Icons.edit;
      color = AppTheme.muted;
      tooltip = 'unsaved (auto-save in a moment)';
    } else {
      icon = Icons.check_circle_outline;
      color = AppTheme.success;
      tooltip = lastSaved == null ? 'saved' : 'saved · ${_fmt(lastSaved!)}';
    }
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  static String _fmt(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _MetaFooter extends StatelessWidget {
  final Note note;
  const _MetaFooter({required this.note});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.overlay)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 12, color: AppTheme.muted),
            const SizedBox(width: 4),
            Text('updated ${_ago(note.updatedAt)}',
                style: const TextStyle(
                    color: AppTheme.muted, fontSize: 12)),
            const SizedBox(width: 16),
            const Icon(Icons.tag, size: 12, color: AppTheme.muted),
            const SizedBox(width: 4),
            Text('${note.tags.length}',
                style: const TextStyle(
                    color: AppTheme.muted, fontSize: 12)),
            const Spacer(),
            Text(note.id.length >= 8 ? note.id.substring(0, 8) : note.id,
                style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
