// Dispatcher tests — drive keys, assert state transitions.

import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/state.dart';


Key rune(String r) => Key('rune', r);

void main() {
  group('Normal mode motions', () {
    test('j moves list cursor down', () {
      final s = _stateWith3Notes();
      dispatch(s, rune('j'));
      expect(s.listCursor, 1);
      dispatch(s, rune('j'));
      expect(s.listCursor, 2);
      dispatch(s, rune('j'));
      expect(s.listCursor, 2); // clamped
    });

    test('k moves up, clamped at 0', () {
      final s = _stateWith3Notes();
      dispatch(s, rune('j'));
      dispatch(s, rune('k'));
      expect(s.listCursor, 0);
    });

    test('gg jumps to top, G to bottom', () {
      final s = _stateWith3Notes();
      dispatch(s, rune('G'));
      expect(s.listCursor, 2);
      dispatch(s, rune('g'));
      dispatch(s, rune('g'));
      expect(s.listCursor, 0);
    });

    test('<tab>j = 5x down (nvim boost)', () {
      final s = _stateWith(8);
      dispatch(s, const Key('tab'));
      dispatch(s, rune('j'));
      expect(s.listCursor, 5);
    });

    test('H/L in list = 5x up/down', () {
      final s = _stateWith(10);
      dispatch(s, rune('L'));
      expect(s.listCursor, 5);
      dispatch(s, rune('H'));
      expect(s.listCursor, 0);
    });
  });

  group('Vim modes', () {
    test('Enter opens detail; q closes it', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      expect(s.focus, Focus.detail);
      expect(s.current, isNotNull);
      dispatch(s, rune('q'));
      expect(s.focus, Focus.list);
    });

    test('i enters INSERT mode inside detail', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      expect(s.mode, Mode.insert);
    });

    test('typing in INSERT edits active buffer', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, rune('h'));
      dispatch(s, rune('i'));
      // fieldIdx = 2 (body) after openNoteForEdit
      expect(s.bodyBuf.text.startsWith('hi'), isTrue);
    });

    test('Esc exits INSERT', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, const Key('esc'));
      expect(s.mode, Mode.normal);
    });

    test('v starts VISUAL, y yanks, exits', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      // body starts empty — put text via insert then normalize back
      dispatch(s, rune('i'));
      for (final c in 'hello world'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('esc'));
      dispatch(s, rune('0')); // start of line
      dispatch(s, rune('v'));
      dispatch(s, rune('l'));
      dispatch(s, rune('l'));
      dispatch(s, rune('l'));
      dispatch(s, rune('l'));
      dispatch(s, rune('y'));
      expect(s.register, 'hello');
      expect(s.mode, Mode.normal);
    });
  });

  group('Command line (:)', () {
    test(':q returns quit result', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(':'));
      dispatch(s, rune('q'));
      final r = dispatch(s, const Key('enter'));
      expect(r.quit, isTrue);
    });

    test(':new returns create result', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(':'));
      for (final c in 'new'.split('')) {
        dispatch(s, rune(c));
      }
      final r = dispatch(s, const Key('enter'));
      expect(r.create, isTrue);
    });

    test(':reload returns needsReload', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(':'));
      for (final c in 'reload'.split('')) {
        dispatch(s, rune(c));
      }
      final r = dispatch(s, const Key('enter'));
      expect(r.needsReload, isTrue);
    });
  });

  group('Leader (space) chords', () {
    test('<space>q quits', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(' '));
      final r = dispatch(s, rune('q'));
      expect(r.quit, isTrue);
    });

    test('<space>bd deletes note', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(' '));
      dispatch(s, rune('b'));
      final r = dispatch(s, rune('d'));
      expect(r.delete, isTrue);
    });

    test('<space>bn creates note', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(' '));
      dispatch(s, rune('b'));
      final r = dispatch(s, rune('n'));
      expect(r.create, isTrue);
    });

    test('<space>fg opens SEARCH', () {
      final s = _stateWith3Notes();
      dispatch(s, rune(' '));
      dispatch(s, rune('f'));
      dispatch(s, rune('g'));
      expect(s.mode, Mode.search);
    });
  });

  group('Search', () {
    test('/ opens search, Esc cancels', () {
      final s = _stateWith3Notes();
      dispatch(s, rune('/'));
      expect(s.mode, Mode.search);
      dispatch(s, const Key('esc'));
      expect(s.mode, Mode.normal);
    });

    test('search filters list', () {
      final s = _stateWith3Notes();
      dispatch(s, rune('/'));
      for (final c in 'two'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.filtered().length, 1);
      expect(s.filtered().first.title, 'note two');
    });
  });

  group('Yank/delete/paste', () {
    test('dd requests delete (list) or deletes line (detail)', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter')); // into detail
      dispatch(s, rune('i'));
      for (final c in 'a\nb\nc'.split('')) {
        if (c == '\n') {
          dispatch(s, const Key('enter'));
        } else {
          dispatch(s, rune(c));
        }
      }
      dispatch(s, const Key('esc'));
      dispatch(s, rune('g'));
      dispatch(s, rune('g'));
      dispatch(s, rune('d'));
      dispatch(s, rune('d'));
      expect(s.bodyBuf.text, 'b\nc');
      expect(s.register, 'a\n');
    });

    test('yy yanks current line, p pastes', () {
      final s = _stateWith3Notes();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      for (final c in 'foo\nbar'.split('')) {
        if (c == '\n') {
          dispatch(s, const Key('enter'));
        } else {
          dispatch(s, rune(c));
        }
      }
      dispatch(s, const Key('esc'));
      dispatch(s, rune('g')); dispatch(s, rune('g'));
      dispatch(s, rune('y')); dispatch(s, rune('y'));
      expect(s.register, 'foo');
      dispatch(s, rune('p'));
      expect(s.bodyBuf.text, 'foo\nfoo\nbar');
    });
  });
}

// ---------- helpers ----------

AppState _stateWith(int count) {
  final s = AppState()..splashDismissed = true;
  final now = DateTime.now().toUtc();
  s.notes = List.generate(
    count,
    (i) => Note(
      id: 'id-$i',
      userId: 'u',
      title: 'note ${_word(i)}',
      body: '',
      tags: const [],
      createdAt: now,
      updatedAt: now,
    ),
  );
  return s;
}

AppState _stateWith3Notes() => _stateWith(3);

String _word(int i) => const ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'][i % 10];
