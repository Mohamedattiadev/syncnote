// Full list view for a category (Pinned / Recent / Tagged).
// Reachable from home row-header "view all" chevron.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../widgets/fade_scale_route.dart';
import 'editor_screen.dart';

enum AllNotesFilter { all, pinned, recent, tagged }

class AllNotesScreen extends ConsumerWidget {
  final AllNotesFilter filter;
  final String? tag;
  final String title;
  const AllNotesScreen({
    super.key,
    required this.filter,
    required this.title,
    this.tag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: AppTheme.base,
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('error: $e')),
        data: (all) {
          final filtered = _apply(all);
          if (filtered.isEmpty) {
            return const Center(
              child: Text('nothing here yet',
                  style: TextStyle(color: AppTheme.muted, fontSize: 15)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = filtered[i];
              return Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    FadeScalePageRoute(builder: (_) => EditorScreen(note: n)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (n.pinned)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.push_pin, size: 14, color: AppTheme.warning),
                            ),
                          Expanded(
                            child: Text(
                              n.title.isEmpty ? '(untitled)' : n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                        if (n.body.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.muted, fontSize: 13, height: 1.4),
                          ),
                        ],
                        if (n.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: n.tags.map((t) => Text('#$t',
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 12,
                                        fontFamily: 'monospace'))).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 200.ms, delay: (i * 20).ms)
                  .slideY(begin: 0.15);
            },
          );
        },
      ),
    );
  }

  List<Note> _apply(List<Note> all) {
    switch (filter) {
      case AllNotesFilter.pinned:
        final ns = all.where((n) => n.pinned).toList();
        ns.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return ns;
      case AllNotesFilter.recent:
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        final ns = all.where((n) => n.updatedAt.isAfter(cutoff)).toList();
        ns.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return ns;
      case AllNotesFilter.tagged:
        if (tag == null) return const [];
        final ns = all.where((n) => n.tags.contains(tag)).toList();
        ns.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return ns;
      case AllNotesFilter.all:
        final ns = List<Note>.of(all);
        ns.sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        return ns;
    }
  }
}
