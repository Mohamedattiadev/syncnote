// Domain models + parsed vim modes.

class Note {
  final String id;
  final String userId;
  String title;
  String body;
  List<String> tags;
  final DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        tags: (m['tags'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'tags': tags,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Note copyWith({String? title, String? body, List<String>? tags}) => Note(
        id: id,
        userId: userId,
        title: title ?? this.title,
        body: body ?? this.body,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

enum Mode { normal, insert, visual, visualLine, cmd, search, confirmQuit }

extension ModeLabel on Mode {
  String get label => switch (this) {
        Mode.normal => 'NORMAL',
        Mode.insert => 'INSERT',
        Mode.visual => 'VISUAL',
        Mode.visualLine => 'V-LINE',
        Mode.cmd => 'COMMAND',
        Mode.search => 'SEARCH',
        Mode.confirmQuit => 'QUIT?',
      };
}

/// Which pane is focused.
enum Focus { list, detail, chat, tree }
