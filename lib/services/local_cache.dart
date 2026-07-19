// Local SQLite cache for offline mode.
// Mirrors the `notes` table + a `pending_ops` queue for writes made offline.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

class LocalCache {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    if (Platform.isLinux || Platform.isWindows) {
      // sqflite_common_ffi handled by pkg; for desktop we skip cache (Web/mobile only)
      // In practice this fallback is fine for dev; production mobile paths reach here.
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'syncnote_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            kind TEXT NOT NULL DEFAULT 'note',
            url TEXT,
            tags TEXT NOT NULL DEFAULT '[]',
            folder TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await d.execute(
            'CREATE INDEX notes_user_updated ON notes(user_id, updated_at DESC)');
        await d.execute('''
          CREATE TABLE pending_ops (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            op TEXT NOT NULL,          -- 'insert' | 'update' | 'delete'
            note_id TEXT NOT NULL,
            payload TEXT,               -- JSON of the note (for insert/update)
            queued_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<List<Note>> readAll(String userId) async {
    try {
      final rows = await (await db).query(
        'notes',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(_rowToNote).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> writeAll(List<Note> notes) async {
    try {
      final d = await db;
      await d.transaction((txn) async {
        for (final n in notes) {
          await txn.insert(
            'notes',
            _noteToRow(n),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (_) {}
  }

  static Future<void> upsert(Note n) async {
    try {
      await (await db).insert(
        'notes',
        _noteToRow(n),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  static Future<void> delete(String id) async {
    try {
      await (await db).delete('notes', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<void> queueOp({
    required String op,
    required String noteId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await (await db).insert('pending_ops', {
        'op': op,
        'note_id': noteId,
        'payload': payload == null ? null : jsonEncode(payload),
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> readPendingOps() async {
    try {
      return await (await db).query('pending_ops', orderBy: 'queued_at ASC');
    } catch (_) {
      return const [];
    }
  }

  static Future<void> removeOp(int id) async {
    try {
      await (await db).delete('pending_ops', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Map<String, dynamic> _noteToRow(Note n) => {
        'id': n.id,
        'user_id': n.userId,
        'title': n.title,
        'body': n.body,
        'kind': n.kind.name,
        'url': n.url,
        'tags': jsonEncode(n.tags),
        'folder': n.folder,
        'created_at': n.createdAt.toIso8601String(),
        'updated_at': n.updatedAt.toIso8601String(),
      };

  static Note _rowToNote(Map<String, dynamic> r) => Note(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        title: (r['title'] ?? '') as String,
        body: (r['body'] ?? '') as String,
        kind: kindFromString((r['kind'] ?? 'note') as String),
        url: r['url'] as String?,
        tags: (jsonDecode((r['tags'] ?? '[]') as String) as List)
            .map((e) => e as String)
            .toList(),
        folder: r['folder'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );
}
