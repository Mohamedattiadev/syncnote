import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../widgets/skeleton.dart';
import 'editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  NoteKind? _filter;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      body: notesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(12, 130, 12, 100),
          children: const [
            NoteSkeleton(),
            NoteSkeleton(),
            NoteSkeleton(),
            NoteSkeleton(),
            NoteSkeleton(),
          ],
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text('error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('retry'),
                  onPressed: () => ref.invalidate(notesStreamProvider),
                ),
              ],
            ),
          ),
        ),
        data: (notes) {
          final visible = _apply(notes, query);
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(notesStreamProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: true,
                snap: false,
                expandedHeight: 130,
                backgroundColor: AppTheme.base,
                surfaceTintColor: AppTheme.base,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'sign out',
                    onPressed: () => ref.read(authProvider)?.signOut(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.note_alt_outlined,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('SyncNote',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.overlay,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${notes.length}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'search notes…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                notesAsync.when(
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, _) => const SizedBox.shrink(),
                                  data: (n) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      '${_apply(n, query).length}',
                                      style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _searchCtrl.clear();
                                    _onSearch('');
                                  },
                                ),
                              ],
                            )
                          : null,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _Chip(
                        label: 'all',
                        icon: Icons.all_inclusive,
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      _Chip(
                        label: 'notes',
                        icon: Icons.notes,
                        selected: _filter == NoteKind.note,
                        onTap: () => setState(() => _filter = NoteKind.note),
                      ),
                      _Chip(
                        label: 'links',
                        icon: Icons.link,
                        selected: _filter == NoteKind.link,
                        onTap: () => setState(() => _filter = NoteKind.link),
                      ),
                      _Chip(
                        label: 'files',
                        icon: Icons.attach_file,
                        selected: _filter == NoteKind.file,
                        onTap: () => setState(() => _filter = NoteKind.file),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(hasQuery: query.isNotEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _NoteTile(note: visible[i]),
                  ),
                ),
            ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.base,
      ),
    );
  }

  List<Note> _apply(List<Note> notes, String query) {
    Iterable<Note> it = notes;
    if (_filter != null) it = it.where((n) => n.kind == _filter);
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      // Fuzzy scoring — substring > subsequence, sort by score desc
      final scored = it.map((n) {
        final hay = '${n.title.toLowerCase()} ${n.body.toLowerCase()} ${n.tags.join(' ').toLowerCase()}';
        final score = _fuzzyScore(q, hay);
        return (score, n);
      }).where((e) => e.$1 > 0).toList();
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      return scored.map((e) => e.$2).toList();
    }
    // Pinned first, then by updated_at desc
    final sorted = it.toList();
    sorted.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  /// Same algorithm as CLI AppState.fuzzyScore
  static int _fuzzyScore(String query, String haystack) {
    if (query.isEmpty) return 1;
    final idx = haystack.indexOf(query);
    if (idx >= 0) return 1000 - idx;
    int hi = 0, hits = 0, score = 0;
    for (final ch in query.runes) {
      final rest = haystack.substring(hi);
      final found = rest.indexOf(String.fromCharCode(ch));
      if (found < 0) return 0;
      hi += found + 1;
      hits++;
      if (found == 0) score += 5;
      score += 1;
    }
    return hits > 0 ? score : 0;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.2)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.overlay,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: selected ? AppTheme.primary : AppTheme.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: selected ? AppTheme.primary : AppTheme.text,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasQuery ? Icons.search_off : Icons.notes_outlined,
              size: 48,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'no matches' : 'no notes yet',
            style: const TextStyle(
                color: AppTheme.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            hasQuery ? 'try different keywords' : 'tap + to create your first note',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  final Note note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
          );
        },
        onLongPress: () async {
          HapticFeedback.heavyImpact();
          final action = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: AppTheme.surface,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      note.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                      color: AppTheme.warning,
                    ),
                    title: Text(note.pinned ? 'unpin' : 'pin to top'),
                    onTap: () => Navigator.pop(context, 'pin'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                    title: const Text('delete'),
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close, color: AppTheme.muted),
                    title: const Text('cancel'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
          if (!context.mounted) return;
          if (action == 'pin') {
            await ref.read(notesRepoProvider).update(
                  note.copyWith(pinned: !note.pinned),
                );
          } else if (action == 'delete') {
            final backup = note;
            await ref.read(notesRepoProvider).delete(note.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('deleted "${backup.title.isEmpty ? "untitled" : backup.title}"'),
                  action: SnackBarAction(
                    label: 'undo',
                    textColor: AppTheme.warning,
                    onPressed: () async {
                      await ref.read(notesRepoProvider).create(
                            title: backup.title,
                            body: backup.body,
                            kind: backup.kind,
                            tags: backup.tags,
                            folder: backup.folder,
                          );
                    },
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.overlay, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  note.pinned ? Icons.push_pin : _kindIcon(note.kind),
                  color: note.pinned ? AppTheme.warning : AppTheme.muted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'note-title-${note.id}',
                      flightShuttleBuilder: (_, _, _, _, _) => Material(
                        color: Colors.transparent,
                        child: Text(
                          note.title.isEmpty ? '(untitled)' : note.title,
                          style: const TextStyle(
                              color: AppTheme.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15.5,
                              letterSpacing: -0.1),
                        ),
                      ),
                      child: Text(
                        note.title.isEmpty ? '(untitled)' : note.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.5,
                            height: 1.2,
                            letterSpacing: -0.1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.body.replaceAll('\n', ' '),
                        style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _fmtDate(note.updatedAt),
                          style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        if (note.tags.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              note.tags.take(3).map((t) => '#$t').join('  '),
                              style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
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

  static Color _kindColor(NoteKind k) => switch (k) {
        NoteKind.note => AppTheme.primary,
        NoteKind.link => AppTheme.accent,
        NoteKind.file => AppTheme.warning,
      };

  static IconData _kindIcon(NoteKind k) => switch (k) {
        NoteKind.note => Icons.notes_outlined,
        NoteKind.link => Icons.link,
        NoteKind.file => Icons.description_outlined,
      };
}

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
