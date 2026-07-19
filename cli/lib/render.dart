// Full-redesign render.
// Layout:
//   ╭─ SyncNote  ●realtime ──────────────────────────────╮
//   │  📁 tree   │  ▸ Note title              tag  4h    │
//   │  ▸ #work   │    body preview             tag       │
//   │            │  ▸ Another note                       │
//   ├────────────┴──────────────────────────────────────┤
//   │ NORMAL │ 3/12 │ inbox │                    ● Doom │
//   ╰─  ⌘ leader: <space>  · e tree · a AI · / find · q quit ╯

import 'ai.dart';
import 'ansi.dart';
import 'markdown.dart';
import 'model.dart';
import 'state.dart';

class Frame {
  final List<String> rows;
  final int? cursorRow;
  final int? cursorCol;
  const Frame(this.rows, {this.cursorRow, this.cursorCol});
}

// ---------- palette shortcuts ----------

String _c(String fg, String bg) => sty([fg, bg]);
String _r() => sty(['0']);

Frame renderFrame(AppState s, int w, int h) {
  final rows = <String>[];

  // Help overlay pre-empts everything.
  if (s.showHelp) {
    return _renderHelp(s, w, h);
  }

  // top bar (2 rows)
  rows.add(_topBar(s, w));
  rows.add(_divider(s, w));

  final bodyH = h - 5; // top(2) + statusline(2) + hint(1)
  // Responsive layout: [tree] [list] [preview]. Preview only when
  // terminal wide and we're on list focus (not detail editor).
  final layout = _computeLayout(s, w);
  final treeW = layout.tree;
  final previewW = layout.preview;
  final mainW = w - treeW - previewW;

  if (s.focus == Focus.chat) {
    rows.addAll(_renderChat(s, w, bodyH));
  } else {
    // Reserve 1 col for each active divider — reduce main width so alignment stays.
    final treeDivW = treeW > 0 ? 1 : 0;
    final previewDivW = previewW > 0 ? 1 : 0;
    final actualMainW = mainW - treeDivW - previewDivW;

    final treeLines = treeW > 0 ? _renderTree(s, treeW, bodyH) : <String>[];
    final mainLines = s.focus == Focus.detail
        ? _renderDetail(s, actualMainW, bodyH)
        : _renderList(s, actualMainW, bodyH);
    final previewLines = previewW > 0 && s.focus != Focus.detail
        ? _renderPreview(s, previewW, bodyH)
        : <String>[];
    final dashedDiv = _c(Colors.muted, Colors.bgBase) + '┊' + _r();
    for (int i = 0; i < bodyH; i++) {
      final t = i < treeLines.length ? treeLines[i] : '';
      final m = i < mainLines.length ? mainLines[i] : '';
      final p = i < previewLines.length ? previewLines[i] : '';
      final tDiv = treeW > 0 ? dashedDiv : '';
      final pDiv = previewW > 0 ? dashedDiv : '';
      rows.add(t + tDiv + m + pDiv + p);
    }
  }

  rows.add(_statusline(s, w));
  rows.add(_hintline(s, w));

  int? cr, cc;
  if (s.focus == Focus.chat) {
    cr = h - 3;
    cc = 3 + s.chatCursor;
  } else if (s.mode == Mode.search) {
    // Hint line format: ' /<input>' → 2-char prefix (space + '/').
    cr = h - 1;
    cc = 2 + s.searchCursor;
  } else if (s.mode == Mode.cmd) {
    // Hint line format: ' :<input>' → 2-char prefix.
    cr = h - 1;
    cc = 2 + s.cmdCursor;
  } else if (s.focus == Focus.detail) {
    final pos = _detailCursorPosition(s, mainW);
    if (pos != null) {
      cr = 2 + pos.$1; // +2 for top bar
      cc = treeW + (treeW > 0 ? 1 : 0) + pos.$2;
    }
  } else if (s.focus == Focus.list) {
    cr = 2 + (s.listCursor - s.listScroll);
    cc = treeW + (treeW > 0 ? 1 : 0) + 4;
  } else if (s.focus == Focus.tree) {
    // +1 for tree header row (📁 spaces).
    cr = 3 + s.treeCursor;
    cc = 4;
  }
  return Frame(rows, cursorRow: cr, cursorCol: cc);
}

