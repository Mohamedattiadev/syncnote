// Tests for power-user upgrades: counts, dot-repeat, char search,
// substitute, :e, :<N>, marks, :set, quit-all.

import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/state.dart';

Key rune(String r) => Key('rune', r);

AppState _state({int count = 3}) {
  final s = AppState()..splashDismissed = true;
  final now = DateTime.now().toUtc();
  s.notes = List.generate(
    count,
    (i) => Note(
      id: 'id-$i',
      userId: 'u',
      title: 'note-$i',
      body: '',
      tags: const [],
      createdAt: now,
      updatedAt: now,
    ),
  );
  return s;
}

/// Open detail buffer with the given multiline body.
AppState _detail(String body) {
  final s = _state();
  dispatch(s, const Key('enter'));
  dispatch(s, rune('i'));
  for (final ch in body.split('')) {
    if (ch == '\n') {
      dispatch(s, const Key('enter'));
    } else {
      dispatch(s, rune(ch));
    }
  }
  dispatch(s, const Key('esc'));
  dispatch(s, rune('g'));
  dispatch(s, rune('g'));
  dispatch(s, rune('0'));
  return s;
}

void _type(AppState s, String seq) {
  for (final ch in seq.split('')) {
    dispatch(s, rune(ch));
  }
}

void main() {
  group('Count prefixes', () {
    test('5j moves list cursor 5 down', () {
      final s = _state(count: 10);
      _type(s, '5j');
      expect(s.listCursor, 5);
      expect(s.pendingCount, isEmpty);
    });

    test('10k after G clamps at 0', () {
      final s = _state(count: 10);
      dispatch(s, rune('G'));
      expect(s.listCursor, 9);
      _type(s, '10k');
      expect(s.listCursor, 0);
    });

    test('15G jumps to line N in detail', () {
      final s = _detail('a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\nm\nn\no\np');
      _type(s, '15G');
      expect(s.activeBuf.cursor.row, 14);
    });

    test('3j in detail', () {
      final s = _detail('one\ntwo\nthree\nfour\nfive');
      _type(s, '3j');
      expect(s.activeBuf.cursor.row, 3);
    });

    test('5dd deletes 5 lines', () {
      final s = _detail('a\nb\nc\nd\ne\nf\ng');
      _type(s, '5dd');
      expect(s.activeBuf.text, 'f\ng');
    });

    test('3yy yanks 3 lines', () {
      final s = _detail('one\ntwo\nthree\nfour');
      _type(s, '3yy');
      expect(s.register, 'one\ntwo\nthree');
      expect(s.registerLinewise, isTrue);
    });

    test("'0' alone is not a count (goes to line start)", () {
      final s = _detail('hello world');
      _type(s, 'll');
      expect(s.activeBuf.cursor.col, 2);
      dispatch(s, rune('0'));
      expect(s.activeBuf.cursor.col, 0);
      expect(s.pendingCount, isEmpty);
    });
  });

  group('. repeat', () {
    test('. repeats x', () {
      final s = _detail('abcdef');
      dispatch(s, rune('x')); // delete 'a'
      expect(s.activeBuf.text, 'bcdef');
      dispatch(s, rune('.'));
      expect(s.activeBuf.text, 'cdef');
    });

    test('. repeats insert text', () {
      final s = _detail('X');
      dispatch(s, rune('A')); // append at end of line
      _type(s, 'YZ');
      dispatch(s, const Key('esc'));
      expect(s.activeBuf.text, 'XYZ');
      dispatch(s, rune('.'));
      expect(s.activeBuf.text.contains('YZ'), isTrue);
    });

    test('. repeats dd', () {
      final s = _detail('a\nb\nc\nd');
      dispatch(s, rune('d'));
      dispatch(s, rune('d'));
      expect(s.activeBuf.text, 'b\nc\nd');
      dispatch(s, rune('.'));
      expect(s.activeBuf.text, 'c\nd');
    });
  });

  group('f/F/t/T char search', () {
    test('f{c} jumps to next char on line', () {
      final s = _detail('hello world');
      dispatch(s, rune('f'));
      dispatch(s, rune('w'));
      expect(s.activeBuf.cursor.col, 6);
    });

    test('t{c} jumps up to char', () {
      final s = _detail('hello world');
      dispatch(s, rune('t'));
      dispatch(s, rune('w'));
      expect(s.activeBuf.cursor.col, 5);
    });

    test('; repeats last f', () {
      final s = _detail('a.b.c.d');
      dispatch(s, rune('f'));
      dispatch(s, rune('.'));
      expect(s.activeBuf.cursor.col, 1);
      dispatch(s, rune(';'));
      expect(s.activeBuf.cursor.col, 3);
      dispatch(s, rune(';'));
      expect(s.activeBuf.cursor.col, 5);
    });

    test(', reverses last f', () {
      final s = _detail('a.b.c');
      dispatch(s, rune('f'));
      dispatch(s, rune('.'));
      dispatch(s, rune(';'));
      expect(s.activeBuf.cursor.col, 3);
      dispatch(s, rune(','));
      expect(s.activeBuf.cursor.col, 1);
    });
  });

  group(':s substitute', () {
    test(':s/foo/bar/ replaces first on current line', () {
      final s = _detail('foo foo foo');
      _type(s, ':s/foo/bar/');
      dispatch(s, const Key('enter'));
      expect(s.activeBuf.text, 'bar foo foo');
      expect(s.toast, contains('1 substitutions'));
    });

    test(':s/foo/bar/g replaces all on current line', () {
      final s = _detail('foo foo foo');
      _type(s, ':s/foo/bar/g');
      dispatch(s, const Key('enter'));
      expect(s.activeBuf.text, 'bar bar bar');
    });

    test(':%s/foo/bar/g replaces across all lines', () {
      final s = _detail('foo\nfoo bar\nbaz foo');
      _type(s, ':%s/foo/X/g');
      dispatch(s, const Key('enter'));
      expect(s.activeBuf.text, 'X\nX bar\nbaz X');
    });

    test(':s snapshots for undo', () {
      final s = _detail('hello');
      _type(s, ':s/hello/world/');
      dispatch(s, const Key('enter'));
      expect(s.activeBuf.text, 'world');
      dispatch(s, rune('u'));
      expect(s.activeBuf.text, 'hello');
    });
  });

  group(':e fuzzy open', () {
    test(':e note-1 opens matching note', () {
      final s = _state(count: 3);
      _type(s, ':e note-1');
      dispatch(s, const Key('enter'));
      expect(s.focus, Focus.detail);
      expect(s.current!.title, 'note-1');
    });

    test(':e nope toasts no match', () {
      final s = _state();
      _type(s, ':e zzzzzz');
      dispatch(s, const Key('enter'));
      expect(s.focus, Focus.list);
      expect(s.toastErr, isTrue);
    });
  });

  group(':<N> line jump', () {
    test(':5 jumps to line 5 in detail', () {
      final s = _detail('1\n2\n3\n4\n5\n6\n7');
      _type(s, ':5');
      dispatch(s, const Key('enter'));
      expect(s.activeBuf.cursor.row, 4);
    });
  });

  group('marks', () {
    test("m{a} + '{a} jumps to mark row", () {
      final s = _detail('a\nb\nc\nd\ne');
      _type(s, '3j'); // cursor row 3
      dispatch(s, rune('m'));
      dispatch(s, rune('a'));
      dispatch(s, rune('g'));
      dispatch(s, rune('g'));
      expect(s.activeBuf.cursor.row, 0);
      dispatch(s, rune("'"));
      dispatch(s, rune('a'));
      expect(s.activeBuf.cursor.row, 3);
    });
  });

  group(':set', () {
    test(':set nowrap sets wrapMode false', () {
      final s = _state();
      _type(s, ':set nowrap');
      dispatch(s, const Key('enter'));
      expect(s.wrapMode, isFalse);
      _type(s, ':set wrap');
      dispatch(s, const Key('enter'));
      expect(s.wrapMode, isTrue);
    });

    test(':set nonumber toggles line numbers off', () {
      final s = _state();
      _type(s, ':set nonumber');
      dispatch(s, const Key('enter'));
      expect(s.showNumbers, isFalse);
    });
  });

  group('quit-all commands', () {
    test(':qa quits', () {
      final s = _state();
      _type(s, ':qa');
      final r = dispatch(s, const Key('enter'));
      expect(r.quit, isTrue);
    });

    test(':wqa saves and quits', () {
      final s = _state();
      _type(s, ':wqa');
      final r = dispatch(s, const Key('enter'));
      expect(r.quit, isTrue);
      expect(r.save, isTrue);
    });

    test(':qa! discards dirty and quits', () {
      final s = _detail('hi');
      s.dirty = true;
      _type(s, ':qa!');
      final r = dispatch(s, const Key('enter'));
      expect(r.quit, isTrue);
    });
  });

  group(':pwd', () {
    test(':pwd toasts a non-empty path', () {
      final s = _state();
      _type(s, ':pwd');
      dispatch(s, const Key('enter'));
      expect(s.toast, isNotEmpty);
    });
  });
}
