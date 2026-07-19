// Premium render — restraint over decoration.
//
// Design principles:
// - One hero color at a time (Primary on focused pane, muted everywhere else)
// - No emoji chrome, use typographic markers (—  •  ─  ┊)
// - Generous vertical spacing between list rows (2 rows per item)
// - Statusline segments separated by muted vertical bars, not colored fills
// - Preview label pattern: uppercase muted heading + content in fg
// - Bold weight for hierarchy since we can't change font size

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

// -------- palette shortcuts --------
String _c(String fg, String bg) => sty([fg, bg]);
String _r() => sty(['0']);
String _b() => sty(['1']); // bold
String _dim() => sty(['2']); // dim

Frame renderFrame(AppState s, int w, int h) {
  final rows = <String>[];

  if (s.shouldShowSplash) return _renderSplash(s, w, h);
  if (s.showHelp) return _renderHelp(s, w, h);

  // TOP BAR (2 rows: brand + divider)
  rows.add(_brandBar(s, w));
  rows.add(_thinRule(w));

  // Chrome: brand(1) + rule(1) + rule(1) + statusline(1) = 4 rows.
  // bodyH = h - 4 so total rows fills terminal exactly and statusline
  // lands on the last row (h-1), where the cursor calc points.
  final bodyH = h - 4;
  final layout = _computeLayout(s, w);
  final treeW = layout.tree;
  final previewW = layout.preview;
  final mainW = w - treeW - previewW;

  if (s.focus == Focus.chat) {
    rows.addAll(_renderChat(s, w, bodyH));
  } else {
    // Reserve 1 col for each active divider.
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
    final divider = _c(Colors.muted, Colors.bgBase) + '┊' + _r();
    for (int i = 0; i < bodyH; i++) {
      final t = i < treeLines.length ? treeLines[i] : '';
      final m = i < mainLines.length ? mainLines[i] : '';
      final p = i < previewLines.length ? previewLines[i] : '';
      final tDiv = treeW > 0 ? divider : '';
      final pDiv = previewW > 0 ? divider : '';
      rows.add(t + tDiv + m + pDiv + p);
    }
  }

  rows.add(_thinRule(w));
  rows.add(_statusline(s, w));

  int? cr, cc;
  if (s.focus == Focus.chat) {
    cr = h - 3;
    cc = 3 + s.chatCursor;
  } else if (s.mode == Mode.search) {
    cr = h - 1;
    cc = 3 + s.searchCursor;
  } else if (s.mode == Mode.cmd) {
    cr = h - 1;
    cc = 3 + s.cmdCursor;
  } else if (s.focus == Focus.detail) {
    final pos = _detailCursorPosition(s, mainW);
    if (pos != null) {
      cr = 2 + pos.$1;
      cc = treeW + (treeW > 0 ? 1 : 0) + pos.$2;
    }
  } else if (s.focus == Focus.list || s.focus == Focus.tree) {
    // Rely on visual stripe indicator; hide terminal cursor.
    cr = null;
    cc = null;
  }
  return Frame(rows, cursorRow: cr, cursorCol: cc);
}

// Each list item takes 2 rows (title + meta). +2 for section header rows.
int _visualListRow(int idx) => 2 + idx * 2;

(int, int)? _detailCursorPosition(AppState s, int mainW) {
  final gutterW = 5;
  if (s.fieldIdx == 0) return (2, 10 + s.titleBuf.cursor.col);
  if (s.fieldIdx == 1) return (3, 10 + s.tagsBuf.cursor.col);
  final bodyTop = 5;
  final avail = 20;
  final scroll = s.bodyBuf.cursor.row < avail ? 0 : s.bodyBuf.cursor.row - avail + 3;
  final visible = s.bodyBuf.cursor.row - scroll;
  return (bodyTop + visible, gutterW + s.bodyBuf.cursor.col);
}

// -------- top bar --------