(int, int)? _detailCursorPosition(AppState s, int mainW) {
  final gutterW = 5;
  if (s.fieldIdx == 0) return (1, 10 + s.titleBuf.cursor.col);
  if (s.fieldIdx == 1) return (2, 10 + s.tagsBuf.cursor.col);
  // body — rows: 0 title, 1 tags, 2 divider, 3 body-label, 4..
  final bodyTop = 4;
  final avail = 20; // approx, bodyRow scroll handles overflow
  final scroll = s.bodyBuf.cursor.row < avail ? 0 : s.bodyBuf.cursor.row - avail + 3;
  final visible = s.bodyBuf.cursor.row - scroll;
  return (bodyTop + visible, gutterW + s.bodyBuf.cursor.col);
}

// ---------- top bar ----------

String _topBar(AppState s, int w) {
  final left = _c(Colors.black, Colors.bgAccent) + '  ✦ SyncNote  ' + _r();
  final syncDot = _c(Colors.success, Colors.bgBase) + ' ● ' + _r();
  final ws = _c(Colors.muted, Colors.bgBase) + 'realtime · Doom One ' + _r();
  final right = syncDot + ws;
  final gap = w - _len(left) - _len(right);
  return left + (gap > 0 ? _c(Colors.fg, Colors.bgBase) + ' ' * gap : '') + right;
}

String _divider(AppState s, int w) {
  return _c(Colors.muted, Colors.bgBase) + '─' * w + _r();
}

// ---------- help overlay ----------

Frame _renderHelp(AppState s, int w, int h) {
  final rows = <String>[];
  final content = _helpText();
  rows.add(_padRight(_c(Colors.black, Colors.bgAccent) + '  ✦ SyncNote help — press ? or Esc to close  ' + _r(), w));
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '─' * w + _r(), w));
  for (final line in content) {
    if (rows.length >= h - 1) break;
    rows.add(_padRight(_c(Colors.fg, Colors.bgBase) + '  ' + line + _r(), w));
  }
  while (rows.length < h - 1) {
    rows.add(_padRight('', w));
  }
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + ' press ? or Esc to close' + _r(), w));
  return Frame(rows);
}

List<String> _helpText() => [
      '',
      sty([Colors.accent]) + 'MOTION' + sty(['0']),
      '  h j k l         move left/down/up/right',
      '  w b e           word forward / back / end',
      '  0  \$            line start / end',
      '  gg / G          top / bottom',
      '  H / L           5x up / down (or field prev/next in detail)',
      '  <tab>hjkl       jump 5 cells',
      '  Ctrl+d / Ctrl+u half-page down/up',
      '',
      sty([Colors.accent]) + 'EDITING' + sty(['0']),
      '  i / I / a / A   insert · at cursor / line start / after / line end',
      '  o / O           new line below / above',
      '  v / V           visual char / visual line',
      '  y / d / c       yank / delete / change (works with motion or visual)',
      '  yy / dd / cc    apply to whole line',
      '  x               delete char under cursor',
      '  p               paste from register',
      '  u               undo',
      '  Ctrl+r          redo',
      '',
      sty([Colors.accent]) + 'NAVIGATION' + sty(['0']),
      '  Enter           open selected note',
      '  Tab             cycle fields (in detail)',
      '  q               back / quit (with confirm)',
      '  Esc             cancel current mode',
      '',
      sty([Colors.accent]) + 'LEADER  (space)' + sty(['0']),
      '  <space>q        quit',
      '  <space>w        save note',
      '  <space>e        toggle tree pane',
      '  <space>a        AI chat',
      '  <space>bd       delete note',
      '  <space>bn       new note',
      '  <space>fg / ff  search notes',
      '  <space>r        reload from server',
      '',
      sty([Colors.accent]) + 'SEARCH / COMMAND' + sty(['0']),
      '  /               search filter',
      '  :               command line',
      '  :q :w :wq :new :del :reload :search :help',
      '',
      sty([Colors.accent]) + 'CHAT' + sty(['0']),
      '  Enter           send',
      '  Ctrl+W          toggle notes ↔ web mode',
      '  Ctrl+L          clear conversation',
      '  Esc             back to list',
    ];

