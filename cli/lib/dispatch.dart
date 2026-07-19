// Key dispatcher — maps Key events to state mutations. Pure functions where possible.

import 'ai.dart';
import 'keys.dart';
import 'model.dart';
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

DispatchResult _normalMode(AppState s, Key k) {
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
      if (s.focus == Focus.list) {
        s.listCursor = 0;
      } else {
        s.activeBuf.moveTop();
      }
    }
    return DispatchResult.none;
  }
  // yy dd cc
  if (s.pendingY) {
    s.pendingY = false;
    if (k.isRune && k.rune == 'y') {
      if (s.focus == Focus.list) {
        final n = s.currentUnderList();
        if (n != null) {
          s.register = n.title;
          s.toast = '⟡ yanked title';
        }
      } else {
        s.register = s.activeBuf.currentLine();
        s.registerLinewise = true;
        final r = s.activeBuf.cursor.row;
        final len = s.activeBuf.currentLine().length;
        s.flashYank(r, 0, r, len);
        s.toast = '⟡ yanked line';
      }
    }
    return DispatchResult.none;
  }
  if (s.pendingD) {
    s.pendingD = false;
    if (k.isRune && k.rune == 'd') {
      if (s.focus == Focus.list) {
        return const DispatchResult(delete: true);
      }
      s.activeBuf.snapshot();
      s.register = s.activeBuf.deleteLine();
      s.registerLinewise = true;
      s.dirty = true;
      s.toast = 'deleted line';
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
  if (!k.isRune) return DispatchResult.none;
  final r = k.rune;

  switch (r) {
    case ' ':
      s.pendingLeader = true;
      break;
    case ':':
      s.mode = Mode.cmd;
      s.cmdInput = '';
      s.cmdCursor = 0;
      break;
    case '/':
      s.mode = Mode.search;
      s.searchInput = s.search;
      s.searchCursor = s.searchInput.length;
      break;
    case 'q':
      if (s.focus == Focus.detail) {
        if (s.dirty) return const DispatchResult(save: true);
        s.closeDetail();
      } else {
        s.mode = Mode.confirmQuit;
      }
      break;
    case 'j':
      _move(s, dy: 1);
      break;
    case 'k':
      _move(s, dy: -1);
      break;
    case 'h':
      if (s.focus == Focus.list && s.treeOpen) {
        s.focus = Focus.tree;
      } else {
        _move(s, dx: -1);
      }
      break;
    case 'l':
      if (s.focus == Focus.tree) {
        s.focus = Focus.list;
      } else {
        _move(s, dx: 1);
      }
      break;
    case 'g':
      s.pendingG = true;
      break;
    case 'G':
      if (s.focus == Focus.list) {
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
      if (s.focus == Focus.detail) s.activeBuf.wordForward();
      break;
    case 'b':
      if (s.focus == Focus.detail) s.activeBuf.wordBack();
      break;
    case 'e':
      if (s.focus == Focus.detail) s.activeBuf.wordEnd();
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
      }
      break;
    case 'I':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveHome();
        s.mode = Mode.insert;
      }
      break;
    case 'a':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveRight();
        s.mode = Mode.insert;
      }
      break;
    case 'A':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.moveEnd();
        s.mode = Mode.insert;
      }
      break;
    case 'o':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.openLineBelow();
        s.mode = Mode.insert;
      }
      break;
    case 'O':
      if (s.focus == Focus.detail) {
        s.activeBuf.snapshot();
        s.activeBuf.openLineAbove();
        s.mode = Mode.insert;
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
        s.activeBuf.snapshot();
        s.register = s.activeBuf.currentLine()
            .substring(s.activeBuf.cursor.col, (s.activeBuf.cursor.col + 1).clamp(0, s.activeBuf.currentLine().length));
        s.activeBuf.deleteCharAtCursor();
        s.dirty = true;
      }
      break;
    case 'p':
      if (s.focus == Focus.detail && s.register.isNotEmpty) {
        s.activeBuf.snapshot();
        s.activeBuf.paste(s.register, linewise: s.registerLinewise);
        s.dirty = true;
      }
      break;
    case 'n':
      return const DispatchResult(create: true);
    case 'r':
      return const DispatchResult(needsReload: true);
    case '?':
      s.showHelp = !s.showHelp;
      break;
  }
  return DispatchResult.none;
}

String _hintNormal(AppState s) => s.focus == Focus.list
    ? 'j/k G g move · Enter open · n new · dd del · yy yank · / search · : cmd · <space>… leader · q quit'
    : 'hjkl move · i/I/a/A/o/O insert · v/V visual · y d c · p paste · Tab field · q back';

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
      // toggle tree pane
      s.treeOpen = !s.treeOpen;
      if (!s.treeOpen && s.focus == Focus.tree) s.focus = Focus.list;
      if (s.treeOpen) s.focus = Focus.tree;
      break;
    case 't':
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
      s.focus = Focus.list;
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
    return DispatchResult.none;
  }
  if (k.name == 'ctrl+s') return const DispatchResult(save: true);
  if (k.name == 'enter') {
    if (s.fieldIdx == 2) {
      b.insertNewline();
      s.dirty = true;
    } else {
      // title/tags — Enter exits insert
      s.mode = Mode.normal;
    }
    return DispatchResult.none;
  }
  if (k.name == 'backspace') { b.backspace(); s.dirty = true; return DispatchResult.none; }
  if (k.name == 'left')  { b.moveLeft();  return DispatchResult.none; }
  if (k.name == 'right') { b.moveRight(); return DispatchResult.none; }
  if (k.name == 'up')    { b.moveUp();    return DispatchResult.none; }
  if (k.name == 'down')  { b.moveDown();  return DispatchResult.none; }
  if (k.name == 'home')  { b.moveHome();  return DispatchResult.none; }
  if (k.name == 'end')   { b.moveEnd();   return DispatchResult.none; }
  if (k.isRune) {
    b.insertRune(k.rune!);
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
      s.activeBuf.clearVisual();
      s.mode = Mode.normal;
      s.toast = '⟡ yanked ${s.register.length} chars';
      break;
    case 'd':
    case 'x':
      s.register = s.activeBuf.deleteSelection();
      s.registerLinewise = s.mode == Mode.visualLine;
      s.mode = Mode.normal;
      s.dirty = true;
      break;
    case 'c':
      s.register = s.activeBuf.deleteSelection();
      s.registerLinewise = s.mode == Mode.visualLine;
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
    default:
      s.toast = 'unknown: $head';
      s.toastErr = true;
  }
  return DispatchResult.none;
}
