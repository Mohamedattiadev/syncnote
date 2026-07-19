// Note templates — pre-fill title + body for common note types.

class NoteTemplate {
  final String id;
  final String label;
  final String description;
  final String Function() titleFn;
  final String Function() bodyFn;
  final List<String> tags;
  const NoteTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.titleFn,
    required this.bodyFn,
    this.tags = const [],
  });
}

String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _weekday() {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[DateTime.now().weekday - 1];
}

final kTemplates = <NoteTemplate>[
  NoteTemplate(
    id: 'daily',
    label: 'Daily note',
    description: 'Journal entry for today',
    titleFn: () => 'Daily · ${_today()} (${_weekday()})',
    bodyFn: () => '''
## Today
- [ ]

## Notes


## Wins


## Tomorrow
- [ ]
''',
    tags: const ['daily'],
  ),
  NoteTemplate(
    id: 'meeting',
    label: 'Meeting notes',
    description: 'Attendees, agenda, actions',
    titleFn: () => 'Meeting · ${_today()}',
    bodyFn: () => '''
**Date:** ${_today()}
**Attendees:**

## Agenda


## Discussion


## Decisions


## Action items
- [ ]
''',
    tags: const ['meeting', 'work'],
  ),
  NoteTemplate(
    id: 'idea',
    label: 'Idea',
    description: 'Quick brainstorm frame',
    titleFn: () => 'Idea · ',
    bodyFn: () => '''
## What?


## Why does this matter?


## First step


## References

''',
    tags: const ['idea'],
  ),
  NoteTemplate(
    id: 'blank',
    label: 'Blank',
    description: 'Empty note',
    titleFn: () => '',
    bodyFn: () => '',
  ),
];