String _brandBar(AppState s, int w) {
  // Colored logo dot + brand + subtle count
  final count = s.notes.length;
  final logo = _c(Colors.accent, Colors.bgBase) + '●' + _r() +
      _c(Colors.primary, Colors.bgBase) + '●' + _r();
  final brand = _c(Colors.fg, Colors.bgBase) + _b() + '  syncnote' + _r();
  final countBadge = count > 0
      ? _c(Colors.muted, Colors.bgBase) + '   ' + _c(Colors.accent, Colors.bgBase) + count.toString() + _r() +
        _c(Colors.muted, Colors.bgBase) + ' notes' + _r()
      : '';
  final left = '  ' + logo + brand + countBadge;

  final syncOK = _c(Colors.success, Colors.bgBase) + '●' + _r();
  final right = syncOK + _c(Colors.muted, Colors.bgBase) + '  synced  ' + _r();
  final gap = w - _len(left) - _len(right);
  return left + (gap > 0 ? _c(Colors.fg, Colors.bgBase) + ' ' * gap : '') + right;
}

String _thinRule(int w) => _c(Colors.muted, Colors.bgBase) + '─' * w + _r();

// -------- help --------

Frame _renderSplash(AppState s, int w, int h) {
  final rows = <String>[];
  final art = _asciiArt();
  final artW = art.map((l) => l.length).reduce((a, b) => a > b ? a : b);
  final artStart = ((h - art.length - 6) ~/ 2).clamp(0, h);

  for (int i = 0; i < artStart; i++) {
    rows.add(_padRight('', w));
  }
  final leftPad = ((w - artW) ~/ 2).clamp(0, w);
  final pad = ' ' * leftPad;
  for (final line in art) {
    rows.add(_padRight(pad + _c(Colors.primary, Colors.bgBase) + line + _r(), w));
  }
  rows.add(_padRight('', w));
  rows.add(_padRight('', w));

  const tagline = 'notes  ·  sync  ·  ai';
  final tagPad = ' ' * ((w - tagline.length) ~/ 2).clamp(0, w);
  rows.add(_padRight(tagPad + _c(Colors.muted, Colors.bgBase) + _b() + tagline + _r(), w));
  rows.add(_padRight('', w));

  // Loading dots animation
  final dots = ((DateTime.now().millisecondsSinceEpoch ~/ 200) % 4);
  final dotStr = List.filled(dots, '·').join(' ') + List.filled(3 - dots, ' ').join(' ');
  final dotPad = ' ' * ((w - 7) ~/ 2).clamp(0, w);
  rows.add(_padRight(dotPad + _c(Colors.accent, Colors.bgBase) + '  $dotStr  ' + _r(), w));

  while (rows.length < h - 1) rows.add(_padRight('', w));
  const hint = 'press any key to continue';
  final hintPad = ' ' * ((w - hint.length) ~/ 2).clamp(0, w);
  rows.add(_padRight(hintPad + _c(Colors.muted, Colors.bgBase) + hint + _r(), w));
  return Frame(rows);
}

/// Simple ASCII wordmark — bold letters with negative space.
List<String> _asciiArt() {
  return [
    '  ┌─┐┬ ┬┌┐┌┌─┐┌┐┌┌─┐┌┬┐┌─┐',
    '  └─┐└┬┘││││   ││││ │ │ ├┤ ',
    '  └─┘ ┴ ┘└┘└─┘┘└┘└─┘ ┴ └─┘',
  ];
}

Frame _renderHelp(AppState s, int w, int h) {
  final rows = <String>[];
  rows.add(_c(Colors.fg, Colors.bgBase) + '  ' + _b() + 'help' + _r() +
      _c(Colors.muted, Colors.bgBase) + '   press ? or Esc to close' + _r());
  rows.add(_thinRule(w));
  for (final line in _helpText()) {
    if (rows.length >= h - 1) break;
    rows.add(_padRight(_c(Colors.fg, Colors.bgBase) + '  ' + line + _r(), w));
  }
  while (rows.length < h - 1) rows.add(_padRight('', w));
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ? / Esc to close' + _r(), w));
  return Frame(rows);
}

