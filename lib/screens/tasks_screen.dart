import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../widgets/fade_scale_route.dart';
import 'editor_screen.dart';

/// Aggregates every `- [ ]` and `- [x]` from every note into one list.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _hideDone = false;

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: Icon(_hideDone ? Icons.check_circle : Icons.check_circle_outline),
            tooltip: _hideDone ? 'show done' : 'hide done',
            onPressed: () => setState(() => _hideDone = !_hideDone),
          ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error: $e')),
        data: (notes) {
          final tasks = _collect(notes).where((t) => !_hideDone || !t.done).toList();
          if (tasks.isEmpty) {
            return const _Empty();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _TaskRow(
              task: tasks[i],
              onToggle: () => _toggle(tasks[i]),
              onOpenNote: () => _open(tasks[i].note),
            ),
          );
        },
      ),
    );
  }

  List<_Task> _collect(List<Note> notes) {
    final out = <_Task>[];
    for (final n in notes) {
      final lines = n.body.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final m = RegExp(r'^(\s*)-\s+\[( |x|X)\]\s+(.*)$').firstMatch(lines[i]);
        if (m == null) continue;
        out.add(_Task(
          note: n,
          lineIdx: i,
          done: (m.group(2) ?? ' ').toLowerCase() == 'x',
          text: m.group(3) ?? '',
        ));
      }
    }
    // Undone first, then by note updated_at desc
    out.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });
    return out;
  }

  Future<void> _toggle(_Task t) async {
    final lines = t.note.body.split('\n');
    lines[t.lineIdx] = lines[t.lineIdx].replaceFirstMapped(
      RegExp(r'\[( |x|X)\]'),
      (m) => m.group(1) == ' ' ? '[x]' : '[ ]',
    );
    await ref.read(notesRepoProvider).update(
          t.note.copyWith(body: lines.join('\n')),
        );
  }

  void _open(Note n) {
    Navigator.of(context).push(
      FadeScalePageRoute(builder: (_) => EditorScreen(note: n)),
    );
  }
}

class _Task {
  final Note note;
  final int lineIdx;
  final bool done;
  final String text;
  _Task({required this.note, required this.lineIdx, required this.done, required this.text});
}

class _TaskRow extends StatelessWidget {
  final _Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpenNote;
  const _TaskRow({required this.task, required this.onToggle, required this.onOpenNote});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.overlay),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                task.done ? Icons.check_box : Icons.check_box_outline_blank,
                color: task.done ? AppTheme.success : AppTheme.muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.text,
                      style: TextStyle(
                        color: task.done ? AppTheme.muted : AppTheme.text,
                        decoration: task.done ? TextDecoration.lineThrough : null,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onOpenNote,
                      child: Row(
                        children: [
                          const Icon(Icons.notes, size: 12, color: AppTheme.muted),
                          const SizedBox(width: 4),
                          Text(
                            task.note.title.isEmpty ? '(untitled)' : task.note.title,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
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
                    AppTheme.success.withValues(alpha: 0.18),
                    AppTheme.primary.withValues(alpha: 0.10),
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
                  child: Icon(Icons.check_circle_outline,
                      size: 80, color: AppTheme.success.withValues(alpha: 0.85)),
                ),
                Positioned(
                  bottom: 32, right: 32,
                  child: Icon(Icons.task_alt,
                      size: 40, color: AppTheme.primary.withValues(alpha: 0.7)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('All caught up',
                style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3)),
            const SizedBox(height: 8),
            const Text(
              'add `- [ ] task` to any note\n'
              'or `- [x]` to mark it done',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.overlay,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '- [ ] my task',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontFamily: 'monospace',
                    fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
