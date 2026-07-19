// Parse ```syncnote-action { ... } ``` code blocks from AI output
// and execute create / update / delete on the notes repo.

import 'dart:convert';

import '../models/note.dart';
import 'notes_repo.dart';

class AiAction {
  final String kind; // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  const AiAction(this.kind, this.payload);
}

class AiActionRunner {
  final NotesRepo repo;
  AiActionRunner(this.repo);

  static final _blockRegex = RegExp(
    r'```syncnote-action\s*([\s\S]*?)```',
    multiLine: true,
  );

  /// Extract action blocks from an AI reply. Skips malformed JSON silently.
  List<AiAction> parse(String reply) {
    final out = <AiAction>[];
    for (final match in _blockRegex.allMatches(reply)) {
      final raw = (match.group(1) ?? '').trim();
      try {
        final obj = jsonDecode(raw) as Map<String, dynamic>;
        final action = (obj['action'] ?? '') as String;
        if (['create', 'update', 'delete'].contains(action)) {
          out.add(AiAction(action, obj));
        }
      } catch (_) {}
    }
    return out;
  }

  /// Returns a human summary of what was done.
  Future<String> execute(List<AiAction> actions) async {
    if (actions.isEmpty) return '';
    final results = <String>[];
    for (final a in actions) {
      try {
        switch (a.kind) {
          case 'create':
            final n = await repo.create(
              title: (a.payload['title'] ?? '') as String,
              body: (a.payload['body'] ?? '') as String,
              kind: kindFromString((a.payload['kind'] ?? 'note') as String),
              tags: (a.payload['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
            );
            results.add('✓ created "${n.title}"');
            break;
          case 'update':
            // Update requires we fetch the note first — repo doesn't expose by-id,
            // so we skip for now (would need a fetch-single or full-fetch and find).
            results.add('~ update skipped (not yet implemented)');
            break;
          case 'delete':
            final id = a.payload['id'] as String?;
            if (id != null) {
              await repo.delete(id);
              results.add('✗ deleted note $id');
            }
            break;
        }
      } catch (e) {
        results.add('! failed ${a.kind}: $e');
      }
    }
    return results.join('\n');
  }

  /// Strip action blocks from reply so the user only sees the prose.
  String stripBlocks(String reply) =>
      reply.replaceAll(_blockRegex, '').trim();
}
