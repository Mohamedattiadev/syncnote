// Key dispatcher — maps Key events to state mutations. Pure functions where possible.

import 'dart:convert';
import 'dart:io';

import 'ai.dart';
import 'keys.dart';
import 'model.dart';
import 'render.dart' show cmdCompletions;
import 'state.dart';

/// Public entry: applies a key event to state. Returns true if async data
/// operation was requested (caller must reload from Supabase after).
class DispatchResult {
  final bool needsReload;
  final bool save;
  final bool create;
  final bool delete;
  final bool quit;
  final bool chatSend;
  const DispatchResult({
    this.needsReload = false,
    this.save = false,
    this.create = false,
    this.delete = false,
    this.quit = false,
    this.chatSend = false,
  });
  static const none = DispatchResult();
}

DispatchResult dispatch(AppState s, Key k) {
  s.toast = '';

  // Splash dismisses on any key.
  if (s.shouldShowSplash) {
    s.splashDismissed = true;
    return DispatchResult.none;
  }

  // Help overlay eats input until dismissed.
  if (s.showHelp) {
    if (k.name == 'esc' || (k.isRune && (k.rune == 'q' || k.rune == '?'))) {
      s.showHelp = false;
    }
    return DispatchResult.none;
  }

  if (s.mode == Mode.confirmQuit) {
    if (k.isRune && (k.rune == 'y' || k.rune == 'Y')) {
      return const DispatchResult(quit: true);
    }
    s.mode = Mode.normal;
    return DispatchResult.none;
  }

  // Chat pane has its own input model.
  if (s.focus == Focus.chat) return _chatMode(s, k);
  if (s.focus == Focus.tree) return _treeMode(s, k);

  switch (s.mode) {
    case Mode.cmd:
      return _cmdMode(s, k);
    case Mode.search:
      return _searchMode(s, k);
    case Mode.insert:
      return _insertMode(s, k);
    case Mode.visual:
    case Mode.visualLine:
      return _visualMode(s, k);
    case Mode.normal:
    case Mode.confirmQuit:
      return _normalMode(s, k);
  }
}

// ---------------- NORMAL ----------------

int _consumeCount(AppState s, {int fallback = 1}) {
  if (s.pendingCount.isEmpty) return fallback;
  final n = int.tryParse(s.pendingCount) ?? fallback;
  s.pendingCount = '';
  return n < 1 ? 1 : n;
}

void _clearCount(AppState s) {
  s.pendingCount = '';
}

/// Char search on current line in detail buffer. op ∈ {f,F,t,T}.
void _charSearchApply(AppState s, String op, String ch) {
  if (s.focus != Focus.detail) return;
  final b = s.activeBuf;
  final line = b.currentLine();
  final col = b.cursor.col;
  int target = -1;
  if (op == 'f' || op == 't') {
    for (int i = col + 1; i < line.length; i++) {
      if (line[i] == ch) { target = i; break; }
    }
    if (target < 0) { s.toast = 'not found'; return; }
    if (op == 't') target -= 1;
    b.cursor.col = target;
  } else {
    for (int i = col - 1; i >= 0; i--) {
      if (line[i] == ch) { target = i; break; }
    }
    if (target < 0) { s.toast = 'not found'; return; }
    if (op == 'T') target += 1;
    b.cursor.col = target;
  }
}

