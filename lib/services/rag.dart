// Simple context RAG — no embeddings.
// Fetches all notes, ranks by keyword overlap with query, packs top-K into
// a system prompt within a token budget.

import '../models/note.dart';

class RagBuilder {
  /// Approx char budget for the notes context. 4 chars ~= 1 token.
  final int maxChars;
  const RagBuilder({this.maxChars = 6000});

  String buildSystemPrompt(String query, List<Note> notes) {
    if (notes.isEmpty) {
      return 'The user has no notes yet. Politely tell them so and suggest they '
          'create some first.';
    }

    final ranked = _rank(query, notes);
    final buf = StringBuffer();
    buf.writeln(
        'You are the user\'s personal notes assistant. Read the notes below and answer questions about them. '
        'If the answer is not in the notes, say "I don\'t see that in your notes." '
        'If the user asks to CREATE a note, tell them: "Say `/note Title` or `create note called X, content Y` and I will save it." '
        'Cite notes by their title in [brackets] when useful. Be concise.\n');
    buf.writeln('---NOTES BEGIN---');
    int used = 0;
    for (final n in ranked) {
      final title = n.title.isEmpty ? '(untitled)' : n.title;
      final tags = n.tags.isEmpty ? '' : ' [tags: ${n.tags.join(', ')}]';
      final section = '\n## $title$tags\n${n.body}\n';
      if (used + section.length > maxChars) {
        // Truncate this note to fit.
        final remain = maxChars - used - 200;
        if (remain > 200) {
          buf.write('\n## $title$tags\n');
          buf.write(n.body.substring(0, n.body.length.clamp(0, remain)));
          buf.write('\n… (truncated)\n');
        }
        break;
      }
      buf.write(section);
      used += section.length;
    }
    buf.writeln('---NOTES END---');
    return buf.toString();
  }

  /// Rank notes by keyword-hit count against query; ties broken by recency.
  List<Note> _rank(String query, List<Note> notes) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
    if (words.isEmpty) {
      final sorted = [...notes];
      sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted;
    }
    final scored = notes.map((n) {
      final hay =
          '${n.title.toLowerCase()} ${n.body.toLowerCase()} ${n.tags.join(' ').toLowerCase()}';
      final score = words.where((w) => hay.contains(w)).length;
      return (score, n);
    }).toList();
    scored.sort((a, b) {
      if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
      return b.$2.updatedAt.compareTo(a.$2.updatedAt);
    });
    return scored.map((e) => e.$2).toList();
  }
}