// ---------- responsive layout ----------

class _Layout {
  final int tree;
  final int preview;
  const _Layout(this.tree, this.preview);
}

_Layout _computeLayout(AppState s, int w) {
  // Compute tree width
  int tree = 0;
  if (s.treeOpen && w >= 60) {
    if (w < 90) {
      tree = 16;
    } else if (w < 140) {
      tree = 22;
    } else {
      tree = (w / 5).floor().clamp(22, 32);
    }
  }
  // Preview only when wide and not editing. Give it more room than before.
  int preview = 0;
  if (s.focus != Focus.detail && s.focus != Focus.chat) {
    final remaining = w - tree;
    if (remaining >= 80) {
      // Aim for 40% of remaining, clamped to a wider range
      preview = (remaining * 0.4).floor().clamp(32, 56);
    }
  }
  // Ensure main pane has enough space
  final mainMin = 28;
  while (w - tree - preview < mainMin && preview > 0) {
    preview -= 2;
    if (preview < 28) { preview = 0; break; }
  }
  return _Layout(tree, preview);
}

// ---------- preview pane ----------

List<String> _renderPreview(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final n = s.currentUnderList();

  // Header
  final head = _c(Colors.accent, Colors.bgSurface) + ' 👁 preview ' + _r();
  rows.add(_padRight(head, w));

  if (n == null) {
    while (rows.length < bodyH) {
      rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ~' + _r(), w));
    }
    return rows;
  }

  rows.add(_padRight('', w));

  // Title
  final title = n.title.isEmpty ? '(untitled)' : n.title;
  rows.add(_padRight(_c(Colors.primary, Colors.bgBase) + '  ' + title + _r(), w));

  // Meta
  final meta = _c(Colors.muted, Colors.bgBase) + '  ' +
      _fmtDate(n.updatedAt) +
      (n.tags.isEmpty ? '' : '  ·  ' + n.tags.map((t) => '#$t').join(' ')) +
      _r();
  rows.add(_padRight(meta, w));

  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + '─' * (w - 4) + _r(), w));

  // Body — render as markdown, then wrap each rendered line to width
  final rendered = n.body.isEmpty
      ? <String>[_c(Colors.muted, Colors.bgBase) + '(no content)' + _r()]
      : renderMarkdown(n.body);

  for (final r in rendered) {
    // Word-wrap the rendered line (strip ANSI for length calc)
    final wrapped = _wrapPreserve(r, w - 4);
    for (final w2 in wrapped) {
      if (rows.length >= bodyH) break;
      rows.add(_padRight('  ' + w2, w));
    }
    if (rows.length >= bodyH) break;
  }

  while (rows.length < bodyH) {
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ~' + _r(), w));
  }
  return rows;
}

// ---------- tree pane ----------