DispatchResult _normalMode(AppState s, Key k) {
  // Register selector: `"{a-z}` sets activeRegister for next op
  if (s.pendingRegister) {
    s.pendingRegister = false;
    if (k.isRune) {
      final r = k.rune!;
      if (r.length == 1 && r.codeUnitAt(0) >= 0x61 && r.codeUnitAt(0) <= 0x7a) {
        s.activeRegister = r;
        s.toast = 'reg "$r';
      }
    }
    return DispatchResult.none;
  }
  // Char-search pending: capture the next char.
  if (s.pendingCharSearch != null) {
    final op = s.pendingCharSearch!;
    s.pendingCharSearch = null;
    if (k.isRune) {
      _charSearchApply(s, op, k.rune!);
      s.lastCharSearchOp = op;
      s.lastCharSearchCh = k.rune;
    }
    return DispatchResult.none;
  }
  // Mark set: m{a-z}
  if (s.pendingM) {
    s.pendingM = false;
    if (k.isRune && s.focus == Focus.detail) {
      final r = k.rune!;
      if (r.length == 1 && r.codeUnitAt(0) >= 0x61 && r.codeUnitAt(0) <= 0x7a) {
        s.activeBuf.marks[r] = s.activeBuf.cursor.row;
        s.toast = "mark '$r set";
      }
    }
    return DispatchResult.none;
  }
  if (s.pendingQuote) {
    s.pendingQuote = false;
    if (k.isRune && s.focus == Focus.detail) {
      final r = k.rune!;
      final row = s.activeBuf.marks[r];
      if (row != null) {
        s.activeBuf.cursor.row = row.clamp(0, s.activeBuf.lines.length - 1);
        s.activeBuf.cursor.col = 0;
      } else {
        s.toast = "mark '$r not set";
      }
    }
    return DispatchResult.none;
  }
  // g Ctrl-g word/char count
  if (s.pendingCtrlG) {
    s.pendingCtrlG = false;
    if (k.name == 'ctrl+g') {
      final b = s.activeBuf;
      final total = b.lines.length;
      final line = b.cursor.row + 1;
      final totalChars = b.text.length;
      final beforeChars = b.lines.sublist(0, b.cursor.row).fold<int>(0, (a, l) => a + l.length + 1) + b.cursor.col;
      final totalWords = _countWords(b.text);
      final wordsBefore = _countWords(b.text.substring(0, beforeChars.clamp(0, b.text.length)));
      s.toast = 'Line $line of $total · Word $wordsBefore of $totalWords · Char $beforeChars of $totalChars';
      return DispatchResult.none;
    }
    // fall through — treat as fresh key after failed g-chord
  }
  // Leader chords first.
  if (s.pendingLeader) {
    s.pendingLeader = false;
    return _leader(s, k);
  }
  if (s.pendingLeaderB) {
    s.pendingLeaderB = false;
    return _leaderBuffer(s, k);
  }
  if (s.pendingLeaderF) {
    s.pendingLeaderF = false;
    return _leaderFind(s, k);
  }
  // <tab>hjkl = 5x motion (user's nvim config).
  if (s.pendingTab) {
    s.pendingTab = false;
    if (k.isRune) {
      switch (k.rune) {
        case 'h': _move(s, dx: -5); break;
        case 'l': _move(s, dx: 5); break;
        case 'j': _move(s, dy: 5); break;
        case 'k': _move(s, dy: -5); break;
      }
    }
    return DispatchResult.none;
  }
  // gg
  if (s.pendingG) {
    s.pendingG = false;
    if (k.isRune && k.rune == 'g') {
      _clearCount(s);
      if (s.focus == Focus.list) {
        s.listCursor = 0;
      } else {
        s.activeBuf.moveTop();
      }
    } else if (k.isRune && k.rune == 'x') {
      // gx — open URL under cursor
      _openUrlUnderCursor(s);
    }
    return DispatchResult.none;
  }
  // yy dd cc  — with optional count and dw
  if (s.pendingY) {
    s.pendingY = false;
    if (k.isRune && k.rune == 'y') {
      final n = _consumeCount(s);
      if (s.focus == Focus.list) {
        final note = s.currentUnderList();
        if (note != null) {
          s.register = note.title;
          s.toast = '⟡ yanked title';
        }
      } else {
        final b = s.activeBuf;
        if (n == 1) {
          s.register = b.currentLine();
        } else {
          final start = b.cursor.row;
          final end = (start + n).clamp(0, b.lines.length);
          s.register = b.lines.sublist(start, end).join('\n');
        }
        s.registerLinewise = true;
        final start = b.cursor.row;
        final lastRow = (start + n - 1).clamp(start, b.lines.length - 1);
        final lastLen = b.lines[lastRow].length;
        s.flashYank(start, 0, lastRow, lastLen);
        _stashNamed(s, linewise: true);
        s.toast = n > 1 ? '⟡ yanked $n lines' : '⟡ yanked line';
        s.lastChangeKind = 'yy';
        s.lastChangeCount = n;
      }
    }
    return DispatchResult.none;
  }
  if (s.pendingD) {
    s.pendingD = false;
    if (k.isRune && k.rune == 'd') {
      final n = _consumeCount(s);
      if (s.focus == Focus.list) {
        return const DispatchResult(delete: true);
      }
      s.activeBuf.snapshot();
      final buf = StringBuffer();
      for (int i = 0; i < n; i++) {
        buf.write(s.activeBuf.deleteLine());
      }
      s.register = buf.toString();
      s.registerLinewise = true;
      _stashNamed(s, linewise: true);
      s.dirty = true;
      s.toast = n > 1 ? 'deleted $n lines' : 'deleted line';
      s.lastChangeKind = 'dd';
      s.lastChangeCount = n;
    } else if (k.isRune && k.rune == 'w' && s.focus == Focus.detail) {
      // dw — delete from cursor to next word start (single line)
      final n = _consumeCount(s);
      s.activeBuf.snapshot();
      for (int i = 0; i < n; i++) {
        _deleteWord(s.activeBuf);
      }
      s.dirty = true;
      s.lastChangeKind = 'dw';
      s.lastChangeCount = n;
    }
    return DispatchResult.none;
  }
  if (s.pendingC) {
    s.pendingC = false;
    if (k.isRune && k.rune == 'c') {
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.register = s.activeBuf.deleteLine();
        s.registerLinewise = true;
        s.mode = Mode.insert;
      }
    }
    return DispatchResult.none;
  }

  // Simple keys.
  if (k.name == 'esc') {
    if (s.search.isNotEmpty) {
      s.search = '';
      s.listCursor = 0;
    }
    return DispatchResult.none;
  }
  if (k.name == 'tab' && s.focus == Focus.detail) {
    s.fieldIdx = (s.fieldIdx + 1) % 3;
    return DispatchResult.none;
  }
  if (k.name == 'shift+tab' && s.focus == Focus.detail) {
    s.fieldIdx = (s.fieldIdx + 2) % 3;
    return DispatchResult.none;
  }
  if (k.name == 'tab' && s.focus == Focus.list) {
    s.pendingTab = true;
    return DispatchResult.none;
  }
  if (k.name == 'enter') {
    if (s.focus == Focus.list) {
      final n = s.currentUnderList();
      if (n != null) s.openNoteForEdit(n);
    }
    return DispatchResult.none;
  }

  if (k.name == 'ctrl+r') {
    if (s.focus == Focus.detail) {
      if (s.activeBuf.redo()) {
        s.dirty = true;
        s.toast = '↷ redo';
      } else {
        s.toast = 'nothing to redo';
      }
    }
    return DispatchResult.none;
  }
  if (k.name == 'ctrl+g' && s.pendingCtrlG) {
    // already handled above
  }
  if (!k.isRune) return DispatchResult.none;
  final r = k.rune;

  // Count-prefix accumulation. '0' is only a count digit if we already have digits
  // (otherwise it's move-to-line-start).
  if (r != null && r.length == 1) {
    final cu = r.codeUnitAt(0);
    final isDigit = cu >= 0x30 && cu <= 0x39;
    if (isDigit && (r != '0' || s.pendingCount.isNotEmpty)) {
      // cap length to 6 to avoid nonsense
      if (s.pendingCount.length < 6) s.pendingCount += r;
      return DispatchResult.none;
    }
  }

  switch (r) {
    case ' ':
      _clearCount(s);
      s.pendingLeader = true;
      break;
    case ':':
      _clearCount(s);
      s.mode = Mode.cmd;
      s.cmdInput = '';
      s.cmdCursor = 0;
      break;
    case '/':
      _clearCount(s);
      s.mode = Mode.search;
      s.searchInput = s.search;
      s.searchCursor = s.searchInput.length;
      break;
    case 'q':
      _clearCount(s);
      if (s.focus == Focus.detail) {
        if (s.dirty) return const DispatchResult(save: true);
        s.closeDetail();
      } else {
        s.mode = Mode.confirmQuit;
      }
      break;
    case 'j':
      _move(s, dy: _consumeCount(s));
      break;
    case 'k':
      _move(s, dy: -_consumeCount(s));
      break;
    case 'h':
      if ((s.focus == Focus.list || s.focus == Focus.detail) && s.treeOpen && s.pendingCount.isEmpty) {
        s.lastMainFocus = s.focus;
        s.focus = Focus.tree;
      } else {
        _move(s, dx: -_consumeCount(s));
      }
      break;
    case 'l':
      if (s.focus == Focus.tree) {
        s.focus = s.lastMainFocus;
      } else {
        _move(s, dx: _consumeCount(s));
      }
      break;
    case 'g':
      s.pendingG = true;
      s.pendingCtrlG = true;
      break;
    case 'G':
      if (s.pendingCount.isNotEmpty) {
        final n = _consumeCount(s);
        if (s.focus == Focus.detail) {
          s.activeBuf.cursor.row = (n - 1).clamp(0, s.activeBuf.lines.length - 1);
          s.activeBuf.cursor.col = 0;
        } else if (s.focus == Focus.list) {
          s.listCursor = (n - 1).clamp(0, s.filtered().length - 1);
        }
      } else if (s.focus == Focus.list) {
        s.listCursor = s.filtered().length - 1;
      } else {
        s.activeBuf.moveBottom();
      }
      break;
    case '0':
      if (s.focus == Focus.detail) s.activeBuf.moveHome();
      break;
    case '\$':
      if (s.focus == Focus.detail) s.activeBuf.moveEnd();
      break;
    case 'w':
      if (s.focus == Focus.detail) {
        final n = _consumeCount(s);
        for (int i = 0; i < n; i++) s.activeBuf.wordForward();
      }
      break;
    case 'b':
      if (s.focus == Focus.detail) {
        final n = _consumeCount(s);
        for (int i = 0; i < n; i++) s.activeBuf.wordBack();
      }
      break;
    case 'e':
      if (s.focus == Focus.detail) {
        final n = _consumeCount(s);
        for (int i = 0; i < n; i++) s.activeBuf.wordEnd();
      }
      break;
    case 'f':
    case 'F':
    case 't':
    case 'T':
      if (s.focus == Focus.detail) {
        s.pendingCharSearch = r;
      }
      break;
    case ';':
      if (s.focus == Focus.detail && s.lastCharSearchOp != null) {
        _charSearchApply(s, s.lastCharSearchOp!, s.lastCharSearchCh!);
      }
      break;
    case ',':
      if (s.focus == Focus.detail && s.lastCharSearchOp != null) {
        final op = s.lastCharSearchOp!;
        final rev = op == 'f' ? 'F' : op == 'F' ? 'f' : op == 't' ? 'T' : 't';
        _charSearchApply(s, rev, s.lastCharSearchCh!);
      }
      break;
    case 'm':
      if (s.focus == Focus.detail) s.pendingM = true;
      break;
    case "'":
      if (s.focus == Focus.detail) s.pendingQuote = true;
      break;
    case '.':
      _repeatLastChange(s);
      break;
    case 'H':
      // prev "tab" — cycle field (title/tags/body) or list up 5.
      if (s.focus == Focus.detail) {
        s.fieldIdx = (s.fieldIdx + 2) % 3;
      } else {
        _move(s, dy: -5);
      }
      break;
    case 'L':
      if (s.focus == Focus.detail) {
        s.fieldIdx = (s.fieldIdx + 1) % 3;
      } else {
        _move(s, dy: 5);
      }
      break;
    case 'i':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.mode = Mode.insert;
        s.insertEntry = 'i';
        s.insertCapture.clear();
      }
      break;
    case 'I':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveHome();
        s.mode = Mode.insert;
        s.insertEntry = 'I';
        s.insertCapture.clear();
      }
      break;
    case 'a':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveRight();
        s.mode = Mode.insert;
        s.insertEntry = 'a';
        s.insertCapture.clear();
      }
      break;
    case 'A':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveEnd();
        s.mode = Mode.insert;
        s.insertEntry = 'A';
        s.insertCapture.clear();
      }
      break;
    case 'o':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.openLineBelow();
        s.mode = Mode.insert;
        s.insertEntry = 'o';
        s.insertCapture.clear();
      }
      break;
    case 'O':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.openLineAbove();
        s.mode = Mode.insert;
        s.insertEntry = 'O';
        s.insertCapture.clear();
      }
      break;
    case 'u':
      if (s.focus == Focus.detail) {
        if (s.activeBuf.undo()) {
          s.dirty = true;
          s.toast = '↶ undo';
        } else {
          s.toast = 'nothing to undo';
        }
      }
      break;
    case 'v':
      if (s.focus == Focus.detail) {
        s.mode = Mode.visual;
        s.activeBuf.startVisual(Mode.visual);
      }
      break;
    case 'V':
      if (s.focus == Focus.detail) {
        s.mode = Mode.visualLine;
        s.activeBuf.startVisual(Mode.visualLine);
      }
      break;
    case 'y':
      s.pendingY = true;
      break;
    case 'd':
      s.pendingD = true;
      break;
    case 'c':
      s.pendingC = true;
      break;
    case 'x':
      if (s.focus == Focus.detail) {
        final n = _consumeCount(s);
        s.activeBuf.snapshot();
        for (int i = 0; i < n; i++) {
          if (s.activeBuf.cursor.col >= s.activeBuf.currentLine().length) break;
          s.activeBuf.deleteCharAtCursor();
        }
        s.dirty = true;
        s.lastChangeKind = 'x';
        s.lastChangeCount = n;
      }
      break;
    case 'p':
      if (s.focus == Focus.detail) {
        final reg = s.activeRegister;
        final txt = reg != null
            ? (s.namedRegisters[reg] ?? '')
            : s.register;
        final lw = reg != null
            ? (s.namedRegistersLinewise[reg] ?? false)
            : s.registerLinewise;
        s.activeRegister = null;
        if (txt.isEmpty) break;
        s.activeBuf.snapshot();
        s.activeBuf.paste(txt, linewise: lw);
        s.dirty = true;
        s.lastChangeKind = 'p';
      }
      break;
    case '"':
      s.pendingRegister = true;
      break;
    case 'n':
      return const DispatchResult(create: true);
    case 'r':
      return const DispatchResult(needsReload: true);
    case '?':
      s.showHelp = !s.showHelp;
      break;
    case 'P':
      // Toggle pin on current note (list focus)
      if (s.focus == Focus.list) {
        final n = s.currentUnderList();
        if (n != null) {
          n.pinned = !n.pinned;
          s.toast = n.pinned ? '★ pinned' : 'unpinned';
        }
      }
      break;
  }
  return DispatchResult.none;
}


