// Export / import — one-tap backup all notes as .zip of markdown files + JSON.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import 'notes_repo.dart';

class BackupService {
  final NotesRepo repo;
  BackupService(this.repo);

  /// Build a zip: notes.json + markdown/<title>.md for each note.
  Future<Uint8List> exportAll() async {
    final notes = await repo.fetchAll();
    final archive = Archive();

    // JSON manifest for lossless restore
    final manifest = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'count': notes.length,
      'notes': notes.map((n) => n.toMap()).toList(),
    };
    final manifestBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(ArchiveFile('notes.json', manifestBytes.length, manifestBytes));

    // Markdown files for easy manual browsing
    for (final n in notes) {
      final safe = _safeName(n.title.isEmpty ? n.id.substring(0, 8) : n.title);
      final md = _toMarkdown(n);
      final bytes = utf8.encode(md);
      archive.addFile(ArchiveFile('markdown/$safe.md', bytes.length, bytes));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<String> saveExport() async {
    final zipBytes = await exportAll();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return FileSaver.instance.saveFile(
      name: 'syncnote-backup-$ts.zip',
      bytes: zipBytes,
      mimeType: MimeType.zip,
    );
  }

  /// Restore from a previously-exported archive. Notes are re-created with new IDs
  /// (to avoid clobbering existing) unless [preserveIds] is true.
  Future<int> importAll(Uint8List zipBytes, {bool preserveIds = false}) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? manifestFile;
    for (final f in archive) {
      if (f.name == 'notes.json') {
        manifestFile = f;
        break;
      }
    }
    if (manifestFile == null) {
      throw Exception('Not a SyncNote backup: notes.json missing');
    }
    final data = utf8.decode(manifestFile.content as List<int>);
    final manifest = jsonDecode(data) as Map<String, dynamic>;
    final list = manifest['notes'] as List;
    int imported = 0;
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (!preserveIds) m['id'] = const Uuid().v4();
      try {
        await repo.create(
          title: (m['title'] ?? '') as String,
          body: (m['body'] ?? '') as String,
          kind: kindFromString((m['kind'] ?? 'note') as String),
          url: m['url'] as String?,
          tags: (m['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
          folder: m['folder'] as String?,
        );
        imported++;
      } catch (_) {
        // skip individual failures
      }
    }
    return imported;
  }

  String _toMarkdown(Note n) {
    final buf = StringBuffer();
    buf.writeln('# ${n.title.isEmpty ? "(untitled)" : n.title}');
    buf.writeln();
    if (n.tags.isNotEmpty) {
      buf.writeln('_tags: ${n.tags.join(", ")}_');
      buf.writeln();
    }
    buf.writeln('_created: ${n.createdAt.toIso8601String()}_  ');
    buf.writeln('_updated: ${n.updatedAt.toIso8601String()}_');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
    buf.write(n.body);
    return buf.toString();
  }

  String _safeName(String s) {
    return s
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase()
        .substring(0, s.length > 40 ? 40 : s.length);
  }
}
