// AI chat — full-screen ChatGPT-style immersion (UI_PLAN_V2 §9).
//
// - Bypasses the shell chrome (no bg appbar, no left rail, no bottom nav).
// - Floating transparent header top-right with model + mode chip.
// - Bubbles: no borders, rounded 16, user right / AI left.
// - Streaming indicator: bottom border opacity pulse.
// - Composer: rounded 20 input with send button integrated on the right.
// - Message list uses flutter_animate for fade+slide entry.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown_selectionarea.dart';

import '../config/theme.dart';
import '../widgets/pressable_scale.dart';
import '../models/note.dart';
import '../providers.dart';
import '../services/ai.dart';
import '../services/ai_actions.dart';
import '../services/rag.dart';
import '../widgets/fade_scale_route.dart';
import 'ai_settings_screen.dart';


enum ChatMode { notes, web }

/// Push the chat as a full-screen route so it bypasses the shell's left rail
/// / bottom nav entirely (spec §9 "full immersion").
Future<void> openAiChat(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    FadeScalePageRoute(builder: (_) => const AiChatScreen()),
  );
}

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
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    // Quick-save commands — no LLM needed.
    if (text.startsWith('/note ') || text.startsWith('/save ')) {
      final rest = text.substring(6).trim();
      final firstNewline = rest.indexOf('\n');
      final title = firstNewline < 0 ? rest : rest.substring(0, firstNewline);
      final body = firstNewline < 0 ? '' : rest.substring(firstNewline + 1);
      await _quickSave(title, body);
      setState(() => _input.clear());
      return;
    }

    // Natural-language note creation intent — parse before LLM.
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

  (String, String)? _parseNoteIntent(String text) {
    final t = text.trim();
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
      FadeScalePageRoute(builder: (_) => const AiSettingsScreen()),
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
    final topPad = MediaQuery.of(context).padding.top;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            setState(() {
              _messages.clear();
              _streaming = null;
              _err = null;
            }),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.base,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              // Message column — no appbar, full-bleed.
              Positioned.fill(
                child: Column(
                  children: [
                    // Space for the floating header.
                    SizedBox(height: topPad + 64),
                    if (ai == null)
                      _NotConfiguredBanner(onConfigure: _openSettings),
                    Expanded(
                      child: _messages.isEmpty && _streaming == null
                          ? _EmptyChat(onPick: _send)
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _messages.length +
                                  (_streaming != null ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i < _messages.length) {
                                  final msg = _messages[i];
                                  return _Bubble(
                                    msg: msg,
                                    onCopy: () {
                                      HapticFeedback.selectionClick();
                                      Clipboard.setData(
                                          ClipboardData(text: msg.content));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('copied'),
                                          duration: Duration(milliseconds: 900),
                                        ),
                                      );
                                    },
                                    onRetry: i == _messages.length - 1 &&
                                            msg.role == 'assistant'
                                        ? _retry
                                        : null,
                                    onSaveNote: msg.role == 'assistant'
                                        ? () => _saveMessageAsNote(msg.content)
                                        : null,
                                  )
                                      .animate()
                                      .fadeIn(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic)
                                      .slideY(
                                          begin: 0.15,
                                          end: 0,
                                          duration: const Duration(
                                              milliseconds: 220),
                                          curve: Curves.easeOutCubic);
                                }
                                return _Bubble(
                                  msg: ChatMessage(
                                      'assistant', _streaming ?? ''),
                                  streaming: true,
                                );
                              },
                            ),
                    ),
                    if (_err != null)
                      _ErrorBar(
                          err: _err!,
                          onDismiss: () => setState(() => _err = null)),
                    _Composer(
                      controller: _input,
                      enabled: !_busy && ai != null,
                      busy: _busy,
                      onSend: _send,
                    ),
                  ],
                ),
              ),
              // Floating transparent header — top-right cluster.
              Positioned(
                top: topPad + 8,
                left: 8,
                right: 8,
                child: _FloatingHeader(
                  modelLabel: currentModel.label,
                  mode: _mode,
                  onChangeModel: _changeModel,
                  onModeChanged: (m) => setState(() => _mode = m),
                  onClose: () => Navigator.of(context).maybePop(),
                  onClear: _messages.isEmpty
                      ? null
                      : () => setState(() {
                            _messages.clear();
                            _streaming = null;
                            _err = null;
                          }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  final String modelLabel;
  final ChatMode mode;
  final VoidCallback onChangeModel;
  final ValueChanged<ChatMode> onModeChanged;
  final VoidCallback onClose;
  final VoidCallback? onClear;
  const _FloatingHeader({
    required this.modelLabel,
    required this.mode,
    required this.onChangeModel,
    required this.onModeChanged,
    required this.onClose,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Close (back) chip on the left — needed since we bypass the shell.
        _HeaderChip(
          onTap: onClose,
          child: const Icon(Icons.arrow_back, size: 18, color: AppTheme.text),
        ),
        const Spacer(),
        _HeaderChip(
          onTap: onChangeModel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_outlined,
                  size: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(modelLabel,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down,
                  size: 18, color: AppTheme.muted),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ModeToggle(mode: mode, onChanged: onModeChanged),
        if (onClear != null) ...[
          const SizedBox(width: 8),
          _HeaderChip(
            onTap: onClear!,
            child:
                const Icon(Icons.refresh, size: 18, color: AppTheme.text),
          ),
        ],
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HeaderChip({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
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
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.key, color: AppTheme.warning),
              SizedBox(width: 12),
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
    final scheme = Theme.of(context).colorScheme;
    // User bubble: primary-tinted container. AI: surface.
    final bubbleColor = isUser
        ? scheme.primary.withValues(alpha: 0.18)
        : AppTheme.surface;
    final textColor = isUser ? scheme.primary : AppTheme.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  child: _BubbleBody(
                    bubbleColor: bubbleColor,
                    streaming: streaming,
                    child: isUser
                        ? SelectableText(
                            msg.content,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w500),
                          )
                        : SelectionArea(
                            child: Markdown(
                              data: msg.content + (streaming ? '▍' : ''),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    color: AppTheme.text,
                                    fontSize: 15,
                                    height: 1.6),
                                code: const TextStyle(
                                    color: AppTheme.warning,
                                    backgroundColor: AppTheme.base,
                                    fontFamily: 'monospace'),
                                codeblockDecoration: BoxDecoration(
                                  color: AppTheme.base,
                                  borderRadius: BorderRadius.circular(8),
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
              ),
            ],
          ),
          if (!isUser && !streaming)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (onCopy != null)
                    _MsgAction(
                        icon: Icons.copy_outlined,
                        label: 'copy',
                        onTap: onCopy!),
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
                        icon: Icons.refresh,
                        label: 'retry',
                        onTap: onRetry!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bubble container: no border, radius 16, padding 16h/12v. When [streaming]
/// is true, a thin bottom edge pulses opacity 0.3→1.0 as the "thinking" cue.
class _BubbleBody extends StatelessWidget {
  final Widget child;
  final Color bubbleColor;
  final bool streaming;
  const _BubbleBody({
    required this.child,
    required this.bubbleColor,
    required this.streaming,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (!streaming) return content;
    // Pulsing bottom edge — subtle streaming indicator (no typing dots).
    return Stack(
      children: [
        content,
        Positioned(
          left: 12,
          right: 12,
          bottom: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(
                  duration: const Duration(milliseconds: 700),
                  begin: 0.3,
                  curve: Curves.easeInOut),
        ),
      ],
    );
  }
}

class _MsgAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MsgAction(
      {required this.icon, required this.label, required this.onTap});
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
                style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
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
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.22),
                    AppTheme.primary.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.overlay.withValues(alpha: 0.4)),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Positioned(
                  top: 40, left: 40,
                  child: Icon(Icons.auto_awesome,
                      size: 80, color: AppTheme.accent.withValues(alpha: 0.85)),
                ),
                Positioned(
                  bottom: 32, right: 32,
                  child: Icon(Icons.chat_bubble_outline,
                      size: 40, color: AppTheme.primary.withValues(alpha: 0.75)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Ask anything',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.24,
                    color: AppTheme.text)),
            const SizedBox(height: 8),
            const Text(
              'Chat streams live · markdown supported · retry & copy',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        color: AppTheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(Icons.folder_outlined, 'notes', ChatMode.notes),
          _seg(Icons.public, 'web', ChatMode.web),
        ],
      ),
    );
  }

  Widget _seg(IconData icon, String label, ChatMode m) {
    final selected = mode == m;
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        // Composer respects the on-screen keyboard via resizeToAvoidBottomInset
        // (scaffold-level), plus this padding for the ambient safe area.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLines: 6,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style:
                      const TextStyle(color: AppTheme.text, fontSize: 15),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: enabled
                        ? 'ask AI · try /note <title> to save fast'
                        : 'add API key first',
                    hintStyle: const TextStyle(
                        color: AppTheme.muted, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Integrated send button — inside the input pill on the right.
              PressableScale(
                onTap: canSend ? () => onSend() : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: canSend ? AppTheme.primary : AppTheme.overlay,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.base),
                          )
                        : Icon(Icons.arrow_upward,
                            size: 20,
                            color: canSend
                                ? AppTheme.base
                                : AppTheme.muted),
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
