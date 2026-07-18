enum NoteKind { note, link, file }

NoteKind kindFromString(String s) => switch (s) {
      'link' => NoteKind.link,
      'file' => NoteKind.file,
      _ => NoteKind.note,
    };

class Note {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NoteKind kind;
  final String? url;
  final List<String> tags;
  final String? folder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.kind,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    this.folder,
  });

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        kind: kindFromString((m['kind'] ?? 'note') as String),
        url: m['url'] as String?,
        tags: (m['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
        folder: m['folder'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'kind': kind.name,
        'url': url,
        'tags': tags,
        'folder': folder,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Note copyWith({
    String? title,
    String? body,
    NoteKind? kind,
    String? url,
    List<String>? tags,
    String? folder,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        body: body ?? this.body,
        kind: kind ?? this.kind,
        url: url ?? this.url,
        tags: tags ?? this.tags,
        folder: folder ?? this.folder,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get icon => switch (kind) {
        NoteKind.note => '📝',
        NoteKind.link => '🔖',
        NoteKind.file => '📄',
      };

  /// Material icon codepoint for the note kind — used in Flutter UI so we can
  /// avoid emoji and render crisp vector icons at any size.
  int get iconCodePoint => switch (kind) {
        NoteKind.note => 0xe266, // Icons.notes
        NoteKind.link => 0xe157, // Icons.link
        NoteKind.file => 0xe226, // Icons.description
      };
}
