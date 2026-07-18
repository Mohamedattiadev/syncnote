// Same-shape RAG for CLI — takes Note list, builds a system prompt.

import 'model.dart';

String buildNotesSystemPrompt(String query, List<Note> notes,
    {int maxChars = 6000}) {
  if (notes.isEmpty) {
    return 'The user has no notes yet. Politely tell them so and suggest they '
        'create some first.';
  }
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();
  final scored = <(int, Note)>[];
  for (final n in notes) {
    final hay =
        '${n.title.toLowerCase()} ${n.body.toLowerCase()} ${n.tags.join(' ').toLowerCase()}';
    final score =
        words.isEmpty ? 0 : words.where((w) => hay.contains(w)).length;
    scored.add((score, n));
  }
  scored.sort((a, b) {
    if (a.$1 != b.$1) return b.$1.compareTo(a.$1);
    return b.$2.updatedAt.compareTo(a.$2.updatedAt);
  });

  final buf = StringBuffer();
  buf.writeln(
      'You are the user\'s personal notes assistant. Answer using ONLY the notes below. '
      'If the answer is not present, say "I don\'t see that in your notes." '
      'Cite notes by title in [brackets] when useful. Be concise.\n');
  buf.writeln('---NOTES BEGIN---');
  int used = 0;
  for (final entry in scored) {
    final n = entry.$2;
    final title = n.title.isEmpty ? '(untitled)' : n.title;
    final tags = n.tags.isEmpty ? '' : ' [tags: ${n.tags.join(', ')}]';
    final section = '\n## $title$tags\n${n.body}\n';
    if (used + section.length > maxChars) {
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
