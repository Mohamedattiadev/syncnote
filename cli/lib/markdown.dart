// Minimal markdown → ANSI renderer for the preview pane.
// Supported:
//   # H1  → accent + bold
//   ## H2 → primary + bold
//   ### H3 → accent
//   - [ ] task    → ☐ task
//   - [x] task    → ☑ ~~task~~
//   - item        → • item
//   > quote       → left accent bar
//   **bold**      → bold
//   _italic_      → italic
//   `code`        → warning fg on base bg

import 'ansi.dart';

/// Return a list of already-ANSI-styled lines (no width wrapping).
List<String> renderMarkdown(String source) {
  final out = <String>[];
  bool inCode = false;
  String? codeLang;
  for (final raw in source.split('\n')) {
    // Fenced code blocks
    final fenceMatch = RegExp(r'^```(\w*)').firstMatch(raw);
    if (fenceMatch != null) {
      if (inCode) {
        // Closing fence
        inCode = false;
        codeLang = null;
        out.add(sty([Colors.muted]) + '└' + '─' * 20 + sty(['0']));
      } else {
        // Opening fence
        inCode = true;
        codeLang = fenceMatch.group(1);
        final label = codeLang!.isEmpty ? 'code' : codeLang;
        out.add(sty([Colors.muted]) + '┌ ' + sty([Colors.accent, '1']) + label + sty(['0']));
      }
      continue;
    }
    if (inCode) {
      out.add(sty([Colors.warn, Colors.bgSurface]) + '  ' + raw + sty(['0']));
      continue;
    }
    out.add(_renderLine(raw));
  }
  return out;
}

String _renderLine(String line) {
  // Task checkbox — bigger, high-contrast glyphs
  final task = RegExp(r'^(\s*)-\s+\[( |x|X)\]\s+(.*)$').firstMatch(line);
  if (task != null) {
    final indent = task.group(1) ?? '';
    final done = (task.group(2) ?? ' ').toLowerCase() == 'x';
    final rest = _inline(task.group(3) ?? '');
    if (done) {
      return '$indent${sty([Colors.success, '1'])}[✓]${sty(['0'])} '
          '${sty([Colors.muted])}$rest${sty(['0'])}';
    }
    return '$indent${sty([Colors.warn, '1'])}[ ]${sty(['0'])} '
        '${sty([Colors.fg])}$rest${sty(['0'])}';
  }

  // Bullet list
  final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(line);
  if (bullet != null) {
    final indent = bullet.group(1) ?? '';
    final rest = _inline(bullet.group(2) ?? '');
    return '$indent${sty([Colors.accent])}•${sty(['0'])} $rest';
  }

  // Numbered list
  final num = RegExp(r'^(\s*)(\d+)\.\s+(.*)$').firstMatch(line);
  if (num != null) {
    final indent = num.group(1) ?? '';
    final n = num.group(2) ?? '';
    final rest = _inline(num.group(3) ?? '');
    return '$indent${sty([Colors.muted])}$n.${sty(['0'])} $rest';
  }

  // Headings
  final h = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
  if (h != null) {
    final level = (h.group(1) ?? '#').length;
    final rest = h.group(2) ?? '';
    final color = level == 1
        ? Colors.accent
        : (level == 2 ? Colors.primary : Colors.warn);
    return '${sty([color, '1'])}${'#' * level} $rest${sty(['0'])}';
  }

  // Blockquote
  final q = RegExp(r'^>\s*(.*)$').firstMatch(line);
  if (q != null) {
    final rest = _inline(q.group(1) ?? '');
    return '${sty([Colors.accent])}▎${sty([Colors.muted])} $rest${sty(['0'])}';
  }

  // Horizontal rule
  if (RegExp(r'^\s*(-{3,}|_{3,}|\*{3,})\s*$').hasMatch(line)) {
    return sty([Colors.muted]) + '─' * 40 + sty(['0']);
  }

  // Plain paragraph — use brighter fg
  return sty([Colors.fg]) + _inline(line) + sty(['0']);
}

/// Inline markdown: **bold**, _italic_, `code`, [link](url).
String _inline(String s) {
  var t = s;
  // code
  t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) {
    return sty([Colors.warn, Colors.bgSurface]) + ' ${m.group(1)} ' + sty(['0']);
  });
  // bold
  t = t.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) {
    return sty([Colors.fg, '1']) + (m.group(1) ?? '') + sty(['0']);
  });
  // italic (avoid capturing snake_case)
  t = t.replaceAllMapped(RegExp(r'(?<![a-zA-Z0-9])_([^_]+)_(?![a-zA-Z0-9])'), (m) {
    return sty([Colors.fg, '3']) + (m.group(1) ?? '') + sty(['0']);
  });
  // links [text](url)
  t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) {
    final text = m.group(1) ?? '';
    return sty([Colors.primary, '4']) + text + sty(['0']);
  });
  return t;
}