DispatchResult _leader(AppState s, Key k) {
  if (!k.isRune) return DispatchResult.none;
  switch (k.rune) {
    case 'q':
      return const DispatchResult(quit: true);
    case 'w':
      return const DispatchResult(save: true);
    case 'b':
      s.pendingLeaderB = true;
      break;
    case 'f':
      s.pendingLeaderF = true;
      break;
    case '/':
      s.mode = Mode.search;
      s.searchInput = '';
      s.searchCursor = 0;
      break;
    case 'r':
      return const DispatchResult(needsReload: true);
    case 'a':
      s.focus = Focus.chat;
      s.mode = Mode.normal;
      break;
    case 'e':
      // toggle tree pane visibility WITHOUT changing focus.
      // Use h/Tab to focus tree once open.
      s.treeOpen = !s.treeOpen;
      if (!s.treeOpen && s.focus == Focus.tree) s.focus = Focus.list;
      break;
    case 'x':
      // <space>x — open URL under cursor (mirror of gx)
      _openUrlUnderCursor(s);
      break;
    case 't':
      // Focus tree explicitly (opens if closed)
      s.focus = Focus.tree;
      s.treeOpen = true;
      break;
  }
  return DispatchResult.none;
}

DispatchResult _treeMode(AppState s, Key k) {
  final items = s.treeItems();
  // Support <space>e to close tree from within tree focus (bidirectional toggle).
  if (s.pendingLeader) {
    s.pendingLeader = false;
    if (k.isRune && k.rune == 'e') {
      s.treeOpen = false;
      s.focus = Focus.list;
    }
    return DispatchResult.none;
  }
  if (k.isRune && k.rune == ' ') {
    s.pendingLeader = true;
    return DispatchResult.none;
  }
  if (k.name == 'esc') {
    s.focus = Focus.list;
    return DispatchResult.none;
  }
  if (!k.isRune && k.name != 'enter') {
    if (k.name == 'up') { if (s.treeCursor > 0) s.treeCursor--; }
    if (k.name == 'down') {
      if (s.treeCursor < items.length - 1) s.treeCursor++;
    }
    return DispatchResult.none;
  }
  final r = k.rune;
  switch (r) {
    case 'j':
      if (s.treeCursor < items.length - 1) s.treeCursor++;
      break;
    case 'k':
      if (s.treeCursor > 0) s.treeCursor--;
      break;
    case 'g':
      s.treeCursor = 0;
      break;
    case 'G':
      s.treeCursor = items.length - 1;
      break;
    case 'l':
    case ' ':
      // apply filter, jump to list
      final it = items[s.treeCursor];
      s.treeFilter = it.key == '__all__' ? null : it.key;
      s.listCursor = 0;
      s.focus = Focus.list;
      break;
    case 'q':
      s.focus = s.lastMainFocus;
      break;
    case 'h':
      // stay in tree - h is no-op inside tree (already leftmost)
      break;
    case 'e':
      s.treeOpen = false;
      s.focus = Focus.list;
      break;
  }
  if (k.name == 'enter') {
    final it = items[s.treeCursor];
    s.treeFilter = it.key == '__all__' ? null : it.key;
    s.listCursor = 0;
    s.focus = Focus.list;
  }
  return DispatchResult.none;
}

// ---------------- CHAT ----------------

DispatchResult _chatMode(AppState s, Key k) {
  if (k.name == 'esc') {
    // exit chat mode → back to list
    s.focus = Focus.list;
    s.chatInput = '';
    s.chatCursor = 0;
    return DispatchResult.none;
  }
  if (k.name == 'enter') {
    if (s.chatInput.trim().isEmpty) return DispatchResult.none;
    s.chat.add(ChatMsg('user', s.chatInput.trim()));
    s.chatInput = '';
    s.chatCursor = 0;
    return const DispatchResult(chatSend: true);
  }
  if (k.name == 'ctrl+c') {
    return const DispatchResult(quit: true);
  }
  if (k.name == 'ctrl+l') {
    s.chat.clear();
    s.chatStreaming = null;
    return DispatchResult.none;
  }
  if (k.name == 'ctrl+w') {
    // toggle notes/web mode
    s.chatUseNotes = !s.chatUseNotes;
    s.toast = s.chatUseNotes ? 'mode: notes (RAG)' : 'mode: web (general chat)';
    s.toastErr = false;
    return DispatchResult.none;
  }
  if (k.name == 'backspace') {
    if (s.chatCursor > 0) {
      s.chatInput = s.chatInput.substring(0, s.chatCursor - 1) +
          s.chatInput.substring(s.chatCursor);
      s.chatCursor--;
    }
    return DispatchResult.none;
  }
  if (k.name == 'left' && s.chatCursor > 0) {
    s.chatCursor--;
    return DispatchResult.none;
  }
  if (k.name == 'right' && s.chatCursor < s.chatInput.length) {
    s.chatCursor++;
    return DispatchResult.none;
  }
  if (k.name == 'up') {
    if (s.chatScroll > 0) s.chatScroll--;
    return DispatchResult.none;
  }
  if (k.name == 'down') {
    s.chatScroll++;
    return DispatchResult.none;
  }
  if (k.name == 'home') {
    s.chatCursor = 0;
    return DispatchResult.none;
  }
  if (k.name == 'end') {
    s.chatCursor = s.chatInput.length;
    return DispatchResult.none;
  }
  if (k.isRune) {
    s.chatInput = s.chatInput.substring(0, s.chatCursor) +
        k.rune! +
        s.chatInput.substring(s.chatCursor);
    s.chatCursor += k.rune!.length;
  }
  return DispatchResult.none;
}

