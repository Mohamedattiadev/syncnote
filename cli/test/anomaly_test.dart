// Anomaly / edge-case tests — hunt for bugs.
//
// Every failure here is a real bug. Categories:
// - empty / boundary states
// - unicode
// - very long content
// - rapid mode switching
// - pending prefix interactions
// - undo/redo history semantics
// - search edge cases
// - buffer edge cases

import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/state.dart';
import 'package:syncnote_cli/vim.dart';

Key rune(String r) => Key('rune', r);

AppState _state({int count = 3, List<String>? tags}) {
  final s = AppState()..splashDismissed = true;
  final now = DateTime.now().toUtc();
  s.notes = List.generate(
    count,
    (i) => Note(
      id: 'id-$i',
      userId: 'u',
      title: 'note ${i + 1}',
      body: 'body $i',
      tags: tags ?? (i == 0 ? ['work'] : []),
      createdAt: now,
      updatedAt: now,
    ),
  );
  return s;
}

void main() {
  group('Empty state edge cases', () {
    test('empty notes list: j/k does not crash', () {
      final s = AppState()..splashDismissed = true;
      s.notes = [];
      dispatch(s, rune('j'));
      dispatch(s, rune('k'));
      dispatch(s, rune('G'));
      dispatch(s, rune('g'));
      dispatch(s, rune('g'));
      expect(s.listCursor, isIn([0, -1, 0])); // clamped or -1
    });

    test('empty notes: Enter does not crash', () {
      final s = AppState()..splashDismissed = true;
      s.notes = [];
      dispatch(s, const Key('enter'));
      expect(s.focus, Focus.list); // stayed
    });

    test('empty notes: yy does nothing safely', () {
      final s = AppState()..splashDismissed = true;
      s.notes = [];
      dispatch(s, rune('y'));
      dispatch(s, rune('y'));
      expect(s.register, isEmpty);
    });

    test('empty notes: dd requests delete but nothing happens', () {
      final s = AppState()..splashDismissed = true;
      s.notes = [];
      dispatch(s, rune('d'));
      final r = dispatch(s, rune('d'));
      expect(r.delete, isTrue); // signals delete; caller handles no-op
    });

    test('empty buffer: hjkl bounds', () {
      final b = Buffer.fromText('');
      b.moveLeft(100);
      b.moveRight(100);
      b.moveUp(100);
      b.moveDown(100);
      expect(b.cursor.row, 0);
      expect(b.cursor.col, 0);
    });

    test('empty buffer: backspace does not crash', () {
      final b = Buffer.fromText('');
      b.backspace();
      expect(b.text, '');
    });

    test('empty buffer: deleteLine returns empty and does not crash', () {
      final b = Buffer.fromText('');
      final r = b.deleteLine();
      expect(r, contains('\n'));
      expect(b.text, '');
    });
  });

  group('Unicode', () {
    test('emoji in title survives yy', () {
      final s = AppState()..splashDismissed = true;
      final now = DateTime.now().toUtc();
      s.notes = [
        Note(
          id: 'x',
          userId: 'u',
          title: '🚀 launch plan',
          body: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
        ),
      ];
      dispatch(s, rune('y'));
      dispatch(s, rune('y'));
      expect(s.register, '🚀 launch plan');
    });

    test('arabic/rtl text in body: motion does not crash', () {
      final b = Buffer.fromText('مرحبا يا عالم');
      b.moveRight(5);
      b.moveLeft(2);
      b.wordForward();
      b.wordBack();
      expect(b.cursor.col, greaterThanOrEqualTo(0));
    });

    test('CJK characters in insert', () {
      final b = Buffer.fromText('');
      b.insertRune('日');
      b.insertRune('本');
      b.insertRune('語');
      expect(b.text, '日本語');
      expect(b.cursor.col, 3);
    });
  });

  group('Very long content', () {
    test('title with 10k chars survives yy', () {
      final s = AppState()..splashDismissed = true;
      final huge = 'x' * 10000;
      final now = DateTime.now().toUtc();
      s.notes = [
        Note(
          id: 'x',
          userId: 'u',
          title: huge,
          body: '',
          tags: const [],
          createdAt: now,
          updatedAt: now,
        ),
      ];
      dispatch(s, rune('y'));
      dispatch(s, rune('y'));
      expect(s.register.length, 10000);
    });

    test('body with 100k chars: motion stays fast', () {
      final b = Buffer.fromText('X' * 100000);
      final sw = Stopwatch()..start();
      b.moveEnd();
      b.moveHome();
      b.wordForward();
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(200));
    });
  });

  group('Rapid mode switching', () {
    test('spam Esc from every mode returns to normal', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune('v'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune('V'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune(':'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune('/'));
      dispatch(s, const Key('esc'));
      expect(s.mode, Mode.normal);
    });

    test('open detail, discard with :q!, reopen shows clean buffer', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, rune('X'));
      dispatch(s, const Key('esc'));
      // Discard with :q!
      dispatch(s, rune(':'));
      dispatch(s, rune('q'));
      dispatch(s, rune('!'));
      dispatch(s, const Key('enter'));
      expect(s.focus, Focus.list);
      // Reopen
      dispatch(s, const Key('enter'));
      expect(s.bodyBuf.text, isNot(contains('X')));
    });
  });

  group('Pending prefix interactions', () {
    test('g followed by non-g cancels pending', () {
      final s = _state();
      dispatch(s, rune('g'));
      dispatch(s, rune('j')); // not 'g'
      // pending should clear, j moves down
      expect(s.pendingG, isFalse);
    });

    test('y followed by non-y cancels', () {
      final s = _state();
      dispatch(s, rune('y'));
      dispatch(s, rune('j'));
      expect(s.pendingY, isFalse);
      expect(s.register, isEmpty);
    });

    test('leader followed by unknown key cancels leader', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('Z')); // unknown leader binding
      expect(s.pendingLeader, isFalse);
    });

    test('leader + b then non-b/d/n cancels', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('b'));
      dispatch(s, rune('X'));
      expect(s.pendingLeaderB, isFalse);
    });
  });

  group('Undo/redo edge cases', () {
    test('redo cleared after new edit', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, rune('A'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune('u'));
      expect(s.bodyBuf.redoStack.length, greaterThan(0));
      // Now make a new edit; redo stack should clear
      dispatch(s, rune('i'));
      dispatch(s, rune('B'));
      expect(s.bodyBuf.redoStack, isEmpty);
    });

    test('undo history caps at 200', () {
      final b = Buffer.fromText('');
      for (int i = 0; i < 250; i++) {
        b.snapshot();
        b.insertRune('x');
      }
      expect(b.undoStack.length, lessThanOrEqualTo(200));
    });

    test('undo below zero: no crash, returns false', () {
      final b = Buffer.fromText('hello');
      expect(b.undo(), isFalse);
      expect(b.text, 'hello');
    });

    test('redo without undo: no crash', () {
      final b = Buffer.fromText('hello');
      expect(b.redo(), isFalse);
    });
  });

  group('Search edge cases', () {
    test('search with no matches returns empty', () {
      final s = _state();
      dispatch(s, rune('/'));
      for (final c in 'zzzzzzz'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.filtered(), isEmpty);
    });

    test('search then clear via Esc restores full list', () {
      final s = _state();
      dispatch(s, rune('/'));
      for (final c in 'zzz'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.filtered(), isEmpty);
      dispatch(s, const Key('esc'));
      expect(s.filtered().length, s.notes.length);
    });

    test('fuzzy: subsequence match works', () {
      final s = _state(count: 5);
      s.notes[3].title = 'Refactor code';
      dispatch(s, rune('/'));
      for (final c in 'rfc'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.filtered().any((n) => n.title == 'Refactor code'), isTrue);
    });

    test('search backspace works', () {
      final s = _state();
      dispatch(s, rune('/'));
      dispatch(s, rune('a'));
      dispatch(s, rune('b'));
      dispatch(s, const Key('backspace'));
      expect(s.searchInput, 'a');
    });

    test('search does not persist across Esc-cancel', () {
      final s = _state();
      dispatch(s, rune('/'));
      dispatch(s, rune('x'));
      dispatch(s, const Key('esc'));
      expect(s.search, isEmpty);
    });
  });

  group('Buffer edge cases', () {
    test('single-line buffer: j/k stays at row 0', () {
      final b = Buffer.fromText('only line');
      b.moveDown();
      expect(b.cursor.row, 0);
      b.moveUp();
      expect(b.cursor.row, 0);
    });

    test('deleteLine on last row does not underflow', () {
      final b = Buffer.fromText('a\nb\nc');
      b.moveBottom();
      b.deleteLine();
      expect(b.text, 'a\nb');
      b.deleteLine();
      expect(b.text, 'a');
      b.deleteLine();
      expect(b.text, '');
    });

    test('word motion on empty line', () {
      final b = Buffer.fromText('\n\nword');
      b.wordForward();
      expect(b.cursor.row, greaterThanOrEqualTo(0));
    });

    test('insertNewline at end of last line', () {
      final b = Buffer.fromText('hello');
      b.moveEnd();
      b.insertNewline();
      expect(b.text, 'hello\n');
      expect(b.cursor.row, 1);
      expect(b.cursor.col, 0);
    });

    test('backspace across many joins', () {
      final b = Buffer.fromText('a\nb\nc');
      b.moveBottom();
      b.moveHome();
      b.backspace(); // c → bc
      b.backspace(); // b → abc? no: cursor at start of new-line-c row
      expect(b.text.contains('c'), isTrue);
    });

    test('very deep indent nesting', () {
      final deep = '    ' * 50 + 'x';
      final b = Buffer.fromText(deep);
      b.moveEnd();
      expect(b.cursor.col, deep.length);
    });
  });

  group('Visual mode edge cases', () {
    test('visual then Esc clears anchor', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('i'));
      dispatch(s, rune('a'));
      dispatch(s, rune('b'));
      dispatch(s, rune('c'));
      dispatch(s, const Key('esc'));
      dispatch(s, rune('v'));
      dispatch(s, rune('l'));
      dispatch(s, const Key('esc'));
      expect(s.bodyBuf.anchor, isNull);
      expect(s.mode, Mode.normal);
    });

    test('visual yank of empty selection returns line', () {
      final b = Buffer.fromText('hello');
      b.startVisual(Mode.visual);
      final r = b.yankSelection();
      expect(r.contains('h'), isTrue);
    });

    test('visual across multiple lines yanks correctly', () {
      final b = Buffer.fromText('one\ntwo\nthree');
      b.startVisual(Mode.visualLine);
      b.moveDown();
      expect(b.yankSelection(), 'one\ntwo');
    });
  });

  group('Confirm-quit interactions', () {
    test('confirm-quit + j does not treat as motion', () {
      final s = _state();
      dispatch(s, rune('q')); // enter confirm mode
      final before = s.listCursor;
      dispatch(s, rune('j')); // should cancel, NOT move
      expect(s.listCursor, before);
      expect(s.mode, Mode.normal);
    });

    test('confirm-quit inside detail: q closes detail (dirty=false)', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('q'));
      expect(s.focus, Focus.list);
    });
  });

  group('Tree pane interactions', () {
    test('tree with only untagged notes: work tag absent', () {
      final s = _state(count: 2, tags: []);
      final items = s.treeItems();
      expect(items.any((e) => e.key == 'work'), isFalse);
    });

    test('tree filter applies then clearing filter shows all', () {
      final s = _state();
      s.treeFilter = 'work';
      expect(s.filtered().length, 1);
      s.treeFilter = null;
      expect(s.filtered().length, 3);
    });

    test('tree cursor cannot exceed items', () {
      final s = _state();
      s.treeOpen = true;
      s.focus = Focus.tree;
      final items = s.treeItems();
      // Spam j
      for (int i = 0; i < 100; i++) {
        dispatch(s, rune('j'));
      }
      expect(s.treeCursor, lessThan(items.length));
    });
  });

  group('Chat edge cases', () {
    test('empty message ignored on Enter', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      final r = dispatch(s, const Key('enter'));
      expect(r.chatSend, isFalse);
    });

    test('long message accumulates', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      for (int i = 0; i < 300; i++) {
        dispatch(s, rune('x'));
      }
      expect(s.chatInput.length, 300);
    });

    test('backspace at start does not go negative', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      dispatch(s, const Key('backspace'));
      dispatch(s, const Key('backspace'));
      dispatch(s, const Key('backspace'));
      expect(s.chatCursor, 0);
    });
  });

  group('Fuzzy scoring', () {
    test('exact substring beats subsequence', () {
      // Direct call via filtered() proxy
      final substr = AppState.fuzzyScore('hello', 'say hello world');
      final subseq = AppState.fuzzyScore('hello', 'hxexlxlxo');
      expect(substr, greaterThan(subseq));
    });

    test('earlier substring beats later substring', () {
      final early = AppState.fuzzyScore('foo', 'foo bar');
      final late = AppState.fuzzyScore('foo', 'bar bar foo');
      expect(early, greaterThan(late));
    });

    test('no match returns 0', () {
      expect(AppState.fuzzyScore('xyz', 'hello'), 0);
    });
  });
}
