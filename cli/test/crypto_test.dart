import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';

void main() {
  group('snEncrypt / snDecrypt roundtrip', () {
    test('roundtrips ascii', () {
      final c = snEncrypt('hello world', 'secret');
      expect(c.startsWith('SNENC1:'), true);
      expect(snDecrypt(c, 'secret'), 'hello world');
    });
    test('roundtrips utf8 + newlines', () {
      const p = 'line 1\nline 2\n中文 emoji 🚀';
      expect(snDecrypt(snEncrypt(p, 'k'), 'k'), p);
    });
    test('wrong pass returns garbage-but-not-null (best effort)', () {
      final c = snEncrypt('secret payload', 'aaa');
      final wrong = snDecrypt(c, 'bbb');
      // Best-effort cipher: returns something (may be lossy utf8), not null unless base64 bad.
      expect(wrong == 'secret payload', false);
    });
    test('non-marker returns null', () {
      expect(snDecrypt('plain text', 'k'), isNull);
    });
    test('empty input roundtrip', () {
      expect(snDecrypt(snEncrypt('', 'k'), 'k'), '');
    });
  });
}