List<String> _helpText() => [
      '',
      _b() + 'MOTION',
      '  h j k l           move',
      '  w b e             word forward / back / end',
      r'  0  $              line start / end',
      '  gg / G            top / bottom',
      '  H / L             jump 5 · or prev/next field',
      '  <tab>hjkl         jump 5 cells',
      '  Ctrl+d / Ctrl+u   half-page down/up',
      '',
      _b() + 'EDIT',
      '  i I a A           insert · at / start / after / end',
      '  o O               new line below / above',
      '  v V               visual char / visual line',
      '  y d c             yank / delete / change',
      '  yy dd cc          apply to whole line',
      '  x                 delete char',
      '  p                 paste',
      '  u                 undo',
      '  Ctrl+r            redo',
      '',
      _b() + 'NAVIGATE',
      '  Enter             open note',
      '  Tab               cycle fields (in detail)',
      '  q                 back / quit',
      '  Esc               cancel',
      '',
      _b() + 'LEADER (space)',
      '  <space>q          quit',
      '  <space>w          save',
      '  <space>e          toggle tree',
      '  <space>a          AI chat',
      '  <space>bd         delete note',
      '  <space>bn         new note',
      '  <space>fg         search',
      '',
      _b() + 'COMMANDS',
      '  /                 search',
      '  :q :w :new :del :reload :help',
    ];

// -------- layout --------

class _Layout {
  final int tree;
  final int preview;
  const _Layout(this.tree, this.preview);
}

_Layout _computeLayout(AppState s, int w) {
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
  int preview = 0;
  if (s.focus != Focus.detail && s.focus != Focus.chat) {
    final remaining = w - tree;
    if (remaining >= 80) {
      preview = (remaining * 0.4).floor().clamp(32, 56);
    }
  }
  final mainMin = 28;
  while (w - tree - preview < mainMin && preview > 0) {
    preview -= 2;
    if (preview < 28) { preview = 0; break; }
  }
  return _Layout(tree, preview);
}

// -------- preview pane --------

List<String> _renderPreview(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final n = s.currentUnderList();

  // Section label — small muted heading
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  PREVIEW' + _r(), w));
  rows.add(_padRight('', w));

  if (n == null) {
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  select a note to preview' + _r(), w));
    while (rows.length < bodyH) rows.add(_padRight('', w));
    return rows;
  }

  final title = n.title.isEmpty ? '(untitled)' : n.title;
  rows.add(_padRight(_c(Colors.fg, Colors.bgBase) + _b() + '  $title' + _r(), w));
  rows.add(_padRight('', w));

  // Meta
  final tags = n.tags.isEmpty ? '' : '   ' + n.tags.map((t) => '#$t').join('  ');
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + _fmtDate(n.updatedAt) + tags + _r(), w));
  rows.add(_padRight('', w));
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + '─' * (w - 4) + _r(), w));
  rows.add(_padRight('', w));

  final rendered = n.body.isEmpty
      ? <String>[_c(Colors.muted, Colors.bgBase) + '(no content)' + _r()]
      : renderMarkdown(n.body);

  for (final r in rendered) {
    final wrapped = _wrapPreserve(r, w - 4);
    for (final w2 in wrapped) {
      if (rows.length >= bodyH) break;
      rows.add(_padRight('  ' + w2, w));
    }
    if (rows.length >= bodyH) break;
  }
  while (rows.length < bodyH) rows.add(_padRight('', w));
  return rows;
}

// -------- tree pane --------

List<String> _renderTree(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final items = s.treeItems();
  final focused = s.focus == Focus.tree;

  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  SPACES' + _r(), w));

  for (int i = 0; i < bodyH - 1; i++) {
    if (i >= items.length) {
      rows.add(_padRight('', w));
      continue;
    }
    final it = items[i];
    final sel = i == s.treeCursor && focused;
    final active = s.treeFilter == it.key ||
        (s.treeFilter == null && it.key == '__all__');

    final b = StringBuffer();
    // Left stripe cursor — only when tree focused + selected
    if (sel) {
      b.write(_c(Colors.primary, Colors.bgBase) + '▎' + _r());
    } else {
      b.write(_c(Colors.fg, Colors.bgBase) + ' ' + _r());
    }
    // Folder / tag icon
    final glyph = it.key == '__all__' ? '◉' : (it.key == '__untagged__' ? '○' : '▸');
    b.write(' ');
    if (active) {
      b.write(_c(Colors.accent, Colors.bgBase) + glyph + ' ' + _r());
      b.write(_c(Colors.primary, Colors.bgBase) + _b() + it.label + _r());
    } else {
      b.write(_c(Colors.muted, Colors.bgBase) + glyph + ' ' + it.label + _r());
    }
    // Count right-aligned
    final count = it.count.toString();
    final padWidth = w - _len(b.toString()) - _len(count) - 3;
    if (padWidth > 0) {
      b.write(' ' * padWidth);
    }
    b.write(_c(Colors.muted, Colors.bgBase) + count + '  ' + _r());
    rows.add(_padRight(b.toString(), w));
  }
  return rows;
}