List<String> _renderTree(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final items = s.treeItems();
  final focused = s.focus == Focus.tree;
  final headBg = focused ? Colors.bgAccent : Colors.bgSurface;
  final headFg = focused ? Colors.black : Colors.accent;
  rows.add(_padRight(_c(headFg, headBg) + ' 📁 spaces ' + _r() + _c(Colors.muted, Colors.bgBase), w) + _r());

  for (int i = 0; i < bodyH - 1; i++) {
    if (i >= items.length) {
      rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '   ~' + _r(), w));
      continue;
    }
    final it = items[i];
    final sel = i == s.treeCursor && focused;
    final active = s.treeFilter == it.key ||
        (s.treeFilter == null && it.key == '__all__');

    final bg = sel ? Colors.bgSurface : Colors.bgBase;
    final stripe = sel
        ? _c(Colors.primary, bg) + '▎'
        : _c(Colors.muted, bg) + ' ';
    final marker = active
        ? _c(Colors.success, bg) + '●'
        : _c(Colors.muted, bg) + ' ';
    final labelFg = sel ? Colors.primary : (active ? Colors.accent : Colors.fg);
    final count = it.count.toString();

    final b = StringBuffer();
    b.write(stripe);
    b.write(marker);
    b.write(_c(labelFg, bg));
    b.write(' ');
    final labelPart = _truncPad(it.label, w - count.length - 5);
    b.write(labelPart);
    b.write(_c(Colors.muted, bg));
    b.write(count);
    b.write(' ');
    b.write(_r());
    rows.add(_padRight(b.toString(), w));
  }
  return rows;
}

// ---------- notes list ----------

List<String> _renderList(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final items = s.filtered();
  final maxRows = bodyH;
  if (s.listCursor < s.listScroll) s.listScroll = s.listCursor;
  if (s.listCursor >= s.listScroll + maxRows) {
    s.listScroll = s.listCursor - maxRows + 1;
  }
  if (s.listScroll < 0) s.listScroll = 0;

  if (items.isEmpty) {
    // Empty state — nice centered art
    final blank = _padRight('', w);
    rows.add(blank);
    rows.add(blank);
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '     ✎  no notes yet' + _r(), w));
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '        press ${_c(Colors.warn, Colors.bgBase)}n${_c(Colors.muted, Colors.bgBase)} to create your first' + _r(), w));
    while (rows.length < maxRows) rows.add(blank);
    return rows;
  }

  final end = (s.listScroll + maxRows).clamp(0, items.length);
  for (int i = s.listScroll; i < end; i++) {
    final n = items[i];
    final sel = i == s.listCursor && s.focus == Focus.list;

    final title = n.title.isEmpty ? '(untitled)' : n.title;
    final tagLine = n.tags.isEmpty
        ? ''
        : n.tags.take(3).map((t) => '#$t').join(' ');
    final date = _fmtDate(n.updatedAt);

    // Subtle cursor: left border stripe + slightly darker bg (surface),
    // instead of loud full-row primary highlight.
    final bg = sel ? Colors.bgSurface : Colors.bgBase;
    final stripe = sel
        ? _c(Colors.primary, bg) + '▎'
        : _c(Colors.muted, bg) + ' ';
    final titleFg = sel ? Colors.primary : Colors.fg;

    final content = stripe +
        _c(titleFg, bg) + (sel ? ' ' : '  ') + title +
        _c(Colors.muted, bg) + '  ' + tagLine;
    final rightSeg = _c(Colors.muted, bg) + date + ' ';

    final contentPadded = _truncPad(content, w - _len(rightSeg));
    rows.add(_padRight(contentPadded + rightSeg + _r(), w));
  }
  while (rows.length < maxRows) rows.add(_padRight('', w));
  return rows;
}

// ---------- detail (editor) ----------

List<String> _renderDetail(AppState s, int w, int bodyH) {
  final rows = <String>[];
  rows.add(_fieldRow(s, 'title', s.titleBuf.text, s.fieldIdx == 0, w));
  rows.add(_fieldRow(s, 'tags ', s.tagsBuf.text, s.fieldIdx == 1, w));
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + '─' * (w - 4) + _r(), w));

  // body area
  final bodyLines = s.bodyBuf.lines;
  final avail = bodyH - 3;
  final scroll = s.bodyBuf.cursor.row < avail ? 0 : s.bodyBuf.cursor.row - avail + 3;
  for (int i = 0; i < avail; i++) {
    final li = scroll + i;
    if (li >= bodyLines.length) {
      rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '   ~' + _r(), w));
    } else {
      rows.add(_bodyLine(s, li, bodyLines[li], w));
    }
  }
  return rows;
}

