import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/note.dart';

/// In-memory NotesRepo-alike used when Supabase isn't configured yet.
/// Same shape as NotesRepo so UI code is identical.
class MockNotesRepo {
  final _uuid = const Uuid();
  final _notes = <Note>[];
  final _controller = StreamController<List<Note>>.broadcast();

  MockNotesRepo() {
    _seed();
  }

  void _seed() {
    final now = DateTime.now().toUtc();
    _notes.addAll([
      Note(
        id: _uuid.v4(),
        userId: 'demo',
        title: 'Welcome to SyncNote',
        body: '# 👋 Welcome\n\n'
            'This is **demo mode** — everything runs in memory. '
            'Set up Supabase to sync across devices.\n\n'
            '## Try it\n\n'
            '- Tap + to create a note\n'
            '- Long-press a note to delete\n'
            '- Toggle the eye icon in editor for markdown preview\n\n'
            '## Markdown works\n\n'
            '```dart\nvoid main() => print("hello");\n```\n\n'
            '> quotes render\n\n'
            'Bold **works**, _italic_ works, [links](https://supabase.com) work.',
        kind: NoteKind.note,
        tags: ['welcome', 'demo'],
        createdAt: now.subtract(const Duration(minutes: 1)),
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
      Note(
        id: _uuid.v4(),
        userId: 'demo',
        title: 'Meeting notes — Q1 planning',
        body: '## Attendees\n- Alice\n- Bob\n\n## Decisions\n- Ship v1 in Feb\n- Skip iOS for MVP',
        kind: NoteKind.note,
        tags: ['work'],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Note(
        id: _uuid.v4(),
        userId: 'demo',
        title: 'Interesting article on RAG',
        body: 'Great read on retrieval augmented generation.',
        url: 'https://example.com/rag',
        kind: NoteKind.link,
        tags: ['ai', 'reading'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
    _emit();
  }

  void _emit() {
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _controller.add(List.unmodifiable(_notes));
  }

  Stream<List<Note>> watchAll() => _controller.stream;

  Future<Note> create({
    required String title,
    required String body,
    NoteKind kind = NoteKind.note,
    String? url,
    List<String> tags = const [],
    String? folder,
  }) async {
    final now = DateTime.now().toUtc();
    final n = Note(
      id: _uuid.v4(),
      userId: 'demo',
      title: title,
      body: body,
      kind: kind,
      url: url,
      tags: tags,
      folder: folder,
      createdAt: now,
      updatedAt: now,
    );
    _notes.add(n);
    _emit();
    return n;
  }

  Future<void> update(Note n) async {
    final i = _notes.indexWhere((x) => x.id == n.id);
    if (i < 0) return;
    _notes[i] = n.copyWith(updatedAt: DateTime.now().toUtc());
    _emit();
  }

  Future<void> delete(String id) async {
    _notes.removeWhere((n) => n.id == id);
    _emit();
  }
}