// -------- notes list --------

List<String> _renderList(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final items = s.filtered();
  final label = s.treeFilter == null
      ? 'INBOX'
      : (s.treeFilter == '__untagged__' ? 'UNTAGGED' : '#${s.treeFilter}'.toUpperCase());
  final countStr = '${items.length}';
  final header = _c(Colors.muted, Colors.bgBase) + '  ' + label +
      '   ' + _c(Colors.accent, Colors.bgBase) + countStr + _r();
  rows.add(_padRight(header, w));
  rows.add(_padRight('', w));
  // Header takes 2 rows; each item = 2 rows (title + meta)
  final rowsPerItem = 2;
  final availableForItems = bodyH - 2;
  final maxItems = (availableForItems / rowsPerItem).floor();

  if (s.listCursor < s.listScroll) s.listScroll = s.listCursor;
  if (s.listCursor >= s.listScroll + maxItems) {
    s.listScroll = s.listCursor - maxItems + 1;
  }
  if (s.listScroll < 0) s.listScroll = 0;

  if (items.isEmpty) {
    rows.add(_padRight('', w));
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  no notes yet' + _r(), w));
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  press ' + _c(Colors.warn, Colors.bgBase) + _b() + 'n' + _r() + _c(Colors.muted, Colors.bgBase) + ' to create' + _r(), w));
    while (rows.length < bodyH) rows.add(_padRight('', w));
    return rows;
  }

  final end = (s.listScroll + maxItems).clamp(0, items.length);
  for (int i = s.listScroll; i < end; i++) {
    final n = items[i];
    final sel = i == s.listCursor && s.focus == Focus.list;

    final title = n.title.isEmpty ? '(untitled)' : n.title;
    final tags = n.tags.isEmpty ? '' : n.tags.take(3).map((t) => '#$t').join('  ');
    final date = _fmtDate(n.updatedAt);

    // Row 1: title
    final b1 = StringBuffer();
    if (sel) {
      b1.write(_c(Colors.primary, Colors.bgBase) + '▎' + _r());
    } else {
      b1.write(_c(Colors.fg, Colors.bgBase) + ' ' + _r());
    }
    b1.write(' ');
    if (sel) {
      b1.write(_c(Colors.primary, Colors.bgBase) + _b() + title + _r());
    } else {
      b1.write(_c(Colors.fg, Colors.bgBase) + title + _r());
    }
    rows.add(_padRight(b1.toString(), w));

    // Row 2: meta (date + tags)
    final b2 = StringBuffer();
    b2.write(_c(Colors.muted, Colors.bgBase) + '    ' + date);
    if (tags.isNotEmpty) {
      b2.write('   ' + tags);
    }
    b2.write(_r());
    rows.add(_padRight(b2.toString(), w));
  }
  while (rows.length < bodyH) rows.add(_padRight('', w));
  return rows;
}

// -------- detail (editor) --------