String _fieldRow(AppState s, String label, String value, bool active, int w) {
  final labelStyle = active
      ? _c(Colors.black, Colors.bgWarn)
      : _c(Colors.muted, Colors.bgSurface);
  final valueStyle = _c(Colors.fg, Colors.bgBase);
  final display = value.isEmpty ? _c(Colors.muted, Colors.bgBase) + '(empty)' : value;
  return _padRight(labelStyle + ' $label ' + _r() + valueStyle + '  ' + display + _r(), w);
}

String _bodyLine(AppState s, int rowIdx, String line, int w) {
  final cursorRow = s.fieldIdx == 2 ? s.bodyBuf.cursor.row : -1;
  final isCursor = rowIdx == cursorRow;
  final bg = isCursor ? Colors.bgSurface : Colors.bgBase;

  final b = StringBuffer();
  b.write(_c(Colors.muted, bg));
  b.write(' ${(rowIdx + 1).toString().padLeft(3)} ');
  b.write(_c(Colors.fg, bg));

  final buf = s.bodyBuf;
  final maxW = w - 5;
  for (int c = 0; c < line.length && c < maxW; c++) {
    final ch = line[c];
    final selected = buf.inSelection(rowIdx, c);
    final atCursor = rowIdx == cursorRow && c == buf.cursor.col && s.fieldIdx == 2;
    final inYank = s.yankActive && _inYankRange(s, rowIdx, c);
    if (atCursor && s.mode != Mode.insert) {
      b.write(_c(Colors.black, Colors.bgPrimary) + ch + _c(Colors.fg, bg));
    } else if (inYank) {
      b.write(_c(Colors.black, Colors.bgWarn) + ch + _c(Colors.fg, bg));
    } else if (selected) {
      b.write(_c(Colors.fg, Colors.bgOverlay) + ch + _c(Colors.fg, bg));
    } else {
      b.write(ch);
    }
  }
  final pad = maxW - line.length;
  if (pad > 0) b.write(' ' * pad);
  b.write(_r());
  return _padRight(b.toString(), w);
}

// ---------- chat ----------

List<String> _renderChat(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final maxH = bodyH - 1;

  // Mode badge
  final modeBadge = s.chatUseNotes
      ? _c(Colors.black, Colors.bgSuccess) + ' 📁 NOTES ' + _r()
      : _c(Colors.black, Colors.bgPrimary) + ' 🌐 WEB ' + _r();
  final modelName = s.aiCfg?.model ?? '(no key)';
  final modelBadge = _c(Colors.black, Colors.bgAccent) + ' $modelName ' + _r();
  final srcName = switch (lastAiSource) {
    AiSource.env => 'env',
    AiSource.file => 'file',
    AiSource.none => '⚠ missing',
  };
  final srcBadge = _c(Colors.muted, Colors.bgBase) + ' key: $srcName ' + _r();
  rows.add(_padRight(' $modeBadge $modelBadge $srcBadge  ${_c(Colors.muted, Colors.bgBase)}Ctrl+W=mode  Ctrl+L=clear  Esc=back${_r()}', w));

  // Build message lines
  final lines = <_ChatLine>[];
  for (final m in s.chat) {
    final wrapped = _wrapText(m.content, w - 10);
    for (int i = 0; i < wrapped.length; i++) {
      lines.add(_ChatLine(m.role, wrapped[i], isFirst: i == 0));
    }
    lines.add(_ChatLine('spacer', ''));
  }
  if (s.chatStreaming != null) {
    final wrapped = _wrapText('${s.chatStreaming!}▍', w - 10);
    for (int i = 0; i < wrapped.length; i++) {
      lines.add(_ChatLine('assistant', wrapped[i], isFirst: i == 0));
    }
  }

  if (lines.isEmpty) {
    rows.add(_padRight('', w));
    rows.add(_padRight(_c(Colors.accent, Colors.bgBase) + '     ✨ ready when you are' + _r(), w));
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '     ' + (s.chatUseNotes ? 'ask about your notes — RAG mode' : 'general chat — no notes context') + _r(), w));
    while (rows.length < maxH) rows.add(_padRight('', w));
  } else {
    final scroll = lines.length > maxH ? lines.length - maxH : 0;
    for (int i = scroll; i < lines.length && rows.length < maxH; i++) {
      rows.add(_chatLineRender(lines[i], w));
    }
    while (rows.length < maxH) rows.add(_padRight('', w));
  }

  // composer at bottom
  final composer = _c(Colors.muted, Colors.bgBase) + ' ' +
      _c(Colors.warn, Colors.bgSurface) + ' ❯ ' + _r() +
      ' ' + s.chatInput;
  rows.add(_padRight(composer, w));
  return rows;
}

