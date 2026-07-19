// Tests for organization commands: :sort, :g/pat/d, :daily, wiki-links.

import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/state.dart';

Key rune(String r) => Key('rune', r);

AppState _detail(String body) {
  final s = AppState()..splashDismissed = true;
  final now = DateTime.now().toUtc();
  s.notes = [
    Note(id: 'a', userId: 'u', title: 't', body: '', tags: const [],
        createdAt: now, updatedAt: now),
  ];
  dispatch(s, const Key('enter'));
  dispatch(s, rune('i'));
  for (final ch in body.split('')) {
    if (ch == '\n') { dispatch(s, const Key('enter')); }
    else { dispatch(s, rune(ch)); }
  }
  dispatch(s, const Key('esc'));
  return s;
}

void _cmd(AppState s, String c) {
  dispatch(s, rune(':'));
  for (final ch in c.split('')) { dispatch(s, rune(ch)); }
  dispatch(s, const Key('enter'));
}

void main() {
  group('wiki-links', () {
    test('extracts [[title]] tokens', () {
      expect(extractWikiLinks('see [[Foo]] and [[Bar Baz]]'),
          ['Foo', 'Bar Baz']);
    });
    test('empty when no links', () {
      expect(extractWikiLinks('nothing here'), isEmpty);
    });
    test('trims whitespace', () {
      expect(extractWikiLinks('[[  spacey  ]]'), ['spacey']);
    });
  });

  group(':sort', () {
    test('sorts buffer lines', () {
      final s = _detail('c\nb\na');
      _cmd(s, 'sort');
      expect(s.activeBuf.lines, ['a', 'b', 'c']);
    });
    test(':sort! reverses', () {
      final s = _detail('a\nb\nc');
      _cmd(s, 'sort!');
      expect(s.activeBuf.lines, ['c', 'b', 'a']);
    });
    test(':sortu removes duplicates', () {
      final s = _detail('b\na\nb\nc\na');
      _cmd(s, 'sortu');
      expect(s.activeBuf.lines, ['a', 'b', 'c']);
    });
  });

  group(':g/pat/d', () {
    test('deletes matching lines', () {
      final s = _detail('keep\ndrop foo\nkeep\ndrop bar');
      _cmd(s, 'g/drop/d');
      expect(s.activeBuf.lines, ['keep', 'keep']);
    });
    test(':v/pat/d keeps only matching', () {
      final s = _detail('a-good\nb-bad\nc-good');
      _cmd(s, 'v/good/d');
      expect(s.activeBuf.lines, ['a-good', 'c-good']);
    });
  });
}
