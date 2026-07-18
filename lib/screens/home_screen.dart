import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import 'editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  NoteKind? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      body: notesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('error: $e',
                style: const TextStyle(color: AppTheme.error)),
          ),
        ),
        data: (notes) {
          final visible = _apply(notes, query);
          return CustomScrollView(
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
                    onChanged: (v) =>
                        ref.read(searchQueryProvider.notifier).state = v,
                    decoration: InputDecoration(
                      hintText: 'search notes…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(searchQueryProvider.notifier).state = '';
                              },
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
      it = it.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q)));
    }
    return it.toList();
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
        ),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Delete note?'),
              content: Text(note.title.isEmpty ? '(untitled)' : note.title),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('delete'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(notesRepoProvider).delete(note.id);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.overlay),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kindColor(note.kind).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _kindIcon(note.kind),
                    color: _kindColor(note.kind),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? '(untitled)' : note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note.body.replaceAll('\n', ' '),
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12.5, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: note.tags
                            .take(4)
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.overlay,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('#$t',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppTheme.text)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _fmtDate(note.updatedAt),
                style: const TextStyle(color: AppTheme.muted, fontSize: 11),
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
