// Raw stdin byte parser → structured Key events.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class Key {
  /// Name of a special key: 'esc', 'enter', 'tab', 'backspace', 'up', 'down',
  /// 'left', 'right', 'home', 'end', 'delete', 'pageup', 'pagedown',
  /// `ctrl+<letter>`, `alt+<letter>`, 'shift+tab', or 'rune' for printable char.
  final String name;

  /// If [name] is 'rune', the actual printable char.
  final String? rune;

  const Key(this.name, [this.rune]);

  @override
  String toString() => rune ?? name;

  bool get isRune => name == 'rune';
}

class KeyReader {
  final _sc = StreamController<Key>.broadcast();
  StreamSubscription? _sub;
  final _buf = <int>[];

  Stream<Key> get stream => _sc.stream;

  bool _sttyPatched = false;

  void start() {
    stdin.echoMode = false;
    stdin.lineMode = false;
    // Dart's lineMode=false re-applies termios and re-enables ICRNL,
    // which translates CR→LF and makes Enter indistinguishable from Ctrl+J.
    // Disable ICRNL AFTER lineMode=false so the bit sticks.
    try {
      final r = Process.runSync('stty', ['-F', '/dev/tty', '-icrnl']);
      _sttyPatched = r.exitCode == 0;
    } catch (_) {}
    _sub = stdin.listen(_onBytes);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {}
    if (_sttyPatched) {
      try { Process.runSync('stty', ['-F', '/dev/tty', 'icrnl']); } catch (_) {}
      _sttyPatched = false;
    }
    if (!_sc.isClosed) await _sc.close();
  }

  void _onBytes(List<int> data) {
    _buf.addAll(data);
    while (_buf.isNotEmpty) {
      final k = _parse();
      if (k == null) break;
      _sc.add(k);
    }
  }

  Key? _parse() {
    if (_buf.isEmpty) return null;
    final b = _buf[0];

    if (b == 0x1b) {
      if (_buf.length == 1) {
        _buf.removeAt(0);
        return const Key('esc');
      }
      final b1 = _buf[1];
      if (b1 != 0x5b && b1 != 0x4f) {
        // Alt+char (ESC + char)
        _buf.removeRange(0, 2);
        return Key('alt+${String.fromCharCode(b1)}');
      }
      // CSI: ESC [ or ESC O
      int i = 2;
      while (i < _buf.length && !(_buf[i] >= 0x40 && _buf[i] <= 0x7e)) {
        i++;
      }
      if (i >= _buf.length) return null;
      final seq = String.fromCharCodes(_buf.sublist(2, i + 1));
      _buf.removeRange(0, i + 1);
      switch (seq) {
        case 'A': return const Key('up');
        case 'B': return const Key('down');
        case 'C': return const Key('right');
        case 'D': return const Key('left');
        case 'H': return const Key('home');
        case 'F': return const Key('end');
        case 'Z': return const Key('shift+tab');
        case '3~': return const Key('delete');
        case '5~': return const Key('pageup');
        case '6~': return const Key('pagedown');
      }
      return Key('csi:$seq');
    }

    // Enter is CR (0x0d) once ICRNL is disabled (see syncnote.dart startup).
    // LF (0x0a) falls through to the generic ctrl+letter branch → ctrl+j.
    if (b == 0x0d) {
      _buf.removeAt(0);
      return const Key('enter');
    }
    if (b == 0x09) {
      _buf.removeAt(0);
      return const Key('tab');
    }
    if (b == 0x7f || b == 0x08) {
      _buf.removeAt(0);
      return const Key('backspace');
    }
    if (b == 0x20) {
      _buf.removeAt(0);
      return const Key('rune', ' ');
    }
    if (b < 0x20) {
      _buf.removeAt(0);
      return Key('ctrl+${String.fromCharCode(b + 96)}');
    }

    int width;
    if (b < 0x80) {
      width = 1;
    } else if (b < 0xc0) {
      _buf.removeAt(0);
      return null;
    } else if (b < 0xe0) {
      width = 2;
    } else if (b < 0xf0) {
      width = 3;
    } else {
      width = 4;
    }
    if (_buf.length < width) return null;
    final r = utf8.decode(_buf.sublist(0, width));
    _buf.removeRange(0, width);
    return Key('rune', r);
  }
}
