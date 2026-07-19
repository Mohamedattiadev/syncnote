// Vim motion engine — text buffer with cursor, selection, undo.
// Matches user's nvim keymap: leader=<Space>, H/L cycle, <tab>hjkl 5x,
// yy dd cw ciw dw d$ c$ 0 $ w b e gg G I A o O v V y d c x u p P.

import 'model.dart';

class Pos {
  int row;
  int col;
  Pos(this.row, this.col);
  Pos.zero()
      : row = 0,
        col = 0;
  Pos copy() => Pos(row, col);

  bool operator <(Pos o) => row < o.row || (row == o.row && col < o.col);
  bool operator <=(Pos o) => this < o || (row == o.row && col == o.col);
  @override
  bool operator ==(Object o) => o is Pos && o.row == row && o.col == col;
  @override
  int get hashCode => row * 100000 + col;
}

/// Vim-style text buffer for a single field (title or body).
/// Snapshot for undo history — immutable.
class BufferSnapshot {
  final List<String> lines;
  final Pos cursor;
  const BufferSnapshot(this.lines, this.cursor);
}

class Buffer {
  List<String> lines;
  Pos cursor = Pos.zero();
  Pos? anchor; // start of visual selection
  Mode selMode = Mode.normal;

  /// Undo/redo stacks — cap history to avoid memory blowup.
  final List<BufferSnapshot> undoStack = [];
  final List<BufferSnapshot> redoStack = [];

  /// Named marks: 'a'..'z' → line number.
  final Map<String, int> marks = {};
  static const int _maxHistory = 200;

  void snapshot() {
    undoStack.add(BufferSnapshot(List.of(lines), Pos(cursor.row, cursor.col)));
    if (undoStack.length > _maxHistory) undoStack.removeAt(0);
    redoStack.clear();
  }

  bool undo() {
    if (undoStack.isEmpty) return false;
    redoStack.add(BufferSnapshot(List.of(lines), Pos(cursor.row, cursor.col)));
    final s = undoStack.removeLast();
    lines = List.of(s.lines);
    cursor = Pos(s.cursor.row, s.cursor.col);
    return true;
  }

  bool redo() {
    if (redoStack.isEmpty) return false;
    undoStack.add(BufferSnapshot(List.of(lines), Pos(cursor.row, cursor.col)));
    final s = redoStack.removeLast();
    lines = List.of(s.lines);
    cursor = Pos(s.cursor.row, s.cursor.col);
    return true;
  }

  Buffer(this.lines) {
    if (lines.isEmpty) lines = [''];
  }

  Buffer.fromText(String s) : lines = s.isEmpty ? [''] : s.split('\n');

  String get text => lines.join('\n');

  int get lineCount => lines.length;

  String currentLine() => lines[cursor.row.clamp(0, lines.length - 1)];

  void clamp() {
    if (lines.isEmpty) lines = [''];
    if (cursor.row < 0) cursor.row = 0;
    if (cursor.row >= lines.length) cursor.row = lines.length - 1;
    final ln = lines[cursor.row].length;
    if (cursor.col < 0) cursor.col = 0;
    if (cursor.col > ln) cursor.col = ln;
  }

  // Motion primitives.
  void moveLeft([int n = 1]) { cursor.col -= n; clamp(); }
  void moveRight([int n = 1]) { cursor.col += n; clamp(); }
  void moveUp([int n = 1]) { cursor.row -= n; clamp(); }
  void moveDown([int n = 1]) { cursor.row += n; clamp(); }
  void moveHome() { cursor.col = 0; }
  void moveEnd() { cursor.col = lines[cursor.row].length; }
  void moveTop() { cursor.row = 0; clamp(); }
  void moveBottom() { cursor.row = lines.length - 1; clamp(); }

  void wordForward() {
    final line = lines[cursor.row];
    int i = cursor.col;
    while (i < line.length && _isWord(line.codeUnitAt(i))) i++;
    while (i < line.length && !_isWord(line.codeUnitAt(i))) i++;
    if (i >= line.length) {
      if (cursor.row < lines.length - 1) {
        cursor.row++;
        cursor.col = 0;
      } else {
        cursor.col = line.length;
      }
      return;
    }
    cursor.col = i;
  }

  void wordBack() {
    if (cursor.col == 0 && cursor.row > 0) {
      cursor.row--;
      cursor.col = lines[cursor.row].length;
      return;
    }
    final line = lines[cursor.row];
    int i = cursor.col - 1;
    while (i > 0 && !_isWord(line.codeUnitAt(i))) i--;
    while (i > 0 && _isWord(line.codeUnitAt(i - 1))) i--;
    if (i < 0) i = 0;
    cursor.col = i;
  }

  void wordEnd() {
    final line = lines[cursor.row];
    int i = cursor.col;
    if (i < line.length && !_isWord(line.codeUnitAt(i))) i++;
    while (i < line.length && !_isWord(line.codeUnitAt(i))) i++;
    while (i < line.length - 1 && _isWord(line.codeUnitAt(i + 1))) i++;
    if (i >= line.length && cursor.row < lines.length - 1) {
      cursor.row++;
      cursor.col = 0;
      wordEnd();
      return;
    }
    cursor.col = i;
  }

  static bool _isWord(int cu) =>
      (cu >= 0x30 && cu <= 0x39) ||
      (cu >= 0x41 && cu <= 0x5a) ||
      (cu >= 0x61 && cu <= 0x7a) ||
      cu == 0x5f;

  // Visual selection.
  void startVisual(Mode m) {
    anchor = cursor.copy();
    selMode = m;
  }

  void clearVisual() {
    anchor = null;
    selMode = Mode.normal;
  }

