import 'package:test/test.dart';
import 'package:syncnote_cli/render.dart';

void main() {
  group('cmdCompletions', () {
    test('empty input returns 6 alphabetical', () {
      final r = cmdCompletions('');
      expect(r.length, 6);
      // Sorted
      final sorted = List<String>.of(r)..sort();
      expect(r, sorted);
    });
    test('q prefix matches q-family', () {
      final r = cmdCompletions('q');
      expect(r.contains('q'), true);
      expect(r.contains('qa'), true);
      // All results start with q
      expect(r.every((c) => c.toLowerCase().startsWith('q')), true);
    });
    test('exp prefix matches export commands', () {
      final r = cmdCompletions('exp');
      expect(r.contains('export'), true);
      expect(r.contains('exporthtml'), true);
    });
    test('no match returns empty', () {
      expect(cmdCompletions('zzzzzz'), isEmpty);
    });
    test('limits to 6 results', () {
      final r = cmdCompletions('');
      expect(r.length <= 6, true);
    });
  });
}