List<String> _renderDetail(AppState s, int w, int bodyH) {
  final rows = <String>[];
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  EDITOR' + _r(), w));
  rows.add(_padRight('', w));
  rows.add(_fieldRow(s, 'title', s.titleBuf.text, s.fieldIdx == 0, w));
  rows.add(_fieldRow(s, 'tags', s.tagsBuf.text, s.fieldIdx == 1, w));
  rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + '─' * (w - 4) + _r(), w));

  final bodyLines = s.bodyBuf.lines;
  final avail = bodyH - 5;
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
  final b = StringBuffer();
  b.write(_c(Colors.muted, Colors.bgBase) + '  ');
  if (active) {
    b.write(_c(Colors.primary, Colors.bgBase) + _b() + label + _r());
  } else {
    b.write(_c(Colors.muted, Colors.bgBase) + label + _r());
  }
  b.write('    ');
  final display = value.isEmpty
      ? _c(Colors.muted, Colors.bgBase) + '—' + _r()
      : _c(Colors.fg, Colors.bgBase) + value + _r();
  b.write(display);
  return _padRight(b.toString(), w);
}

String _bodyLine(AppState s, int rowIdx, String line, int w) {
  final cursorRow = s.fieldIdx == 2 ? s.bodyBuf.cursor.row : -1;
  final isCursor = rowIdx == cursorRow;

  final b = StringBuffer();
  if (isCursor) {
    b.write(_c(Colors.primary, Colors.bgBase) + '▎' + _r());
  } else {
    b.write(_c(Colors.fg, Colors.bgBase) + ' ' + _r());
  }
  b.write(_c(Colors.muted, Colors.bgBase) + ' ${(rowIdx + 1).toString().padLeft(3)} ' + _r());
  b.write(_c(Colors.fg, Colors.bgBase));

  final buf = s.bodyBuf;
  final maxW = w - 6;
  for (int c = 0; c < line.length && c < maxW; c++) {
    final ch = line[c];
    final selected = buf.inSelection(rowIdx, c);
    final atCursor = rowIdx == cursorRow && c == buf.cursor.col && s.fieldIdx == 2;
    final inYank = s.yankActive && _inYankRange(s, rowIdx, c);
    if (atCursor && s.mode != Mode.insert) {
      b.write(_c(Colors.black, Colors.bgPrimary) + ch + _c(Colors.fg, Colors.bgBase));
    } else if (inYank) {
      b.write(_c(Colors.black, Colors.bgWarn) + ch + _c(Colors.fg, Colors.bgBase));
    } else if (selected) {
      b.write(_c(Colors.fg, Colors.bgOverlay) + ch + _c(Colors.fg, Colors.bgBase));
    } else {
      b.write(ch);
    }
  }
  final pad = maxW - line.length;
  if (pad > 0) b.write(' ' * pad);
  b.write(_r());
  return _padRight(b.toString(), w);
}

// -------- chat --------

