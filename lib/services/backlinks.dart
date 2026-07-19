// Parse `[[Note Title]]` references from all notes and build a link graph.

import '../models/note.dart';

class Backlink {
  final Note source;
  final String rawTarget;
  final String context; // surrounding text
  const Backlink({required this.source, required this.rawTarget, required this.context});
}

class BacklinkIndex {
  final Map<String, List<Backlink>> _incoming = {};

  static final _linkRegex = RegExp(r'\[\[([^\]]+)\]\]');

  BacklinkIndex.build(List<Note> notes) {
    for (final n in notes) {
      _extract(n);
    }
  }

  void _extract(Note n) {
    for (final match in _linkRegex.allMatches(n.body)) {
      final target = (match.group(1) ?? '').trim().toLowerCase();
      if (target.isEmpty) continue;
      final start = (match.start - 40).clamp(0, n.body.length);
      final end = (match.end + 40).clamp(0, n.body.length);
      _incoming.putIfAbsent(target, () => []).add(Backlink(
            source: n,
            rawTarget: match.group(1) ?? '',
            context: n.body.substring(start, end).trim(),
          ));
    }
  }

  /// Backlinks pointing at [note] (matches by title, case-insensitive).
  List<Backlink> forNote(Note note) {
    final key = note.title.toLowerCase();
    return _incoming[key] ?? const [];
  }

  int get totalLinks => _incoming.values.fold(0, (a, b) => a + b.length);
  int get uniqueTargets => _incoming.length;
}
