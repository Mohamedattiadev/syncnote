import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import 'local_cache.dart';
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

    // Wrap Supabase stream so we push each snapshot into local cache
    // AND emit local cache immediately (so UI is never empty on cold boot).
    late final StreamController<List<Note>> ctrl;
    StreamSubscription? sub;
    ctrl = StreamController<List<Note>>(
      onListen: () async {
        // Immediate cache read while network resolves
        final cached = await LocalCache.readAll(uid);
        if (cached.isNotEmpty && !ctrl.isClosed) ctrl.add(cached);

        sub = _client
            .from('notes')
            .stream(primaryKey: ['id'])
            .eq('user_id', uid)
            .order('updated_at', ascending: false)
            .map((rows) => rows.map(Note.fromMap).toList())
            .listen((notes) {
          if (!ctrl.isClosed) ctrl.add(notes);
          unawaited(LocalCache.writeAll(notes));
        }, onError: (e) {
          // silent — user still sees cache
        });
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return ctrl.stream;
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
    // Write to cache first — instant UI feedback + offline survival
    unawaited(LocalCache.upsert(note));
    try {
      await _client.from('notes').insert(note.toMap());
    } catch (e) {
      // Offline — queue for later sync
      unawaited(LocalCache.queueOp(
          op: 'insert', noteId: note.id, payload: note.toMap()));
    }
    return note;
  }

  @override
  Future<void> update(Note n) async {
    final updated = n.copyWith(updatedAt: DateTime.now().toUtc());
    unawaited(LocalCache.upsert(updated));
    try {
      await _client.from('notes').update(updated.toMap()).eq('id', n.id);
    } catch (e) {
      unawaited(LocalCache.queueOp(
          op: 'update', noteId: n.id, payload: updated.toMap()));
    }
  }

  @override
  Future<void> delete(String id) async {
    unawaited(LocalCache.delete(id));
    try {
      await _client.from('notes').delete().eq('id', id);
    } catch (e) {
      unawaited(LocalCache.queueOp(op: 'delete', noteId: id));
    }
  }

  /// Called when app comes back online — drain pending offline ops.
  Future<int> syncPending() async {
    final ops = await LocalCache.readPendingOps();
    int done = 0;
    for (final op in ops) {
      final id = op['id'] as int;
      final kind = op['op'] as String;
      try {
        switch (kind) {
          case 'insert':
            await _client.from('notes').insert(
                jsonDecode(op['payload'] as String) as Map<String, dynamic>);
            break;
          case 'update':
            await _client
                .from('notes')
                .update(
                    jsonDecode(op['payload'] as String) as Map<String, dynamic>)
                .eq('id', op['note_id'] as String);
            break;
          case 'delete':
            await _client.from('notes').delete().eq('id', op['note_id'] as String);
            break;
        }
        await LocalCache.removeOp(id);
        done++;
      } catch (_) {
        // still offline — leave for next attempt
        break;
      }
    }
    return done;
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