List<String> _renderChat(AppState s, int w, int bodyH) {
  final rows = <String>[];
  final maxH = bodyH - 1;

  final modeName = s.chatUseNotes ? 'notes' : 'web';
  final modelName = s.aiCfg?.model ?? '(no key)';
  final srcName = switch (lastAiSource) {
    AiSource.env => 'env',
    AiSource.file => 'file',
    AiSource.none => '⚠ missing',
  };
  final head = _c(Colors.muted, Colors.bgBase) + '  CHAT' + _r() +
      _c(Colors.muted, Colors.bgBase) + '   mode ' + _r() + _c(Colors.fg, Colors.bgBase) + modeName + _r() +
      _c(Colors.muted, Colors.bgBase) + '   model ' + _r() + _c(Colors.fg, Colors.bgBase) + modelName + _r() +
      _c(Colors.muted, Colors.bgBase) + '   key ' + _r() + _c(Colors.fg, Colors.bgBase) + srcName + _r();
  rows.add(_padRight(head, w));

  final lines = <_ChatLine>[];
  for (final m in s.chat) {
    final wrapped = _wrapText(m.content, w - 12);
    for (int i = 0; i < wrapped.length; i++) {
      lines.add(_ChatLine(m.role, wrapped[i], isFirst: i == 0));
    }
    lines.add(_ChatLine('spacer', ''));
  }
  if (s.chatStreaming != null) {
    final wrapped = _wrapText('${s.chatStreaming!}▍', w - 12);
    for (int i = 0; i < wrapped.length; i++) {
      lines.add(_ChatLine('assistant', wrapped[i], isFirst: i == 0));
    }
  }

  if (lines.isEmpty) {
    rows.add(_padRight('', w));
    rows.add(_padRight(_c(Colors.fg, Colors.bgBase) + _b() + '  ready when you are' + _r(), w));
    rows.add(_padRight(_c(Colors.muted, Colors.bgBase) + '  ' + (s.chatUseNotes ? 'ask about your notes' : 'general chat mode') + _r(), w));
    while (rows.length < maxH) rows.add(_padRight('', w));
  } else {
    final scroll = lines.length > maxH ? lines.length - maxH : 0;
    for (int i = scroll; i < lines.length && rows.length < maxH; i++) {
      rows.add(_chatLineRender(lines[i], w));
    }
    while (rows.length < maxH) rows.add(_padRight('', w));
  }

  final prompt = _c(Colors.warn, Colors.bgBase) + '  ›' + _r() + ' ' + s.chatInput;
  rows.add(_padRight(prompt, w));
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
  final label = l.isFirst
      ? (isUser
          ? _c(Colors.primary, Colors.bgBase) + '  you  ' + _r()
          : _c(Colors.accent, Colors.bgBase) + '  ai   ' + _r())
      : '       ';
  final content = label + _c(Colors.fg, Colors.bgBase) + l.text + _r();
  return _padRight(content, w);
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

/// Wrap while preserving ANSI codes — width counts only visible chars.
List<String> _wrapPreserve(String s, int width) {
  final ansiRegex = RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]');
  final visible = s.replaceAll(ansiRegex, '');
  if (visible.length <= width) return [s];
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

// -------- statusline + hint --------

String _statusline(AppState s, int w) {
  // Confirm-quit or toast dominates.
  if (s.mode == Mode.confirmQuit) {
    return _padRight(_c(Colors.error, Colors.bgBase) + '  quit? (y/N)' + _r(), w);
  }
  if (s.toast.isNotEmpty) {
    final color = s.toastErr ? Colors.error : Colors.success;
    return _padRight(_c(color, Colors.bgBase) + '  ' + s.toast + _r(), w);
  }
  if (s.mode == Mode.search) {
    return _padRight(_c(Colors.warn, Colors.bgBase) + '  /' + s.searchInput + _r(), w);
  }
  if (s.mode == Mode.cmd) {
    return _padRight(_c(Colors.warn, Colors.bgBase) + '  :' + s.cmdInput + _r(), w);
  }

  // Normal: mode · context · pos · muted hints
  final modeLabel = s.mode.label.toLowerCase();
  final modeColor = switch (s.mode) {
    Mode.insert => Colors.success,
    Mode.visual || Mode.visualLine => Colors.accent,
    Mode.cmd || Mode.search => Colors.warn,
    _ => Colors.primary,
  };
  final ctx = switch (s.focus) {
    Focus.list => 'inbox',
    Focus.detail => 'editor',
    Focus.chat => 'chat',
    Focus.tree => 'tree',
  };
  final pos = s.focus == Focus.list
      ? '${s.listCursor + 1}/${s.filtered().length}'
      : s.focus == Focus.detail
          ? '${s.activeBuf.cursor.row + 1}:${s.activeBuf.cursor.col + 1}'
          : '';
  final left = '  ' +
      _c(modeColor, Colors.bgBase) + _b() + modeLabel + _r() +
      _c(Colors.muted, Colors.bgBase) + '   ' + ctx +
      (pos.isNotEmpty ? '   ' + _c(Colors.fg, Colors.bgBase) + pos : '') + _r();

  final hint = _c(Colors.muted, Colors.bgBase) + _hintText(s) + '  ' + _r();
  final gap = w - _len(left) - _len(hint);
  return left + (gap > 0 ? _c(Colors.fg, Colors.bgBase) + ' ' * gap : '') + hint;
}

String _hintText(AppState s) => switch (s.focus) {
      Focus.list => 'hjkl · n new · dd del · yy yank · / search · ? help · q quit',
      Focus.detail => 'i insert · v visual · y yank · Tab field · q back',
      Focus.chat => 'Ctrl+W mode · Ctrl+L clear · Esc back',
      Focus.tree => 'j/k · Enter apply · h/q back',
    };

// -------- helpers --------

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
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
