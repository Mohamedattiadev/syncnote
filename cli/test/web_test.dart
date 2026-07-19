import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';

void main() {
  group('URL detection', () {
    test('finds URL under cursor', () {
      const line = 'visit https://example.com/foo now';
      expect(urlUnderCursor(line, 10), 'https://example.com/foo');
      expect(urlUnderCursor(line, 5), isNull);
      expect(urlUnderCursor(line, 32), isNull);
    });
    test('counts URLs in text', () {
      const t = 'a https://a.com b http://b.io c https://c.dev/x';
      expect(countUrls(t), 3);
    });
    test('no URL', () {
      expect(urlUnderCursor('no urls here', 0), isNull);
      expect(countUrls('nothing'), 0);
    });
  });

  group('HTML strip', () {
    test('removes tags + scripts + styles', () {
      const html = '''<html><head><style>x{color:red}</style></head>
<body>Hello <b>world</b><script>evil()</script>&amp; ok</body></html>''';
      final out = stripHtml(html);
      expect(out.contains('Hello world'), true);
      expect(out.contains('& ok'), true);
      expect(out.contains('evil'), false);
      expect(out.contains('color'), false);
      expect(out.contains('<'), false);
    });
    test('collapses whitespace', () {
      expect(stripHtml('  <p>a    b</p>  '), 'a b');
    });
  });

  group('slugify', () {
    test('lowercase + dash', () {
      expect(slugify('My Cool Note!'), 'my-cool-note');
    });
    test('trims dashes', () {
      expect(slugify('---edge---'), 'edge');
    });
    test('empty fallback', () {
      expect(slugify('!!!'), 'note');
    });
  });

  group('tilde expand', () {
    test('expands ~', () {
      final e = expandTilde('~/foo');
      expect(e.endsWith('/foo'), true);
      expect(e.startsWith('~'), false);
    });
    test('no-op without ~', () {
      expect(expandTilde('/abs/path'), '/abs/path');
    });
  });
}