class _ChatLine {
  final String role;
  final String text;
  final bool isFirst;
  _ChatLine(this.role, this.text, {this.isFirst = false});
}

String _chatLineRender(_ChatLine l, int w) {
  if (l.role == 'spacer') return _padRight('', w);
  final isUser = l.role == 'user';
  final avatar = l.isFirst
      ? (isUser
          ? _c(Colors.black, Colors.bgPrimary) + ' 👤 ' + _r()
          : _c(Colors.black, Colors.bgAccent) + ' ✨ ' + _r())
      : '    ';
  final bg = isUser ? Colors.bgSurface : Colors.bgBase;
  final fg = Colors.fg;
  final content = ' $avatar ' + _c(fg, bg) + ' ' + l.text + ' ' + _r();
  return _padRight(content, w);
}

/// Wrap while preserving ANSI codes — width counts only visible chars.
List<String> _wrapPreserve(String s, int width) {
  final ansiRegex = RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]');
  final visible = s.replaceAll(ansiRegex, '');
  if (visible.length <= width) return [s];
  // Simple char-wise wrap; keep it readable, escape overhead is small
  final out = <String>[];
  int visCount = 0;
  final buf = StringBuffer();
  int i = 0;
  while (i < s.length) {
    if (s[i] == '\x1b') {
      final m = ansiRegex.matchAsPrefix(s, i);
      if (m != null) {
        buf.write(m.group(0));
        i = m.end;
        continue;
      }
    }
    buf.write(s[i]);
    visCount++;
    i++;
    if (visCount >= width) {
      out.add(buf.toString());
      buf.clear();
      visCount = 0;
    }
  }
  if (buf.isNotEmpty) out.add(buf.toString());
  return out;
}

List<String> _wrapText(String s, int width) {
  if (width < 10) width = 10;
  final out = <String>[];
  for (final para in s.split('\n')) {
    if (para.isEmpty) { out.add(''); continue; }
    var line = '';
    for (final word in para.split(' ')) {
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= width) {
        line += ' $word';
      } else {
        out.add(line);
        line = word;
      }
      while (line.length > width) {
        out.add(line.substring(0, width));
        line = line.substring(width);
      }
    }
    if (line.isNotEmpty) out.add(line);
  }
  return out;
}

// ---------- statusline / hint ----------

