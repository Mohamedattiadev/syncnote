import 'package:test/test.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/vim.dart';

void main() {
  group('Buffer motion', () {
    test('hjkl clamps to bounds', () {
      final b = Buffer.fromText('hello\nworld');
      b.moveDown();
      expect(b.cursor.row, 1);
      b.moveDown();
      expect(b.cursor.row, 1); // clamped
      b.moveRight(10);
      expect(b.cursor.col, 5);
      b.moveLeft(100);
      expect(b.cursor.col, 0);
    });

    test('word forward w and back b', () {
      final b = Buffer.fromText('the quick brown fox');
      b.wordForward();
      expect(b.cursor.col, 4);
      b.wordForward();
      expect(b.cursor.col, 10);
      b.wordBack();
      expect(b.cursor.col, 4);
    });

    test('gg/G equivalents', () {
      final b = Buffer.fromText('a\nb\nc\nd');
      b.moveBottom();
      expect(b.cursor.row, 3);
      b.moveTop();
      expect(b.cursor.row, 0);
    });

    test('0 and \$ (home/end)', () {
      final b = Buffer.fromText('hello world');
      b.moveEnd();
      expect(b.cursor.col, 11);
      b.moveHome();
      expect(b.cursor.col, 0);
    });
  });

  group('Buffer edit', () {
    test('insertRune at cursor', () {
      final b = Buffer.fromText('hlo');
      b.cursor.col = 1;
      b.insertRune('e');
      expect(b.text, 'helo');
      expect(b.cursor.col, 2);
    });

    test('insertNewline splits line', () {
      final b = Buffer.fromText('hello world');
      b.cursor.col = 5;
      b.insertNewline();
      expect(b.lines, ['hello', ' world']);
      expect(b.cursor.row, 1);
      expect(b.cursor.col, 0);
    });

    test('backspace deletes char', () {
      final b = Buffer.fromText('abc');
      b.cursor.col = 3;
      b.backspace();
      expect(b.text, 'ab');
    });

    test('backspace at col 0 joins lines', () {
      final b = Buffer.fromText('one\ntwo');
      b.cursor.row = 1;
      b.cursor.col = 0;
      b.backspace();
      expect(b.text, 'onetwo');
      expect(b.cursor.row, 0);
      expect(b.cursor.col, 3);
    });

    test('deleteLine returns line + trims', () {
      final b = Buffer.fromText('a\nb\nc');
      b.cursor.row = 1;
      final r = b.deleteLine();
      expect(r, 'b\n');
      expect(b.text, 'a\nc');
    });

    test('openLineBelow o and openLineAbove O', () {
      final b = Buffer.fromText('a\nb');
      b.openLineBelow();
      expect(b.text, 'a\n\nb');
      expect(b.cursor.row, 1);
      final c = Buffer.fromText('x\ny');
      c.cursor.row = 1;
      c.openLineAbove();
      expect(c.text, 'x\n\ny');
    });
  });

  group('Visual selection', () {
    test('char-selection yank returns exact range', () {
      final b = Buffer.fromText('hello world');
      b.cursor.col = 0;
      b.startVisual(Mode.visual);
      b.cursor.col = 4;
      expect(b.yankSelection(), 'hello');
    });

    test('line-selection yank returns whole lines', () {
      final b = Buffer.fromText('a\nb\nc\nd');
      b.cursor.row = 1;
      b.startVisual(Mode.visualLine);
      b.cursor.row = 2;
      expect(b.yankSelection(), 'b\nc');
    });

    test('delete char-selection removes range and clears anchor', () {
      final b = Buffer.fromText('foobar');
      b.cursor.col = 1;
      b.startVisual(Mode.visual);
      b.cursor.col = 3;
      final r = b.deleteSelection();
      expect(r, 'oob');
      expect(b.text, 'far');
      expect(b.anchor, isNull);
    });

    test('delete line-selection removes rows', () {
      final b = Buffer.fromText('a\nb\nc\nd');
      b.cursor.row = 1;
      b.startVisual(Mode.visualLine);
      b.cursor.row = 2;
      b.deleteSelection();
      expect(b.text, 'a\nd');
    });
  });

  group('Paste (register)', () {
    test('linewise paste inserts after cursor line', () {
      final b = Buffer.fromText('a\nb');
      b.cursor.row = 0;
      b.paste('X\n', linewise: true);
      expect(b.text, 'a\nX\nb');
    });

    test('charwise paste inserts at cursor', () {
      final b = Buffer.fromText('hlo');
      b.cursor.col = 1;
      b.paste('el');
      expect(b.text, 'hello');
    });
  });

  group('Pos ordering', () {
    test('Pos < works row-major', () {
      expect(Pos(0, 5) < Pos(1, 0), isTrue);
      expect(Pos(1, 3) < Pos(1, 4), isTrue);
      expect(Pos(1, 4) < Pos(1, 3), isFalse);
    });
  });
}