  bool inSelection(int row, int col) {
    if (anchor == null) return false;
    final a = anchor!;
    final c = cursor;
    final lo = a < c ? a : c;
    final hi = a < c ? c : a;
    if (selMode == Mode.visualLine) {
      return row >= lo.row && row <= hi.row;
    }
    if (row < lo.row || row > hi.row) return false;
    if (row == lo.row && row == hi.row) return col >= lo.col && col <= hi.col;
    if (row == lo.row) return col >= lo.col;
    if (row == hi.row) return col <= hi.col;
    return true;
  }

  String yankSelection() {
    if (anchor == null) return currentLine();
    final a = anchor!;
    final c = cursor;
    final lo = a < c ? a : c;
    final hi = a < c ? c : a;
    if (selMode == Mode.visualLine) {
      return lines.sublist(lo.row, hi.row + 1).join('\n');
    }
    if (lo.row == hi.row) {
      return lines[lo.row].substring(lo.col, (hi.col + 1).clamp(0, lines[lo.row].length));
    }
    final buf = StringBuffer();
    buf.write(lines[lo.row].substring(lo.col));
    buf.write('\n');
    for (int i = lo.row + 1; i < hi.row; i++) {
      buf.write(lines[i]);
      buf.write('\n');
    }
    buf.write(lines[hi.row].substring(0, (hi.col + 1).clamp(0, lines[hi.row].length)));
    return buf.toString();
  }

  // Edit ops.
  void insertRune(String r) {
    final line = lines[cursor.row];
    lines[cursor.row] =
        line.substring(0, cursor.col) + r + line.substring(cursor.col);
    cursor.col += r.length;
  }

  void insertNewline() {
    final line = lines[cursor.row];
    final left = line.substring(0, cursor.col);
    final right = line.substring(cursor.col);
    lines[cursor.row] = left;
    lines.insert(cursor.row + 1, right);
    cursor.row++;
    cursor.col = 0;
  }

  void backspace() {
    if (cursor.col > 0) {
      final line = lines[cursor.row];
      lines[cursor.row] =
          line.substring(0, cursor.col - 1) + line.substring(cursor.col);
      cursor.col--;
    } else if (cursor.row > 0) {
      final prev = lines[cursor.row - 1];
      final cur = lines[cursor.row];
      cursor.col = prev.length;
      lines[cursor.row - 1] = prev + cur;
      lines.removeAt(cursor.row);
      cursor.row--;
    }
  }

  void deleteCharAtCursor() {
    final line = lines[cursor.row];
    if (cursor.col >= line.length) return;
    lines[cursor.row] =
        line.substring(0, cursor.col) + line.substring(cursor.col + 1);
  }

  String deleteLine() {
    if (lines.length == 1) {
      final r = lines[0];
      lines[0] = '';
      cursor.col = 0;
      return '$r\n';
    }
    final r = lines[cursor.row];
    lines.removeAt(cursor.row);
    if (cursor.row >= lines.length) cursor.row = lines.length - 1;
    cursor.col = 0;
    return '$r\n';
  }

  String deleteSelection() {
    if (anchor == null) return '';
    final a = anchor!;
    final c = cursor;
    final lo = a < c ? a : c;
    final hi = a < c ? c : a;
    if (selMode == Mode.visualLine) {
      final r = lines.sublist(lo.row, hi.row + 1).join('\n');
      lines.removeRange(lo.row, hi.row + 1);
      if (lines.isEmpty) lines = [''];
      cursor.row = lo.row.clamp(0, lines.length - 1);
      cursor.col = 0;
      clearVisual();
      return '$r\n';
    }
    if (lo.row == hi.row) {
      final line = lines[lo.row];
      final r = line.substring(lo.col, (hi.col + 1).clamp(0, line.length));
      lines[lo.row] =
          line.substring(0, lo.col) + line.substring((hi.col + 1).clamp(0, line.length));
      cursor = lo.copy();
      clearVisual();
      return r;
    }
    final head = lines[lo.row].substring(0, lo.col);
    final tail = lines[hi.row].substring((hi.col + 1).clamp(0, lines[hi.row].length));
    final buf = StringBuffer();
    buf.write(lines[lo.row].substring(lo.col));
    buf.write('\n');
    for (int i = lo.row + 1; i < hi.row; i++) {
      buf.write(lines[i]);
      buf.write('\n');
    }
    buf.write(lines[hi.row].substring(0, (hi.col + 1).clamp(0, lines[hi.row].length)));
    lines[lo.row] = head + tail;
    lines.removeRange(lo.row + 1, hi.row + 1);
    cursor = lo.copy();
    clearVisual();
    return buf.toString();
  }

  void paste(String s, {bool linewise = false}) {
    if (linewise || s.endsWith('\n')) {
      final content = s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
      final newLines = content.split('\n');
      lines.insertAll(cursor.row + 1, newLines);
      cursor.row++;
      cursor.col = 0;
    } else {
      final parts = s.split('\n');
      if (parts.length == 1) {
        insertRune(s);
      } else {
        final line = lines[cursor.row];
        final left = line.substring(0, cursor.col);
        final right = line.substring(cursor.col);
        lines[cursor.row] = left + parts.first;
        for (int i = 1; i < parts.length - 1; i++) {
          lines.insert(cursor.row + i, parts[i]);
        }
        lines.insert(cursor.row + parts.length - 1, parts.last + right);
        cursor.row += parts.length - 1;
        cursor.col = parts.last.length;
      }
    }
  }

  void openLineBelow() {
    lines.insert(cursor.row + 1, '');
    cursor.row++;
    cursor.col = 0;
  }

  void openLineAbove() {
    lines.insert(cursor.row, '');
    cursor.col = 0;
  }
}