DispatchResult _leaderBuffer(AppState s, Key k) {
  if (!k.isRune) return DispatchResult.none;
  switch (k.rune) {
    case 'b':
      // fuzzy buffers — jump list mode
      if (s.focus == Focus.detail) {
        if (s.dirty) return const DispatchResult(save: true);
        s.closeDetail();
      }
      break;
    case 'd':
      return const DispatchResult(delete: true);
    case 'n':
      return const DispatchResult(create: true);
  }
  return DispatchResult.none;
}

DispatchResult _leaderFind(AppState s, Key k) {
  if (!k.isRune) return DispatchResult.none;
  switch (k.rune) {
    case 'g':
    case 'f':
      s.mode = Mode.search;
      s.searchInput = '';
      s.searchCursor = 0;
      break;
    case 'r':
      return const DispatchResult(needsReload: true);
  }
  return DispatchResult.none;
}

void _move(AppState s, {int dx = 0, int dy = 0}) {
  if (s.focus == Focus.list) {
    if (dy != 0) {
      final f = s.filtered();
      s.listCursor = (s.listCursor + dy).clamp(0, f.isEmpty ? 0 : f.length - 1);
    }
  } else {
    if (dy > 0) s.activeBuf.moveDown(dy);
    if (dy < 0) s.activeBuf.moveUp(-dy);
    if (dx > 0) s.activeBuf.moveRight(dx);
    if (dx < 0) s.activeBuf.moveLeft(-dx);
  }
}

// ---------------- INSERT ----------------

DispatchResult _insertMode(AppState s, Key k) {
  final b = s.activeBuf;
  // Snapshot once when entering insert (before first mutation).
  if (b.undoStack.isEmpty || b.undoStack.last.lines.join('\n') != b.text) {
    // no snapshot yet for this insert session
  }
  if (k.name == 'esc') {
    s.mode = Mode.normal;
    if (s.insertEntry != null) {
      s.lastChangeKind = 'insert:${s.insertEntry}';
      s.lastChangePayload = s.insertCapture.toString();
      s.lastChangeCount = 1;
      s.insertEntry = null;
    }
    return DispatchResult.none;
  }
  if (k.name == 'ctrl+s') return const DispatchResult(save: true);
  if (k.name == 'enter') {
    if (s.fieldIdx == 2) {
      b.insertNewline();
      s.insertCapture.write('\n');
      s.dirty = true;
    } else {
      // title/tags — Enter exits insert
      s.mode = Mode.normal;
      if (s.insertEntry != null) {
        s.lastChangeKind = 'insert:${s.insertEntry}';
        s.lastChangePayload = s.insertCapture.toString();
        s.insertEntry = null;
      }
    }
    return DispatchResult.none;
  }
  if (k.name == 'backspace') {
    b.backspace();
    s.dirty = true;
    // shrink capture if we've captured anything
    final str = s.insertCapture.toString();
    if (str.isNotEmpty) {
      s.insertCapture.clear();
      s.insertCapture.write(str.substring(0, str.length - 1));
    }
    return DispatchResult.none;
  }
  if (k.name == 'left')  { b.moveLeft();  return DispatchResult.none; }
  if (k.name == 'right') { b.moveRight(); return DispatchResult.none; }
  if (k.name == 'up')    { b.moveUp();    return DispatchResult.none; }
  if (k.name == 'down')  { b.moveDown();  return DispatchResult.none; }
  if (k.name == 'home')  { b.moveHome();  return DispatchResult.none; }
  if (k.name == 'end')   { b.moveEnd();   return DispatchResult.none; }
  if (k.isRune) {
    b.insertRune(k.rune!);
    s.insertCapture.write(k.rune!);
    s.dirty = true;
  }
  return DispatchResult.none;
}

// ---------------- VISUAL ----------------

DispatchResult _visualMode(AppState s, Key k) {
  if (k.name == 'esc') {
    s.activeBuf.clearVisual();
    s.mode = Mode.normal;
    return DispatchResult.none;
  }
  if (!k.isRune) return DispatchResult.none;
  switch (k.rune) {
    case 'h': s.activeBuf.moveLeft(); break;
    case 'l': s.activeBuf.moveRight(); break;
    case 'j': s.activeBuf.moveDown(); break;
    case 'k': s.activeBuf.moveUp(); break;
    case 'w': s.activeBuf.wordForward(); break;
    case 'b': s.activeBuf.wordBack(); break;
    case '0': s.activeBuf.moveHome(); break;
    case '\$': s.activeBuf.moveEnd(); break;
    case 'y':
      final a = s.activeBuf.anchor;
      final c = s.activeBuf.cursor;
      if (a != null) {
        final lo = a.row < c.row || (a.row == c.row && a.col < c.col) ? a : c;
        final hi = a.row < c.row || (a.row == c.row && a.col < c.col) ? c : a;
        s.flashYank(lo.row, lo.col, hi.row, hi.col);
      }
      s.register = s.activeBuf.yankSelection();
      s.registerLinewise = s.mode == Mode.visualLine;
      _stashNamed(s, linewise: s.registerLinewise);
      s.activeBuf.clearVisual();
      s.mode = Mode.normal;
      s.toast = '⟡ yanked ${s.register.length} chars';
      break;
    case 'd':
    case 'x':
      s.register = s.activeBuf.deleteSelection();
      s.registerLinewise = s.mode == Mode.visualLine;
      _stashNamed(s, linewise: s.registerLinewise);
      s.mode = Mode.normal;
      s.dirty = true;
      break;
    case 'c':
      s.register = s.activeBuf.deleteSelection();
      s.registerLinewise = s.mode == Mode.visualLine;
      _stashNamed(s, linewise: s.registerLinewise);
      s.mode = Mode.insert;
      s.dirty = true;
      break;
  }
  return DispatchResult.none;
}

// ---------------- SEARCH ----------------

DispatchResult _searchMode(AppState s, Key k) {
  if (k.name == 'esc') {
    s.searchInput = '';
    s.mode = Mode.normal;
    return DispatchResult.none;
  }
  if (k.name == 'enter') {
    s.search = s.searchInput;
    s.listCursor = 0;
    s.mode = Mode.normal;
    return DispatchResult.none;
  }
  if (k.name == 'backspace') {
    if (s.searchCursor > 0) {
      s.searchInput = s.searchInput.substring(0, s.searchCursor - 1) +
          s.searchInput.substring(s.searchCursor);
      s.searchCursor--;
    }
    return DispatchResult.none;
  }
  if (k.name == 'left' && s.searchCursor > 0) { s.searchCursor--; return DispatchResult.none; }
  if (k.name == 'right' && s.searchCursor < s.searchInput.length) { s.searchCursor++; return DispatchResult.none; }
  if (k.isRune) {
    s.searchInput = s.searchInput.substring(0, s.searchCursor) +
        k.rune! +
        s.searchInput.substring(s.searchCursor);
    s.searchCursor += k.rune!.length;
  }
  return DispatchResult.none;
}

// ---------------- CMD (:) ----------------

DispatchResult _cmdMode(AppState s, Key k) {
  if (k.name == 'esc') {
    s.cmdInput = '';
    s.mode = Mode.normal;
    return DispatchResult.none;
  }
  if (k.name == 'tab') {
    // Accept top completion (from render.dart cmdCompletions).
    final list = cmdCompletions(s.cmdInput);
    if (list.isNotEmpty) {
      s.cmdInput = list.first + ' ';
      s.cmdCursor = s.cmdInput.length;
    }
    return DispatchResult.none;
  }
  if (k.name == 'enter') {
    final cmd = s.cmdInput.trim();
    s.cmdInput = '';
    s.mode = Mode.normal;
    return _runCmd(s, cmd);
  }
  if (k.name == 'backspace') {
    if (s.cmdCursor > 0) {
      s.cmdInput =
          s.cmdInput.substring(0, s.cmdCursor - 1) + s.cmdInput.substring(s.cmdCursor);
      s.cmdCursor--;
    }
    return DispatchResult.none;
  }
  if (k.isRune) {
    s.cmdInput = s.cmdInput.substring(0, s.cmdCursor) +
        k.rune! +
        s.cmdInput.substring(s.cmdCursor);
    s.cmdCursor += k.rune!.length;
  }
  return DispatchResult.none;
}