String _statusline(AppState s, int w) {
  final modeBg = switch (s.mode) {
    Mode.normal => Colors.bgPrimary,
    Mode.insert => Colors.bgSuccess,
    Mode.visual || Mode.visualLine => Colors.bgAccent,
    Mode.cmd || Mode.search => Colors.bgWarn,
    Mode.confirmQuit => Colors.bgError,
  };
  final b = StringBuffer();
  b.write(_c(Colors.black, modeBg) + '  ${s.mode.label}  ' + _r());
  final loc = s.focus == Focus.list
      ? '  ${s.listCursor + 1}/${s.filtered().length}  '
      : s.focus == Focus.detail
          ? '  ${s.activeBuf.cursor.row + 1}:${s.activeBuf.cursor.col + 1}  '
          : '  ';
  b.write(_c(Colors.fg, Colors.bgOverlay) + loc + _r());
  final context = switch (s.focus) {
    Focus.list => '  📥 inbox${s.treeFilter != null ? ' · filtered' : ''}  ',
    Focus.detail => '  📝 editing  ',
    Focus.chat => '  ✨ ai chat  ',
    Focus.tree => '  📁 tree  ',
  };
  b.write(_c(Colors.fg, Colors.bgSurface) + context + _r());

  // right side: sync + theme
  final right = _c(Colors.success, Colors.bgSurface) + '  ● ' + _r() +
      _c(Colors.muted, Colors.bgSurface) + 'sync  ' + _r() +
      _c(Colors.black, Colors.bgAccent) + '  Doom One  ' + _r();

  final leftLen = _len(b.toString());
  final rightLen = _len(right);
  final gap = w - leftLen - rightLen;
  final pad = gap > 0 ? _c(Colors.muted, Colors.bgSurface) + ' ' * gap + _r() : '';
  return b.toString() + pad + right;
}

String _hintline(AppState s, int w) {
  String txt;
  if (s.mode == Mode.confirmQuit) {
    txt = _c(Colors.black, Colors.bgWarn) + ' quit SyncNote? (y/N) ' + _r();
    return _padRight(txt, w);
  }
  if (s.toast.isNotEmpty) {
    final color = s.toastErr ? Colors.error : Colors.success;
    txt = _c(color, Colors.bgBase) + ' ${s.toast} ' + _r();
    return _padRight(txt, w);
  }
  if (s.mode == Mode.search) {
    return _padRight(_c(Colors.warn, Colors.bgBase) + ' / ' + s.searchInput + _r(), w);
  }
  if (s.mode == Mode.cmd) {
    return _padRight(_c(Colors.warn, Colors.bgBase) + ' : ' + s.cmdInput + _r(), w);
  }
  final hint = switch (s.focus) {
    Focus.list => ' hjkl move · Enter open · n new · dd delete · yy yank · <space>e tree · <space>a AI · / search · q quit',
    Focus.detail => ' hjkl move · i insert · v visual · y yank · Tab field · Ctrl+S save · q back',
    Focus.chat => ' Enter send · Ctrl+W notes/web · Ctrl+L clear · Esc back',
    Focus.tree => ' j/k move · Enter/l apply · h/q back · <space>e close',
  };
  return _padRight(_c(Colors.muted, Colors.bgBase) + hint + _r(), w);
}

// ---------- helpers ----------

int _len(String s) => s.replaceAll(RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]'), '').length;

String _padRight(String s, int w) {
  final len = _len(s);
  if (len >= w) return _truncPad(s, w);
  return s + ' ' * (w - len);
}

String _truncPad(String s, int w) {
  if (w < 4) return '';
  final len = _len(s);
  if (len > w) return s.substring(0, (w - 1).clamp(0, s.length)) + '…';
  return s + ' ' * (w - len);
}

bool _inYankRange(AppState s, int row, int col) {
  final r1 = s.yankStartRow!;
  final c1 = s.yankStartCol!;
  final r2 = s.yankEndRow!;
  final c2 = s.yankEndCol!;
  if (row < r1 || row > r2) return false;
  if (row == r1 && row == r2) return col >= c1 && col <= c2;
  if (row == r1) return col >= c1;
  if (row == r2) return col <= c2;
  return true;
}

String _fmtDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
