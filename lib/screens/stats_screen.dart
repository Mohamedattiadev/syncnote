import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error: $e')),
        data: (notes) {
          final stats = _compute(notes);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatGrid(stats: stats),
              const SizedBox(height: 24),
              const Text('TOP TAGS',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.muted,
                      letterSpacing: 1,
                      fontSize: 11)),
              const SizedBox(height: 8),
              ...stats.topTags.map((e) => _TagRow(
                    tag: e.key,
                    count: e.value,
                    maxCount: stats.topTags.first.value,
                  )),
              const SizedBox(height: 24),
              const Text('ACTIVITY (LAST 30 DAYS)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.muted,
                      letterSpacing: 1,
                      fontSize: 11)),
              const SizedBox(height: 8),
              _ActivityHeatmap(stats: stats),
            ],
          );
        },
      ),
    );
  }

  _Stats _compute(List<Note> notes) {
    int totalWords = 0;
    int totalTasks = 0;
    int doneTasks = 0;
    final tagCounts = <String, int>{};
    final activity = List.filled(30, 0);
    final now = DateTime.now();
    for (final n in notes) {
      totalWords += n.body.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      totalTasks += RegExp(r'^\s*-\s+\[[ xX]\]', multiLine: true).allMatches(n.body).length;
      doneTasks += RegExp(r'^\s*-\s+\[[xX]\]', multiLine: true).allMatches(n.body).length;
      for (final t in n.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
      final days = now.difference(n.updatedAt).inDays;
      if (days >= 0 && days < 30) activity[days]++;
    }
    final sortedTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _Stats(
      noteCount: notes.length,
      totalWords: totalWords,
      totalTasks: totalTasks,
      doneTasks: doneTasks,
      pinnedCount: notes.where((n) => n.pinned).length,
      topTags: sortedTags.take(6).toList(),
      activity: activity,
    );
  }
}

class _Stats {
  final int noteCount;
  final int totalWords;
  final int totalTasks;
  final int doneTasks;
  final int pinnedCount;
  final List<MapEntry<String, int>> topTags;
  final List<int> activity;
  _Stats({
    required this.noteCount,
    required this.totalWords,
    required this.totalTasks,
    required this.doneTasks,
    required this.pinnedCount,
    required this.topTags,
    required this.activity,
  });
}

class _StatGrid extends StatelessWidget {
  final _Stats stats;
  const _StatGrid({required this.stats});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(icon: Icons.notes_outlined, label: 'notes', value: '${stats.noteCount}', color: AppTheme.primary),
        _StatCard(icon: Icons.text_fields, label: 'words', value: _fmt(stats.totalWords), color: AppTheme.accent),
        _StatCard(icon: Icons.push_pin, label: 'pinned', value: '${stats.pinnedCount}', color: AppTheme.warning),
        _StatCard(icon: Icons.check_box_outlined, label: 'tasks done',
            value: '${stats.doneTasks}/${stats.totalTasks}', color: AppTheme.success),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1_000_000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.overlay),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final String tag;
  final int count;
  final int maxCount;
  const _TagRow({required this.tag, required this.count, required this.maxCount});
  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('#$tag',
                style: const TextStyle(color: AppTheme.text, fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppTheme.surface,
                valueColor: AlwaysStoppedAnimation(AppTheme.accent.withValues(alpha: 0.7)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActivityHeatmap extends StatelessWidget {
  final _Stats stats;
  const _ActivityHeatmap({required this.stats});
  @override
  Widget build(BuildContext context) {
    final max = stats.activity.fold<int>(0, (a, b) => a > b ? a : b);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(30, (i) {
        final dayIdx = 29 - i;
        final count = stats.activity[dayIdx];
        final intensity = max == 0 ? 0.0 : count / max;
        return Tooltip(
          message: '$count edits, ${dayIdx == 0 ? "today" : "$dayIdx days ago"}',
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: count == 0
                  ? AppTheme.overlay
                  : AppTheme.primary.withValues(alpha: 0.15 + 0.85 * intensity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
