// ANSI escape helpers + Doom One palette.

import 'dart:io';

const esc = '\x1b';
const csi = '$esc[';

void aw(String s) => stdout.write(s);

void enterAlt() => aw('${csi}?1049h${csi}?25l');
void exitAlt() => aw('${csi}?1049l${csi}?25h');
void clear() => aw('${csi}2J${csi}H');
void moveTo(int row, int col) => aw('${csi}${row + 1};${col + 1}H');
void hideCursor() => aw('${csi}?25l');
void showCursor() => aw('${csi}?25h');
void resetSgr() => aw('${csi}0m');

/// Full terminal reset — used on exit to guarantee shell prompt returns cleanly.
void terminalReset() {
  try {
    aw('${csi}0m');          // reset SGR
    aw('${csi}?25h');        // show cursor
    aw('$esc[0 q');          // reset cursor shape
    aw('${csi}?1000l');      // disable mouse
    aw('${csi}?1002l');      // disable button mouse
    aw('${csi}?1003l');      // disable any mouse
    aw('${csi}?1006l');      // disable SGR mouse
    aw('${csi}?2004l');      // disable bracketed paste
    aw('${csi}?1049l');      // exit alt screen (last — restore main buffer)
    aw('$esc[!p');           // soft reset
  } catch (_) {}
  try { stdout.flush(); } catch (_) {}
}

/// DECSCUSR — set cursor shape. 1=blink block, 2=steady block, 3=blink underline,
/// 4=steady underline, 5=blink bar, 6=steady bar.
void cursorBlock() => aw('$esc[2 q');
void cursorBar() => aw('$esc[5 q');
void cursorDefault() => aw('$esc[0 q');

// Doom One (matches user's nvim colorscheme).
class Colors {
  static const fg = '38;2;187;194;207';
  static const muted = '38;2;91;97;104';
  static const primary = '38;2;81;175;239';
  static const accent = '38;2;198;120;221';
  static const success = '38;2;152;190;101';
  static const warn = '38;2;236;190;123';
  static const error = '38;2;255;108;107';
  static const bgBase = '48;2;40;44;52';
  static const bgSurface = '48;2;33;36;43';
  static const bgOverlay = '48;2;63;68;73';
  static const bgPrimary = '48;2;81;175;239';
  static const bgAccent = '48;2;198;120;221';
  static const bgSuccess = '48;2;152;190;101';
  static const bgWarn = '48;2;236;190;123';
  static const bgError = '48;2;255;108;107';
  static const black = '38;2;40;44;52';
}

String sty(List<String> codes) => '${csi}${codes.join(';')}m';

int termCols() {
  try {
    return stdout.terminalColumns;
  } catch (_) {
    return 80;
  }
}

int termRows() {
  try {
    return stdout.terminalLines;
  } catch (_) {
    return 24;
  }
}