DispatchResult _runCmd(AppState s, String cmd) {
  if (cmd.isEmpty) return DispatchResult.none;

  // :<N> — jump to line N in detail focus.
  if (RegExp(r'^\d+$').hasMatch(cmd)) {
    final n = int.parse(cmd);
    if (s.focus == Focus.detail) {
      s.activeBuf.cursor.row = (n - 1).clamp(0, s.activeBuf.lines.length - 1);
      s.activeBuf.cursor.col = 0;
    } else if (s.focus == Focus.list) {
      s.listCursor = (n - 1).clamp(0, s.filtered().length - 1);
    }
    return DispatchResult.none;
  }

  // :s/pat/repl/[g] and :%s/pat/repl/[g]
  final subMatch = RegExp(r'^(%?)s/(.*?)/(.*?)(/([gi]*))?$').firstMatch(cmd);
  if (subMatch != null) {
    return _runSubstitute(s,
        allLines: subMatch.group(1) == '%',
        pattern: subMatch.group(2) ?? '',
        replacement: subMatch.group(3) ?? '',
        flags: subMatch.group(5) ?? '');
  }

  // :e <query> — fuzzy open note by title
  if (cmd.startsWith('e ') || cmd == 'e') {
    final q = cmd.length > 2 ? cmd.substring(2).trim() : '';
    if (q.isEmpty) { s.toast = 'usage: :e <query>'; s.toastErr = true; return DispatchResult.none; }
    return _runOpenFuzzy(s, q);
  }

  // :!<shell> — shell command
  if (cmd.startsWith('!')) {
    _runShell(s, cmd.substring(1));
    return DispatchResult.none;
  }

  // Web / external integrations
  if (cmd.startsWith('o ') || cmd == 'o' || cmd.startsWith('open ') || cmd == 'open') {
    final arg = cmd.contains(' ') ? cmd.substring(cmd.indexOf(' ') + 1).trim() : '';
    if (arg.isEmpty) { s.toast = 'usage: :o <url>'; s.toastErr = true; return DispatchResult.none; }
    _openUrl(s, arg);
    return DispatchResult.none;
  }
  if (cmd.startsWith('import ')) {
    _importUrl(s, cmd.substring(7).trim());
    return DispatchResult.none;
  }
  if (cmd.startsWith('export ') || cmd == 'export') {
    final arg = cmd.length > 7 ? cmd.substring(7).trim() : '';
    _exportMarkdown(s, arg);
    return DispatchResult.none;
  }
  if (cmd.startsWith('exporthtml ') || cmd == 'exporthtml') {
    final arg = cmd.length > 11 ? cmd.substring(11).trim() : '';
    _exportHtml(s, arg);
    return DispatchResult.none;
  }
  if (cmd.startsWith('web ') || cmd == 'web') {
    final q = cmd.length > 4 ? cmd.substring(4).trim() : '';
    if (q.isEmpty) { s.toast = 'usage: :web <query>'; s.toastErr = true; return DispatchResult.none; }
    _openUrl(s, 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(q)}');
    return DispatchResult.none;
  }
  if (cmd.startsWith('cd ') || cmd == 'cd') {
    final p = cmd.length > 3 ? cmd.substring(3).trim() : '';
    _cd(s, p);
    return DispatchResult.none;
  }
  if (cmd.startsWith('read ')) {
    _readFile(s, cmd.substring(5).trim());
    return DispatchResult.none;
  }
  if (cmd.startsWith('pipe ')) {
    _pipeBuffer(s, cmd.substring(5).trim());
    return DispatchResult.none;
  }
  if (cmd == 'copy' || cmd == 'yank') {
    _clipCopy(s);
    return DispatchResult.none;
  }
  if (cmd == 'paste') {
    _clipPaste(s);
    return DispatchResult.none;
  }
  if (cmd.startsWith('sh ')) {
    _runShell(s, cmd.substring(3));
    return DispatchResult.none;
  }

  // :set <opt>
  if (cmd.startsWith('set ') || cmd == 'set') {
    return _runSet(s, cmd == 'set' ? '' : cmd.substring(4).trim());
  }

  // :sort — sort buffer lines
  if (cmd == 'sort' || cmd == 'sort!' || cmd == 'sortu') {
    _sortLines(s, reverse: cmd == 'sort!', unique: cmd == 'sortu');
    return DispatchResult.none;
  }

  // :g/pat/d — delete matching lines; :v/pat/d — delete non-matching
  final gMatch = RegExp(r'^(g|v)/(.*?)/d$').firstMatch(cmd);
  if (gMatch != null) {
    _globalDelete(s, gMatch.group(2) ?? '', invert: gMatch.group(1) == 'v');
    return DispatchResult.none;
  }

  // :daily — open/create today's daily note
  if (cmd == 'daily' || cmd == 'today') {
    return _openDaily(s);
  }

  // :bl / :backlinks — show notes linking to current
  if (cmd == 'bl' || cmd == 'backlinks') {
    _showBacklinks(s);
    return DispatchResult.none;
  }

  // :encrypt <passphrase> / :decrypt <passphrase>
  if (cmd.startsWith('encrypt ')) {
    _encryptBuffer(s, cmd.substring(8).trim());
    return DispatchResult.none;
  }
  if (cmd.startsWith('decrypt ')) {
    _decryptBuffer(s, cmd.substring(8).trim());
    return DispatchResult.none;
  }

  // :reg / :registers — list named registers
  if (cmd == 'reg' || cmd == 'registers') {
    if (s.namedRegisters.isEmpty) {
      s.toast = 'no named registers';
    } else {
      final list = s.namedRegisters.entries
          .map((e) => '"${e.key}=${e.value.length > 20 ? "${e.value.substring(0, 20)}…" : e.value.replaceAll("\n", "⏎")}')
          .join('  ');
      s.toast = list;
    }
    return DispatchResult.none;
  }

  // :marks — list marks in current buffer
  if (cmd == 'marks') {
    if (s.focus != Focus.detail) { s.toast = ':marks needs editor'; s.toastErr = true; return DispatchResult.none; }
    final b = s.activeBuf;
    if (b.marks.isEmpty) {
      s.toast = 'no marks set';
    } else {
      final list = b.marks.entries.map((e) => "'${e.key}=L${e.value + 1}").join('  ');
      s.toast = list;
    }
    return DispatchResult.none;
  }

  // :undolist — show undo stack size
  if (cmd == 'undolist' || cmd == 'undol') {
    if (s.focus == Focus.detail) {
      s.toast = 'undo=${s.activeBuf.undoStack.length} redo=${s.activeBuf.redoStack.length}';
    } else {
      s.toast = 'undolist needs editor';
      s.toastErr = true;
    }
    return DispatchResult.none;
  }

  final parts = cmd.split(RegExp(r'\s+'));
  final head = parts.first;
  final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  switch (head) {
    case 'q':
    case 'quit':
      // In detail: q on dirty = save-request. q! = discard.
      if (s.focus == Focus.detail) {
        s.dirty = false;
        s.closeDetail();
        return DispatchResult.none;
      }
      return const DispatchResult(quit: true);
    case 'q!':
    case 'quit!':
      s.dirty = false;
      if (s.focus == Focus.detail) {
        s.closeDetail();
        return DispatchResult.none;
      }
      return const DispatchResult(quit: true);
    case 'qa':
    case 'qall':
    case 'quitall':
      // quit app regardless of focus; dirty buffers block unless forced
      if (s.dirty && s.focus == Focus.detail) {
        s.toast = 'unsaved changes — use :qa! or :wqa';
        s.toastErr = true;
        return DispatchResult.none;
      }
      return const DispatchResult(quit: true);
    case 'qa!':
    case 'qall!':
    case 'quitall!':
      s.dirty = false;
      return const DispatchResult(quit: true);
    case 'wqa':
    case 'wqall':
    case 'xa':
    case 'xall':
      // save + quit app
      return const DispatchResult(save: true, quit: true);
    case 'w':
    case 'write':
      return const DispatchResult(save: true);
    case 'wq':
    case 'x':
      // save then close current
      return const DispatchResult(save: true);
    case 'new':
    case 'n':
      return const DispatchResult(create: true);
    case 'del':
    case 'd':
      return const DispatchResult(delete: true);
    case 'r':
    case 'reload':
      return const DispatchResult(needsReload: true);
    case 'search':
    case '/':
      s.search = rest;
      s.listCursor = 0;
      break;
    case 'help':
    case 'h':
      s.showHelp = true;
      break;
    case 'pwd':
      s.toast = Directory.current.path;
      break;
    default:
      s.toast = 'unknown: $head';
      s.toastErr = true;
  }
  return DispatchResult.none;
}

