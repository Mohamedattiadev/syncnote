import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../services/ai.dart';
import '../services/ai_actions.dart';
import '../services/rag.dart';
import 'ai_settings_screen.dart';
import 'editor_screen.dart';

enum ChatMode { notes, web }

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});
  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  bool _busy = false;
  String? _streaming;
  String? _err;
  ChatMode _mode = ChatMode.notes;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    // Quick-save commands — no LLM needed
    if (text.startsWith('/note ') || text.startsWith('/save ')) {
      final rest = text.substring(6).trim();
      final firstNewline = rest.indexOf('\n');
      final title = firstNewline < 0 ? rest : rest.substring(0, firstNewline);
      final body = firstNewline < 0 ? '' : rest.substring(firstNewline + 1);
      await _quickSave(title, body);
      setState(() => _input.clear());
      return;
    }

    // Natural-language note creation intent — parse before LLM
    final intent = _parseNoteIntent(text);
    if (intent != null) {
      await _quickSave(intent.$1, intent.$2);
      setState(() {
        _messages.add(ChatMessage('user', text));
        _messages.add(ChatMessage(
          'assistant',
          '✓ Created note **${intent.$1}**${intent.$2.isNotEmpty ? ' with content: ${intent.$2}' : ''}.\n\n_You can find it in the notes tab._',
        ));
        _input.clear();
      });
      _scrollDown();
      return;
    }
    final aiBase = ref.read(aiServiceProvider);
    if (aiBase == null) {
      _openSettings();
      return;
    }
    setState(() {
      _messages.add(ChatMessage('user', text));
      _input.clear();
      _busy = true;
      _streaming = '';
      _err = null;
    });
    _scrollDown();
    try {
      // Build effective service with mode-specific system prompt.
      AiService effective = aiBase;
      if (_mode == ChatMode.notes) {
        final notes = await ref.read(notesRepoProvider).fetchAll();
        final sys = const RagBuilder().buildSystemPrompt(text, notes);
        effective = AiService(AiConfig(
          apiKey: aiBase.config.apiKey,
          model: aiBase.config.model,
          systemPrompt: sys,
        ));
      }
      final buf = StringBuffer();
      await for (final delta in effective.chatStream(_messages)) {
        buf.write(delta);
        if (!mounted) return;
        setState(() => _streaming = buf.toString());
        _scrollDown();
      }
      // Parse + execute AI actions embedded in reply
      final runner = AiActionRunner(ref.read(notesRepoProvider));
      final actions = runner.parse(buf.toString());
      String finalReply = buf.toString();
      if (actions.isNotEmpty) {
        final summary = await runner.execute(actions);
        finalReply = runner.stripBlocks(finalReply);
        if (summary.isNotEmpty) {
          finalReply = '$finalReply\n\n_${summary}_';
        }
      }
      setState(() {
        _messages.add(ChatMessage('assistant', finalReply.trim()));
        _streaming = null;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
        _streaming = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retry() {
    if (_messages.isEmpty || _busy) return;
    // Drop last assistant, resend last user
    if (_messages.last.role == 'assistant') {
      setState(() => _messages.removeLast());
    }
    final lastUser = _messages.lastWhere(
      (m) => m.role == 'user',
      orElse: () => const ChatMessage('user', ''),
    );
    if (lastUser.content.isNotEmpty) {
      _messages.removeLast();
      _send(lastUser.content);
    }
  }

  /// Detect "create note with name X, content Y" style patterns.
  /// Returns (title, body) or null.
  (String, String)? _parseNoteIntent(String text) {
    final t = text.trim();
    // "create/make/save note with name/title X, content/body Y"
    final full = RegExp(
      r'^(?:create|make|save|add|new)\s+(?:a\s+)?note\s+(?:with\s+)?(?:name|title|called|named)\s+["`‘’]?([^",\n‘’]+?)["`‘’]?\s*(?:,\s*(?:with\s+)?(?:content|body|text)\s+["`]?(.+?)["`]?)?\s*$',
      caseSensitive: false,
      dotAll: true,
    );
    var m = full.firstMatch(t);
    if (m != null) {
      final title = (m.group(1) ?? '').trim();
      final body = (m.group(2) ?? '').trim();
      if (title.isNotEmpty) return (title, body);
    }
    // "note this: <body>" or "save this: <body>"
    final quick = RegExp(
      r'^(?:note|save)\s+this[:\s]+(.+)$',
      caseSensitive: false,
      dotAll: true,
    );
    m = quick.firstMatch(t);
    if (m != null) {
      final body = (m.group(1) ?? '').trim();
      if (body.isNotEmpty) {
        final title = body.length > 40 ? '${body.substring(0, 40)}…' : body;
        return (title, body);
      }
    }
    return null;
  }

  Future<void> _quickSave(String title, String body) async {
    try {
      await ref.read(notesRepoProvider).create(
            title: title.isEmpty ? 'AI note' : title,
            body: body,
            kind: NoteKind.note,
            tags: const ['ai'],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text('✓ saved note: ${title.isEmpty ? "AI note" : title}',
                style: const TextStyle(color: AppTheme.base)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('save failed: $e')),
        );
      }
    }
  }

  Future<void> _saveMessageAsNote(String content, {String? suggestedTitle}) async {
    final ctrl = TextEditingController(text: suggestedTitle ?? _extractTitle(content));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('save as note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('save')),
        ],
      ),
    );
    if (ok == true) {
      await _quickSave(ctrl.text.trim(), content);
    }
  }

  String _extractTitle(String content) {
    final firstLine = content.split('\n').first.trim();
    if (firstLine.startsWith('#')) {
      return firstLine.replaceAll(RegExp(r'^#+\s*'), '').trim();
    }
    return firstLine.length > 60 ? firstLine.substring(0, 60) : firstLine;
  }

  Future<void> _editAsNote(String content) async {
    final title = _extractTitle(content);
    final now = DateTime.now().toUtc();
    final draft = Note(
      id: 'draft',
      userId: '',
      title: title,
      body: content,
      kind: NoteKind.note,
      tags: const ['ai'],
      createdAt: now,
      updatedAt: now,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(note: draft)),
    );
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
    );
  }

  Future<void> _changeModel() async {
    final cfg = await ref.read(aiSettingsStoreProvider).load();
    if (cfg == null || !mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: kModels.map((m) => ListTile(
              title: Text(m.label),
              subtitle: Text('${m.vendor} · ${m.id}',
                  style: const TextStyle(fontSize: 11)),
              trailing: cfg.model == m.id
                  ? const Icon(Icons.check, color: AppTheme.success)
                  : null,
              onTap: () async {
                await ref
                    .read(aiSettingsStoreProvider)
                    .save(cfg.copyWith(model: m.id));
                ref.invalidate(aiConfigProvider);
                if (mounted) Navigator.of(context).pop();
              },
            )).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiServiceProvider);
    final cfg = ref.watch(aiConfigProvider).asData?.value;
    final currentModel = kModels.firstWhere(
      (m) => m.id == cfg?.model,
      orElse: () => kModels.first,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _changeModel,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentModel.label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('tap to change',
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 10)),
                  ],
                ),
                const Icon(Icons.arrow_drop_down, color: AppTheme.muted),
              ],
            ),
          ),
        ),
        actions: [
          _ModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(width: 8),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: 'new chat',
              onPressed: () => setState(() {
                _messages.clear();
                _streaming = null;
                _err = null;
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          if (ai == null)
            _NotConfiguredBanner(onConfigure: _openSettings),
          Expanded(
            child: _messages.isEmpty && _streaming == null
                ? _EmptyChat(onPick: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    itemCount:
                        _messages.length + (_streaming != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i < _messages.length) {
                        return _Bubble(
                          msg: _messages[i],
                          onCopy: () => Clipboard.setData(
                              ClipboardData(text: _messages[i].content)),
                          onRetry: i == _messages.length - 1 &&
                                  _messages[i].role == 'assistant'
                              ? _retry
                              : null,
                          onSaveNote: _messages[i].role == 'assistant'
                              ? () => _saveMessageAsNote(_messages[i].content)
                              : null,
                        );
                      }
                      return _Bubble(
                        msg: ChatMessage('assistant', _streaming ?? ''),
                        streaming: true,
                      );
                    },
                  ),
          ),
          if (_err != null)
            _ErrorBar(err: _err!, onDismiss: () => setState(() => _err = null)),
          _Composer(
            controller: _input,
            enabled: !_busy && ai != null,
            busy: _busy,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredBanner extends StatelessWidget {
  final VoidCallback onConfigure;
  const _NotConfiguredBanner({required this.onConfigure});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.warning.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onConfigure,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: const [
              Icon(Icons.key, color: AppTheme.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add your OpenRouter API key to start chatting',
                  style: TextStyle(color: AppTheme.text),
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool streaming;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onSaveNote;
  const _Bubble({
    required this.msg,
    this.streaming = false,
    this.onCopy,
    this.onRetry,
    this.onSaveNote,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.accent,
                  child: Icon(Icons.auto_awesome,
                      size: 14, color: AppTheme.base),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser ? AppTheme.primary : AppTheme.overlay,
                    ),
                  ),
                  child: isUser
                      ? SelectableText(
                          msg.content,
                          style: const TextStyle(
                              color: AppTheme.base, height: 1.4),
                        )
                      : SelectionArea(
                          child: Markdown(
                            data: msg.content + (streaming ? '▍' : ''),
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: AppTheme.text, height: 1.5),
                              code: const TextStyle(
                                  color: AppTheme.warning,
                                  backgroundColor: AppTheme.base,
                                  fontFamily: 'monospace'),
                              codeblockDecoration: BoxDecoration(
                                color: AppTheme.base,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              blockquoteDecoration: const BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        color: AppTheme.accent, width: 3)),
                              ),
                              a: const TextStyle(
                                  color: AppTheme.primary,
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.person, size: 14, color: AppTheme.base),
                ),
              ],
            ],
          ),
          if (!isUser && !streaming)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Row(
                children: [
                  if (onCopy != null)
                    _MsgAction(icon: Icons.copy_outlined, label: 'copy', onTap: onCopy!),
                  if (onSaveNote != null) ...[
                    const SizedBox(width: 12),
                    _MsgAction(
                        icon: Icons.bookmark_add_outlined,
                        label: 'save as note',
                        onTap: onSaveNote!),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(width: 12),
                    _MsgAction(
                        icon: Icons.refresh, label: 'retry', onTap: onRetry!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MsgAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MsgAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.muted),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final Function(String) onPick;
  const _EmptyChat({required this.onPick});

  static const _presets = [
    (Icons.lightbulb_outline, 'brainstorm ideas for…'),
    (Icons.summarize_outlined, 'summarize my notes'),
    (Icons.bookmark_add_outlined, '/note Groceries\nmilk, eggs, bread'),
    (Icons.school_outlined, 'explain X in simple terms'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 40, color: AppTheme.accent),
            ),
            const SizedBox(height: 16),
            const Text('Ask me anything',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Chat streams live · markdown supported · retry & copy',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _presets
                  .map((p) => ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(p.$1, size: 14, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            Text(p.$2),
                          ],
                        ),
                        backgroundColor: AppTheme.surface,
                        side: const BorderSide(color: AppTheme.overlay),
                        onPressed: () => onPick(p.$2),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String err;
  final VoidCallback onDismiss;
  const _ErrorBar({required this.err, required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.error.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(err,
                style: const TextStyle(color: AppTheme.error, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final ChatMode mode;
  final ValueChanged<ChatMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.overlay),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('notes', Icons.folder_outlined, ChatMode.notes),
          _seg('web', Icons.public, ChatMode.web),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, ChatMode m) {
    final selected = mode == m;
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon,
                  size: 14,
                  color: selected ? AppTheme.base : AppTheme.muted),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.base : AppTheme.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final Function([String?]) onSend;
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.overlay)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLines: 5,
                minLines: 1,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'ask AI · try /note <title> to save fast'
                      : 'add API key first',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: IconButton(
                      icon: const Icon(Icons.attach_file, size: 18),
                      tooltip: 'save current draft as note',
                      onPressed: enabled && controller.text.trim().isNotEmpty
                          ? () {
                              final t = controller.text.trim();
                              onSend('/note $t');
                            }
                          : null,
                    ),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => controller.clear(),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                heroTag: 'send',
                mini: false,
                backgroundColor:
                    enabled ? AppTheme.primary : AppTheme.overlay,
                foregroundColor: AppTheme.base,
                onPressed: enabled ? () => onSend() : null,
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.base),
                      )
                    : const Icon(Icons.arrow_upward),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
