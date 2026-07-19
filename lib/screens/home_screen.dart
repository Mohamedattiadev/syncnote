// Notes home — Fabric/Notion-inspired hero + horizontal card rows.
//
// Layout:
//   1. Hero greeting ("Good morning, name") + date
//   2. 52pt search bar
//   3. Chip row: Tags · Connections · Shared with me
//   4. Netflix rows: Pinned · Recent · Spaces · AI conversations
//   5. On search: fall back to a flat grid/list of results.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/note.dart';
import '../providers.dart';
import '../services/templates.dart';
import '../widgets/fade_scale_route.dart';
import '../widgets/skeleton.dart';
import 'editor_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _RowKind { tags, connections, shared }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String? _tagFilter;
  _RowKind? _rowFilter;
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

  Future<void> _showTemplatePicker() async {
    final picked = await showModalBottomSheet<NoteTemplate>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('new note from…',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            for (final t in kTemplates)
              ListTile(
                leading: Icon(_iconForTemplate(t.id), color: AppTheme.accent),
                title: Text(t.label),
                subtitle: Text(t.description,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                onTap: () => Navigator.pop(context, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now().toUtc();
    final draft = Note(
      id: 'draft',
      userId: '',
      title: picked.titleFn(),
      body: picked.bodyFn(),
      kind: NoteKind.note,
      tags: picked.tags,
      createdAt: now,
      updatedAt: now,
    );
    if (mounted) {
      await Navigator.of(context).push(
        FadeScalePageRoute(builder: (_) => EditorScreen(note: draft)),
      );
    }
  }

  IconData _iconForTemplate(String id) => switch (id) {
        'daily' => Icons.calendar_today_outlined,
        'meeting' => Icons.groups_outlined,
        'idea' => Icons.lightbulb_outline,
        _ => Icons.note_add_outlined,
      };

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayName() {
    final user = ref.read(authProvider)?.user;
    final meta = user?.userMetadata;
    final metaName = meta?['name'] ?? meta?['full_name'] ?? meta?['display_name'];
    if (metaName is String && metaName.trim().isNotEmpty) return metaName.trim();
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      body: notesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
          children: const [
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
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
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
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              ref.invalidate(notesStreamProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: _HomeBody(
              notes: notes,
              query: query,
              searchCtrl: _searchCtrl,
              onSearch: _onSearch,
              greeting: _greeting(),
              name: _displayName(),
              tagFilter: _tagFilter,
              rowFilter: _rowFilter,
              onTagFilter: (t) {
                HapticFeedback.selectionClick();
                setState(() => _tagFilter = t);
              },
              onRowFilter: (r) => setState(() => _rowFilter = r),
              onClearSearch: () {
                _searchCtrl.clear();
                _onSearch('');
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await _showTemplatePicker();
        },
        icon: const Icon(Icons.add),
        label: const Text('new'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.base,
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final List<Note> notes;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final String greeting;
  final String name;
  final String? tagFilter;
  final _RowKind? rowFilter;
  final ValueChanged<String?> onTagFilter;
  final ValueChanged<_RowKind?> onRowFilter;

  const _HomeBody({
    required this.notes,
    required this.query,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClearSearch,
    required this.greeting,
    required this.name,
    required this.tagFilter,
    required this.rowFilter,
    required this.onTagFilter,
    required this.onRowFilter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPad = width >= 1200
        ? 64.0
        : width >= 900
            ? 48.0
            : 20.0;
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    // Search-mode: flat filtered list/grid.
    if (query.isNotEmpty) {
      final results = _searchAll(notes, query);
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              greeting: greeting,
              name: name,
              date: dateStr,
              pad: horizontalPad,
            ),
          ),
          SliverToBoxAdapter(
            child: _SearchBar(
              controller: searchCtrl,
              onChanged: onSearch,
              onClear: onClearSearch,
              query: query,
              pad: horizontalPad,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPad, 24, horizontalPad, 8),
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(hasQuery: true),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPad, 0, horizontalPad, 100),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _NoteTile(
                  note: results[i],
                  onTapTag: onTagFilter,
                ).animate().fadeIn(
                    duration: 200.ms, delay: (i * 30).ms).slideY(begin: 0.3),
              ),
            ),
        ],
      );
    }

    // Default: hero + rows.
    List<Note> src = notes;
    if (tagFilter != null) {
      src = src.where((n) => n.tags.contains(tagFilter)).toList();
    }

    final pinned = src.where((n) => n.pinned).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final now = DateTime.now();
    final recent = src
        .where((n) => now.difference(n.updatedAt).inDays <= 7 && !n.pinned)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    // Spaces = distinct tags mapped to counts.
    final tagCounts = <String, int>{};
    for (final n in src) {
      for (final t in n.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final spaces = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Hero(
            greeting: greeting,
            name: name,
            date: dateStr,
            pad: horizontalPad,
          ),
        ),
        SliverToBoxAdapter(
          child: _SearchBar(
            controller: searchCtrl,
            onChanged: onSearch,
            onClear: onClearSearch,
            query: query,
            pad: horizontalPad,
          ),
        ),
        SliverToBoxAdapter(
          child: _ChipRow(
            active: rowFilter,
            onSelect: onRowFilter,
            tagFilter: tagFilter,
            onClearTag: () => onTagFilter(null),
            pad: horizontalPad,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (pinned.isNotEmpty)
          _CardRow(
            title: 'Pinned',
            notes: pinned,
            pad: horizontalPad,
            onTapTag: onTagFilter,
          ),
        if (recent.isNotEmpty)
          _CardRow(
            title: 'Recent items',
            notes: recent,
            pad: horizontalPad,
            onTapTag: onTagFilter,
          ),
        if (spaces.isNotEmpty)
          _SpacesRow(
            spaces: spaces,
            pad: horizontalPad,
            onTapTag: onTagFilter,
          ),
        // AI conversations placeholder — real chat backing store lives elsewhere;
        // showing a static empty row for now would add noise, so we surface a
        // small teaser card only.
        _AiConversationsRow(pad: horizontalPad),
        if (notes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(hasQuery: false),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  static List<Note> _searchAll(List<Note> notes, String query) {
    final q = query.toLowerCase();
    final scored = notes.map((n) {
      final hay =
          '${n.title.toLowerCase()} ${n.body.toLowerCase()} ${n.tags.join(' ').toLowerCase()}';
      final score = _fuzzyScore(q, hay);
      return (score, n);
    }).where((e) => e.$1 > 0).toList();
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.map((e) => e.$2).toList();
  }

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

class _Hero extends StatelessWidget {
  final String greeting;
  final String name;
  final String date;
  final double pad;
  const _Hero({
    required this.greeting,
    required this.name,
    required this.date,
    required this.pad,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 48, pad, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, $name',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
              color: AppTheme.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.muted,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String query;
  final double pad;
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.query,
    required this.pad,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
      child: SizedBox(
        height: 52,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search everything…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onClear();
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.overlay),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.overlay),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final _RowKind? active;
  final ValueChanged<_RowKind?> onSelect;
  final String? tagFilter;
  final VoidCallback onClearTag;
  final double pad;
  const _ChipRow({
    required this.active,
    required this.onSelect,
    required this.tagFilter,
    required this.onClearTag,
    required this.pad,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _NavChip(
              label: 'Tags',
              icon: Icons.tag,
              selected: active == _RowKind.tags,
              onTap: () =>
                  onSelect(active == _RowKind.tags ? null : _RowKind.tags),
            ),
            _NavChip(
              label: 'Connections',
              icon: Icons.hub_outlined,
              selected: active == _RowKind.connections,
              onTap: () => onSelect(
                  active == _RowKind.connections ? null : _RowKind.connections),
            ),
            _NavChip(
              label: 'Shared with me',
              icon: Icons.people_outline,
              selected: active == _RowKind.shared,
              onTap: () =>
                  onSelect(active == _RowKind.shared ? null : _RowKind.shared),
            ),
            if (tagFilter != null) ...[
              const SizedBox(width: 16),
              InkWell(
                onTap: onClearTag,
                borderRadius: BorderRadius.circular(9999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag,
                          size: 12, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text('#$tagFilter',
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.close,
                          size: 12, color: AppTheme.accent),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavChip({
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
            ? AppTheme.primary.withValues(alpha: 0.16)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(9999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.overlay,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 14,
                    color: selected ? AppTheme.primary : AppTheme.muted),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            selected ? AppTheme.primary : AppTheme.text,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final String title;
  final List<Note> notes;
  final double pad;
  final ValueChanged<String?> onTapTag;
  const _CardRow({
    required this.title,
    required this.notes,
    required this.pad,
    required this.onTapTag,
  });
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RowHeader(title: title, pad: pad),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: notes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 200,
                  child: _NoteCard(note: notes[i], onTapTag: onTapTag)
                      .animate()
                      .fadeIn(duration: 200.ms, delay: (i * 30).ms)
                      .slideY(begin: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpacesRow extends StatelessWidget {
  final List<MapEntry<String, int>> spaces;
  final double pad;
  final ValueChanged<String?> onTapTag;
  const _SpacesRow({
    required this.spaces,
    required this.pad,
    required this.onTapTag,
  });
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RowHeader(title: 'Spaces', pad: pad),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: pad),
                itemCount: spaces.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final s = spaces[i];
                  return SizedBox(
                    width: 160,
                    child: Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onTapTag(s.key),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.overlay),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.folder_outlined,
                                  color: AppTheme.accent, size: 20),
                              const Spacer(),
                              Text('#${s.key}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '${s.value} note${s.value == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 200.ms, delay: (i * 30).ms)
                      .slideY(begin: 0.3);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiConversationsRow extends StatelessWidget {
  final double pad;
  const _AiConversationsRow({required this.pad});
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RowHeader(title: 'AI conversations', pad: pad),
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.overlay),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        color: AppTheme.accent, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Start a chat',
                              style: TextStyle(
                                  color: AppTheme.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Ask questions about your notes',
                              style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward,
                        color: AppTheme.muted, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowHeader extends StatelessWidget {
  final String title;
  final double pad;
  const _RowHeader({required this.title, required this.pad});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // TODO: view-all — not part of Phase A scope.
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: AppTheme.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final Note note;
  final ValueChanged<String?> onTapTag;
  const _NoteCard({required this.note, required this.onTapTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = note.body.trim().isEmpty
        ? 0
        : note.body.trim().split(RegExp(r'\s+')).length;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            FadeScalePageRoute(builder: (_) => EditorScreen(note: note)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.overlay),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    note.pinned ? Icons.push_pin : _kindIcon(note.kind),
                    size: 16,
                    color:
                        note.pinned ? AppTheme.warning : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _kindLabel(note.kind),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Hero(
                tag: 'note-title-${note.id}',
                flightShuttleBuilder: (_, _, _, _, _) => Material(
                  color: Colors.transparent,
                  child: Text(
                    note.title.isEmpty ? '(untitled)' : note.title,
                    style: const TextStyle(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.2),
                  ),
                ),
                child: Text(
                  note.title.isEmpty ? '(untitled)' : note.title,
                  style: const TextStyle(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.25,
                      letterSpacing: -0.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.body.isEmpty ? '(no body)' : note.body,
                  style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: note.tags.take(3).map((t) {
                    return InkWell(
                      onTap: () => onTapTag(t),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _fmtDate(note.updatedAt),
                    style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  const Text('·',
                      style: TextStyle(
                          color: AppTheme.muted, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text('$words w',
                      style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  final Note note;
  final ValueChanged<String?> onTapTag;
  const _NoteTile({required this.note, required this.onTapTag});

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
            FadeScalePageRoute(builder: (_) => EditorScreen(note: note)),
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
                      note.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin,
                      color: AppTheme.warning,
                    ),
                    title: Text(note.pinned ? 'unpin' : 'pin to top'),
                    onTap: () => Navigator.pop(context, 'pin'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline,
                        color: AppTheme.error),
                    title: const Text('delete'),
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.close, color: AppTheme.muted),
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
                  content: Text(
                      'deleted "${backup.title.isEmpty ? "untitled" : backup.title}"'),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.overlay, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
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
                    Text(
                      note.title.isEmpty ? '(untitled)' : note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.2,
                          letterSpacing: -0.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.body.replaceAll('\n', ' '),
                        style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 13,
                            height: 1.5),
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
                            child: Wrap(
                              spacing: 8,
                              children: note.tags.take(3).map((t) {
                                return InkWell(
                                  onTap: () => onTapTag(t),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Text(
                                    '#$t',
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
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
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.accent.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.overlay.withValues(alpha: 0.4)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 40,
                  left: 40,
                  child: Icon(
                    hasQuery ? Icons.search_off : Icons.notes_outlined,
                    size: 80,
                    color: AppTheme.text.withValues(alpha: 0.6),
                  ),
                ),
                Positioned(
                  bottom: 32,
                  right: 32,
                  child: Icon(
                    hasQuery ? Icons.filter_alt_outlined : Icons.auto_awesome,
                    size: 40,
                    color: AppTheme.accent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasQuery ? 'No matches found' : 'Start writing',
            style: const TextStyle(
                color: AppTheme.text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(
              hasQuery
                  ? 'Try different keywords or clear the search.'
                  : 'Your notes appear here. Create your first one to get started.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(NoteKind k) => switch (k) {
      NoteKind.note => Icons.notes_outlined,
      NoteKind.link => Icons.link,
      NoteKind.file => Icons.description_outlined,
    };

String _kindLabel(NoteKind k) => switch (k) {
      NoteKind.note => 'NOTE',
      NoteKind.link => 'LINK',
      NoteKind.file => 'FILE',
    };

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(d);
}