// ---------------- helper impls for new features ----------------

void _stashNamed(AppState s, {required bool linewise}) {
  final r = s.activeRegister;
  if (r == null) return;
  s.namedRegisters[r] = s.register;
  s.namedRegistersLinewise[r] = linewise;
  s.activeRegister = null;
}

int _countWords(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

void _deleteWord(dynamic buf) {
  // buf is Buffer; delete from cursor.col to next-word-start on current line.
  final line = buf.currentLine() as String;
  final start = buf.cursor.col as int;
  if (start >= line.length) return;
  int i = start;
  // consume word chars, then whitespace
  bool _isW(int cu) =>
      (cu >= 0x30 && cu <= 0x39) ||
      (cu >= 0x41 && cu <= 0x5a) ||
      (cu >= 0x61 && cu <= 0x7a) ||
      cu == 0x5f;
  if (i < line.length && _isW(line.codeUnitAt(i))) {
    while (i < line.length && _isW(line.codeUnitAt(i))) i++;
  } else {
    while (i < line.length && !_isW(line.codeUnitAt(i))) i++;
  }
  while (i < line.length && line[i] == ' ') i++;
  buf.lines[buf.cursor.row] = line.substring(0, start) + line.substring(i);
}

void _repeatLastChange(AppState s) {
  final kind = s.lastChangeKind;
  if (kind == null) return;
  final b = s.focus == Focus.detail ? s.activeBuf : null;
  if (b == null && !kind.startsWith('insert')) return;
  if (kind.startsWith('insert:')) {
    if (s.focus != Focus.detail) return;
    final entry = kind.substring('insert:'.length);
    b!.snapshot();
    switch (entry) {
      case 'I': b.moveHome(); break;
      case 'A': b.moveEnd(); break;
      case 'a': b.moveRight(); break;
      case 'o': b.openLineBelow(); break;
      case 'O': b.openLineAbove(); break;
    }
    final text = s.lastChangePayload ?? '';
    for (final ch in text.split('')) {
      if (ch == '\n') {
        b.insertNewline();
      } else {
        b.insertRune(ch);
      }
    }
    s.dirty = true;
    return;
  }
  switch (kind) {
    case 'x':
      b!.snapshot();
      for (int i = 0; i < s.lastChangeCount; i++) {
        if (b.cursor.col >= b.currentLine().length) break;
        b.deleteCharAtCursor();
      }
      s.dirty = true;
      break;
    case 'dd':
      b!.snapshot();
      for (int i = 0; i < s.lastChangeCount; i++) {
        b.deleteLine();
      }
      s.dirty = true;
      break;
    case 'dw':
      b!.snapshot();
      for (int i = 0; i < s.lastChangeCount; i++) {
        _deleteWord(b);
      }
      s.dirty = true;
      break;
    case 'p':
      if (s.register.isEmpty) return;
      b!.snapshot();
      b.paste(s.register, linewise: s.registerLinewise);
      s.dirty = true;
      break;
    case 'yy':
      // Yank isn't really a "change" — ignore.
      break;
  }
}

DispatchResult _runSubstitute(AppState s, {
  required bool allLines,
  required String pattern,
  required String replacement,
  required String flags,
}) {
  if (s.focus != Focus.detail) {
    s.toast = ':s only in editor';
    s.toastErr = true;
    return DispatchResult.none;
  }
  if (pattern.isEmpty) {
    s.toast = 'empty pattern';
    s.toastErr = true;
    return DispatchResult.none;
  }
  RegExp re;
  try {
    re = RegExp(pattern, caseSensitive: !flags.contains('i'));
  } catch (e) {
    s.toast = 'bad pattern';
    s.toastErr = true;
    return DispatchResult.none;
  }
  final b = s.activeBuf;
  b.snapshot();
  final global = flags.contains('g');
  int count = 0;
  final rows = allLines
      ? List<int>.generate(b.lines.length, (i) => i)
      : [b.cursor.row];
  for (final r in rows) {
    final line = b.lines[r];
    String replaced;
    if (global) {
      replaced = line.replaceAllMapped(re, (m) { count++; return replacement; });
    } else {
      final m = re.firstMatch(line);
      if (m != null) { count++; replaced = line.replaceFirst(re, replacement); }
      else { replaced = line; }
    }
    b.lines[r] = replaced;
  }
  b.clamp();
  if (count > 0) {
    s.dirty = true;
    s.toast = '$count substitutions';
  } else {
    s.toast = 'no match';
  }
  return DispatchResult.none;
}

DispatchResult _runOpenFuzzy(AppState s, String query) {
  final q = query.toLowerCase();
  final scored = s.notes.map((n) {
    final hay = n.title.toLowerCase();
    return (AppState.fuzzyScore(q, hay), n);
  }).where((e) => e.$1 > 0).toList()
    ..sort((a, b) => b.$1.compareTo(a.$1));
  if (scored.isEmpty) {
    s.toast = 'no match';
    s.toastErr = true;
    return DispatchResult.none;
  }
  s.openNoteForEdit(scored.first.$2);
  return DispatchResult.none;
}

void _runShell(AppState s, String shellCmd) {
  final cmd = shellCmd.trim();
  if (cmd.isEmpty) { s.toast = 'usage: :!<cmd>'; s.toastErr = true; return; }
  try {
    final r = Process.runSync('sh', ['-c', cmd]);
    final out = (r.stdout as String).split('\n').firstWhere((l) => l.isNotEmpty, orElse: () => '');
    s.toast = out.isEmpty
        ? 'exit ${r.exitCode}'
        : '$out (exit ${r.exitCode})';
    s.toastErr = r.exitCode != 0;
  } catch (e) {
    s.toast = 'shell err: $e';
    s.toastErr = true;
  }
}

// ---------------- Web / external helpers ----------------

final RegExp urlRegex = RegExp(r'https?://[^\s<>()\[\]"]+');

String? urlUnderCursor(String line, int col) {
  for (final m in urlRegex.allMatches(line)) {
    if (col >= m.start && col <= m.end) return m.group(0);
  }
  return null;
}

int countUrls(String text) => urlRegex.allMatches(text).length;

String stripHtml(String html) {
  var s = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = s.replaceAll(RegExp(r'&nbsp;'), ' ');
  s = s.replaceAll(RegExp(r'&amp;'), '&');
  s = s.replaceAll(RegExp(r'&lt;'), '<');
  s = s.replaceAll(RegExp(r'&gt;'), '>');
  s = s.replaceAll(RegExp(r'&quot;'), '"');
  s = s.replaceAll(RegExp(r'&#39;'), "'");
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}

String slugify(String title) {
  var s = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) s = 'note';
  return s;
}

String expandTilde(String p) {
  if (!p.startsWith('~')) return p;
  final home = Platform.environment['HOME'] ?? '';
  return home + p.substring(1);
}

String _openerCmd() {
  if (Platform.isMacOS) return 'open';
  if (Platform.isWindows) return 'start';
  return 'xdg-open';
}

