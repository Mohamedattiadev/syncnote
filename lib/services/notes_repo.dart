import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import 'mock_repo.dart';

/// Shared repo interface — SupabaseNotesRepo or MockNotesRepo satisfy this.
abstract class NotesRepo {
  Stream<List<Note>> watchAll();
  Future<List<Note>> fetchAll();
  Future<Note> create({
    required String title,
    required String body,
    NoteKind kind = NoteKind.note,
    String? url,
    List<String> tags = const [],
    String? folder,
  });
  Future<void> update(Note n);
  Future<void> delete(String id);
}

class SupabaseNotesRepo implements NotesRepo {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  SupabaseNotesRepo(this._client);

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Stream<List<Note>> watchAll() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('updated_at', ascending: false)
        .map((rows) => rows.map(Note.fromMap).toList());
  }

  @override
  Future<List<Note>> fetchAll() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from('notes')
        .select()
        .eq('user_id', uid)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => Note.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Note> create({
    required String title,
    required String body,
    NoteKind kind = NoteKind.note,
    String? url,
    List<String> tags = const [],
    String? folder,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('not signed in');
    final now = DateTime.now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      userId: uid,
      title: title,
      body: body,
      kind: kind,
      url: url,
      tags: tags,
      folder: folder,
      createdAt: now,
      updatedAt: now,
    );
    await _client.from('notes').insert(note.toMap());
    return note;
  }

  @override
  Future<void> update(Note n) async {
    await _client
        .from('notes')
        .update(n.copyWith(updatedAt: DateTime.now().toUtc()).toMap())
        .eq('id', n.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('notes').delete().eq('id', id);
  }
}

/// Wraps MockNotesRepo so it implements NotesRepo interface.
class MockRepoAdapter implements NotesRepo {
  final MockNotesRepo _inner;
  MockRepoAdapter(this._inner);

  @override
  Stream<List<Note>> watchAll() => _inner.watchAll();

  @override
  Future<List<Note>> fetchAll() async {
    final stream = _inner.watchAll();
    return await stream.first;
  }

  @override
  Future<Note> create({
    required String title,
    required String body,
    NoteKind kind = NoteKind.note,
    String? url,
    List<String> tags = const [],
    String? folder,
  }) =>
      _inner.create(
        title: title,
        body: body,
        kind: kind,
        url: url,
        tags: tags,
        folder: folder,
      );

  @override
  Future<void> update(Note n) => _inner.update(n);

  @override
  Future<void> delete(String id) => _inner.delete(id);
}