void _openUrl(AppState s, String url) {
  try {
    Process.start(_openerCmd(), [url], mode: ProcessStartMode.detached);
    s.toast = 'opened $url';
  } catch (e) {
    s.toast = 'open err: $e';
    s.toastErr = true;
  }
}

void _openUrlUnderCursor(AppState s) {
  if (s.focus != Focus.detail) { s.toast = 'gx needs editor'; s.toastErr = true; return; }
  final b = s.activeBuf;
  final url = urlUnderCursor(b.currentLine(), b.cursor.col);
  if (url == null) { s.toast = 'no url under cursor'; s.toastErr = true; return; }
  _openUrl(s, url);
}

void _importUrl(AppState s, String url) {
  if (url.isEmpty) { s.toast = 'usage: :import <url>'; s.toastErr = true; return; }
  try {
    final client = HttpClient();
    client.getUrl(Uri.parse(url)).then((req) => req.close()).then((resp) async {
      final body = await resp.transform(const _Utf8Decoder()).join();
      final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false).firstMatch(body);
      final title = titleMatch != null ? stripHtml(titleMatch.group(1) ?? url) : url;
      final text = stripHtml(body);
      final excerpt = text.length > 4000 ? text.substring(0, 4000) : text;
      final now = DateTime.now();
      final firstUserId = s.notes.isNotEmpty ? s.notes.first.userId : '';
      s.notes.insert(0, Note(
        id: now.microsecondsSinceEpoch.toString(),
        userId: firstUserId,
        title: title,
        body: '# $title\n\n<$url>\n\n$excerpt',
        tags: ['imported'],
        pinned: false,
        createdAt: now,
        updatedAt: now,
      ));
      s.toast = 'imported: $title';
    }).catchError((e) {
      s.toast = 'import err: $e';
      s.toastErr = true;
    });
  } catch (e) {
    s.toast = 'import err: $e';
    s.toastErr = true;
  }
}

void _exportMarkdown(AppState s, String path) {
  if (s.current == null) { s.toast = 'no note open'; s.toastErr = true; return; }
  s.syncBufsToNote();
  final n = s.current!;
  final target = path.isEmpty
      ? '${Platform.environment['HOME'] ?? '.'}/${slugify(n.title)}.md'
      : expandTilde(path);
  try {
    final body = '# ${n.title}\n\ntags: ${n.tags.join(', ')}\n\n${n.body}\n';
    File(target).writeAsStringSync(body);
    s.toast = 'exported to $target';
  } catch (e) {
    s.toast = 'export err: $e';
    s.toastErr = true;
  }
}

void _exportHtml(AppState s, String path) {
  if (s.current == null) { s.toast = 'no note open'; s.toastErr = true; return; }
  s.syncBufsToNote();
  final n = s.current!;
  final target = path.isEmpty
      ? '${Platform.environment['HOME'] ?? '.'}/${slugify(n.title)}.html'
      : expandTilde(path);
  final esc = (String x) => x
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  try {
    final html = '''<!doctype html>
<html><head><meta charset="utf-8"><title>${esc(n.title)}</title>
<style>body{font-family:system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;line-height:1.6;color:#222}pre{white-space:pre-wrap;background:#f6f8fa;padding:1rem;border-radius:8px}h1{border-bottom:1px solid #eee;padding-bottom:.4rem}.tags{color:#888;font-size:.9rem}</style>
</head><body><h1>${esc(n.title)}</h1><div class="tags">${esc(n.tags.join(', '))}</div><pre>${esc(n.body)}</pre></body></html>''';
    File(target).writeAsStringSync(html);
    s.toast = 'exported html to $target';
  } catch (e) {
    s.toast = 'export err: $e';
    s.toastErr = true;
  }
}

void _cd(AppState s, String p) {
  final path = p.isEmpty ? (Platform.environment['HOME'] ?? '.') : expandTilde(p);
  try {
    Directory.current = path;
    s.toast = 'cwd: ${Directory.current.path}';
  } catch (e) {
    s.toast = 'cd err: $e';
    s.toastErr = true;
  }
}

void _readFile(AppState s, String p) {
  if (s.focus != Focus.detail) { s.toast = ':read needs editor'; s.toastErr = true; return; }
  try {
    final txt = File(expandTilde(p)).readAsStringSync();
    final b = s.activeBuf;
    b.snapshot();
    for (final ch in txt.split('')) {
      if (ch == '\n') { b.insertNewline(); } else { b.insertRune(ch); }
    }
    s.dirty = true;
    s.toast = 'read ${txt.length} chars';
  } catch (e) {
    s.toast = 'read err: $e';
    s.toastErr = true;
  }
}

void _pipeBuffer(AppState s, String cmd) {
  if (s.focus != Focus.detail) { s.toast = ':pipe needs editor'; s.toastErr = true; return; }
  if (cmd.isEmpty) { s.toast = 'usage: :pipe <cmd>'; s.toastErr = true; return; }
  try {
    final b = s.activeBuf;
    final proc = Process.runSync('sh', ['-c', cmd]);
    // Fallback: write via shell echo pipe since runSync has no stdin
    final tmp = File('${Directory.systemTemp.path}/syncnote-pipe-${DateTime.now().microsecondsSinceEpoch}.txt');
    tmp.writeAsStringSync(b.text);
    final r = Process.runSync('sh', ['-c', 'cat "${tmp.path}" | $cmd']);
    try { tmp.deleteSync(); } catch (_) {}
    if (r.exitCode != 0) {
      s.toast = 'pipe exit ${r.exitCode}';
      s.toastErr = true;
      return;
    }
    b.snapshot();
    final out = (r.stdout as String);
    b.lines = out.isEmpty ? [''] : out.split('\n');
    if (b.lines.last.isEmpty && b.lines.length > 1) b.lines.removeLast();
    b.cursor.row = 0;
    b.cursor.col = 0;
    s.dirty = true;
    s.toast = 'piped ${b.text.length} chars';
    // silence unused proc var
    proc.exitCode;
  } catch (e) {
    s.toast = 'pipe err: $e';
    s.toastErr = true;
  }
}

void _clipCopy(AppState s) {
  final text = s.focus == Focus.detail ? s.activeBuf.text : (s.current?.body ?? '');
  if (text.isEmpty) { s.toast = 'nothing to copy'; return; }
  final tools = [
    ['wl-copy', <String>[]],
    ['xclip', ['-selection', 'clipboard']],
    ['pbcopy', <String>[]],
  ];
  for (final t in tools) {
    try {
      final p = Process.runSync(
          'sh', ['-c', 'command -v ${t[0]}'],
          runInShell: false);
      if (p.exitCode != 0) continue;
      final proc = Process.runSync(t[0] as String, t[1] as List<String>);
      // runSync no stdin — use shell pipe
      final tmp = File('${Directory.systemTemp.path}/syncnote-clip-${DateTime.now().microsecondsSinceEpoch}.txt');
      tmp.writeAsStringSync(text);
      final r = Process.runSync('sh', ['-c', 'cat "${tmp.path}" | ${t[0]} ${(t[1] as List<String>).join(' ')}']);
      try { tmp.deleteSync(); } catch (_) {}
      if (r.exitCode == 0) {
        s.toast = 'copied via ${t[0]}';
        proc.exitCode;
        return;
      }
    } catch (_) {}
  }
  // Fallback file
  try {
    File('/tmp/syncnote-clip.txt').writeAsStringSync(text);
    s.toast = 'copied to /tmp/syncnote-clip.txt (no clipboard tool)';
  } catch (e) {
    s.toast = 'clip err: $e';
    s.toastErr = true;
  }
}

void _clipPaste(AppState s) {
  if (s.focus != Focus.detail) { s.toast = ':paste needs editor'; s.toastErr = true; return; }
  final tools = [
    ['wl-paste', <String>[]],
    ['xclip', ['-selection', 'clipboard', '-o']],
    ['pbpaste', <String>[]],
  ];
  for (final t in tools) {
    try {
      final check = Process.runSync('sh', ['-c', 'command -v ${t[0]}']);
      if (check.exitCode != 0) continue;
      final r = Process.runSync(t[0] as String, t[1] as List<String>);
      if (r.exitCode == 0) {
        final b = s.activeBuf;
        b.snapshot();
        final txt = (r.stdout as String);
        for (final ch in txt.split('')) {
          if (ch == '\n') { b.insertNewline(); } else { b.insertRune(ch); }
        }
        s.dirty = true;
        s.toast = 'pasted via ${t[0]}';
        return;
      }
    } catch (_) {}
  }
  // Fallback file
  try {
    final txt = File('/tmp/syncnote-clip.txt').readAsStringSync();
    final b = s.activeBuf;
    b.snapshot();
    for (final ch in txt.split('')) {
      if (ch == '\n') { b.insertNewline(); } else { b.insertRune(ch); }
    }
    s.dirty = true;
    s.toast = 'pasted from /tmp/syncnote-clip.txt';
  } catch (e) {
    s.toast = 'no clipboard: $e';
    s.toastErr = true;
  }
}

/// Simple XOR+base64 stream cipher, keyed by SHA-256-like fold of passphrase.
/// Not cryptographically strong — sufficient for casual obscuration.
/// Uses a distinctive "SNENC1:" marker to identify encrypted payloads.
const _encMarker = 'SNENC1:';

List<int> _keyStream(String pass, int len) {
  final bytes = utf8.encode(pass);
  // Simple key expansion: repeat + rotate + XOR chain
  final ks = List<int>.filled(len, 0);
  int acc = 0x9e3779b9;
  for (int i = 0; i < len; i++) {
    acc = ((acc * 1664525) + 1013904223) & 0xFFFFFFFF;
    ks[i] = (bytes[i % bytes.length] ^ (acc & 0xff)) & 0xff;
  }
  return ks;
}

String snEncrypt(String plain, String pass) {
  final bytes = utf8.encode(plain);
  final ks = _keyStream(pass, bytes.length);
  final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ ks[i]);
  return _encMarker + base64Encode(out);
}

String? snDecrypt(String cipher, String pass) {
  if (!cipher.startsWith(_encMarker)) return null;
  try {
    final bytes = base64Decode(cipher.substring(_encMarker.length));
    final ks = _keyStream(pass, bytes.length);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ ks[i]);
    return utf8.decode(out);
  } catch (_) {
    return null;
  }
}

void _encryptBuffer(AppState s, String pass) {
  if (s.focus != Focus.detail) { s.toast = ':encrypt needs editor'; s.toastErr = true; return; }
  if (pass.isEmpty) { s.toast = 'usage: :encrypt <passphrase>'; s.toastErr = true; return; }
  final b = s.activeBuf;
  if (b.text.startsWith(_encMarker)) { s.toast = 'already encrypted'; return; }
  b.snapshot();
  final enc = snEncrypt(b.text, pass);
  b.lines = [enc];
  b.cursor.row = 0;
  b.cursor.col = 0;
  s.dirty = true;
  s.toast = 'encrypted (${enc.length} chars)';
}

void _decryptBuffer(AppState s, String pass) {
  if (s.focus != Focus.detail) { s.toast = ':decrypt needs editor'; s.toastErr = true; return; }
  if (pass.isEmpty) { s.toast = 'usage: :decrypt <passphrase>'; s.toastErr = true; return; }
  final b = s.activeBuf;
  final plain = snDecrypt(b.text.trim(), pass);
  if (plain == null) { s.toast = 'bad ciphertext or wrong pass'; s.toastErr = true; return; }
  b.snapshot();
  b.lines = plain.isEmpty ? [''] : plain.split('\n');
  b.cursor.row = 0;
  b.cursor.col = 0;
  s.dirty = true;
  s.toast = 'decrypted (${plain.length} chars)';
}

void _sortLines(AppState s, {bool reverse = false, bool unique = false}) {
  if (s.focus != Focus.detail) { s.toast = ':sort needs editor'; s.toastErr = true; return; }
  final b = s.activeBuf;
  b.snapshot();
  var ls = List<String>.of(b.lines);
  ls.sort();
  if (reverse) ls = ls.reversed.toList();
  if (unique) {
    final seen = <String>{};
    ls = ls.where(seen.add).toList();
  }
  b.lines = ls;
  b.clamp();
  s.dirty = true;
  s.toast = 'sorted ${ls.length} lines${unique ? " (unique)" : ""}';
}

void _globalDelete(AppState s, String pattern, {bool invert = false}) {
  if (s.focus != Focus.detail) { s.toast = ':g needs editor'; s.toastErr = true; return; }
  if (pattern.isEmpty) { s.toast = 'empty pattern'; s.toastErr = true; return; }
  RegExp re;
  try { re = RegExp(pattern); } catch (_) { s.toast = 'bad pattern'; s.toastErr = true; return; }
  final b = s.activeBuf;
  b.snapshot();
  final kept = b.lines.where((l) => invert ? re.hasMatch(l) : !re.hasMatch(l)).toList();
  final removed = b.lines.length - kept.length;
  b.lines = kept.isEmpty ? [''] : kept;
  b.clamp();
  s.dirty = true;
  s.toast = 'deleted $removed lines';
}

String _dailyTitle() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return 'daily ${now.year}-$m-$d';
}

DispatchResult _openDaily(AppState s) {
  final title = _dailyTitle();
  final existing = s.notes.where((n) => n.title == title).firstOrNull;
  if (existing != null) {
    s.openNoteForEdit(existing);
    return DispatchResult.none;
  }
  final now = DateTime.now();
  final firstUserId = s.notes.isNotEmpty ? s.notes.first.userId : '';
  final n = Note(
    id: now.microsecondsSinceEpoch.toString(),
    userId: firstUserId,
    title: title,
    body: '# $title\n\n## notes\n\n- \n\n## tasks\n\n- [ ] \n',
    tags: ['daily'],
    pinned: false,
    createdAt: now,
    updatedAt: now,
  );
  s.notes.insert(0, n);
  s.openNoteForEdit(n);
  s.toast = 'daily note';
  return DispatchResult.none;
}

/// Extract wiki-links [[title]] from body.
List<String> extractWikiLinks(String body) =>
    RegExp(r'\[\[([^\]]+)\]\]').allMatches(body).map((m) => m.group(1)!.trim()).toList();

void _showBacklinks(AppState s) {
  if (s.current == null) { s.toast = 'no note open'; s.toastErr = true; return; }
  final title = s.current!.title;
  final backlinks = s.notes.where((n) {
    if (n.id == s.current!.id) return false;
    return extractWikiLinks(n.body).any((l) => l.toLowerCase() == title.toLowerCase());
  }).toList();
  if (backlinks.isEmpty) {
    s.toast = 'no backlinks';
    return;
  }
  s.toast = '${backlinks.length} backlinks: ${backlinks.take(3).map((n) => n.title).join(", ")}${backlinks.length > 3 ? "…" : ""}';
}

class _Utf8Decoder extends Converter<List<int>, String> {
  const _Utf8Decoder();
  @override
  String convert(List<int> input) => utf8.decode(input, allowMalformed: true);
  @override
  Sink<List<int>> startChunkedConversion(Sink<String> sink) =>
      utf8.decoder.startChunkedConversion(sink);
}

DispatchResult _runSet(AppState s, String opt) {
  if (opt.isEmpty) {
    s.toast = 'wrap=${s.wrapMode} number=${s.showNumbers}';
    return DispatchResult.none;
  }
  switch (opt) {
    case 'wrap':      s.wrapMode = true; s.toast = 'wrap on'; break;
    case 'nowrap':    s.wrapMode = false; s.toast = 'wrap off'; break;
    case 'number':    s.showNumbers = true; s.toast = 'number on'; break;
    case 'nonumber':  s.showNumbers = false; s.toast = 'number off'; break;
    default:
      if (opt.startsWith('theme ')) {
        s.toast = 'themes: default (only theme available)';
      } else {
        s.toast = 'unknown :set option';
        s.toastErr = true;
      }
  }
  return DispatchResult.none;
}
