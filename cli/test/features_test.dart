// Tests for new features: quit-confirm, tree, chat mode, yank flash, RAG.

import 'package:test/test.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/rag.dart';
import 'package:syncnote_cli/state.dart';

Key rune(String r) => Key('rune', r);

AppState _state({int count = 3}) {
  final s = AppState()..splashDismissed = true;
  final now = DateTime.now().toUtc();
  s.notes = List.generate(
    count,
    (i) => Note(
      id: 'id-$i',
      userId: 'u',
      title: 'note ${i + 1}',
      body: 'body $i',
      tags: i == 0 ? ['work'] : (i == 1 ? ['personal'] : []),
      createdAt: now,
      updatedAt: now,
    ),
  );
  return s;
}

void main() {
  group('Quit confirmation', () {
    test('q enters confirmQuit mode, does NOT quit immediately', () {
      final s = _state();
      final r = dispatch(s, rune('q'));
      expect(r.quit, isFalse);
      expect(s.mode, Mode.confirmQuit);
    });

    test('y in confirmQuit quits', () {
      final s = _state();
      dispatch(s, rune('q'));
      final r = dispatch(s, rune('y'));
      expect(r.quit, isTrue);
    });

    test('Y (uppercase) in confirmQuit quits', () {
      final s = _state();
      dispatch(s, rune('q'));
      final r = dispatch(s, rune('Y'));
      expect(r.quit, isTrue);
    });

    test('n cancels confirmQuit', () {
      final s = _state();
      dispatch(s, rune('q'));
      final r = dispatch(s, rune('n'));
      expect(r.quit, isFalse);
      expect(s.mode, Mode.normal);
    });

    test('Esc cancels confirmQuit', () {
      final s = _state();
      dispatch(s, rune('q'));
      final r = dispatch(s, const Key('esc'));
      expect(r.quit, isFalse);
      expect(s.mode, Mode.normal);
    });
  });

  group('Tree pane', () {
    test('<space>e opens tree + focus tree', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('e'));
      expect(s.treeOpen, isTrue);
      expect(s.focus, Focus.tree);
    });

    test('<space>e again closes tree, focus returns to list', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('e'));
      dispatch(s, rune(' '));
      dispatch(s, rune('e'));
      expect(s.treeOpen, isFalse);
      expect(s.focus, Focus.list);
    });

    test('tree contains all + untagged + tags with counts', () {
      final s = _state();
      final items = s.treeItems();
      expect(items.map((e) => e.label).toList(),
          containsAll(['all', 'untagged', '#personal', '#work']));
      final all = items.firstWhere((e) => e.key == '__all__');
      expect(all.count, 3);
      final untagged = items.firstWhere((e) => e.key == '__untagged__');
      expect(untagged.count, 1);
    });

    test('Enter in tree applies filter and returns to list', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('e'));
      // cursor at 0 (all), move to a real tag
      final items = s.treeItems();
      final workIdx = items.indexWhere((e) => e.key == 'work');
      s.treeCursor = workIdx;
      dispatch(s, const Key('enter'));
      expect(s.treeFilter, 'work');
      expect(s.focus, Focus.list);
      // filtered() returns only work-tagged notes
      expect(s.filtered().length, 1);
      expect(s.filtered().first.tags, contains('work'));
    });
  });

  group('AI chat mode', () {
    test('<space>a opens chat focus', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      expect(s.focus, Focus.chat);
    });

    test('typing in chat mode fills chatInput', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      for (final c in 'hi'.split('')) {
        dispatch(s, rune(c));
      }
      expect(s.chatInput, 'hi');
      expect(s.chatCursor, 2);
    });

    test('Enter in chat returns chatSend result', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      for (final c in 'hello'.split('')) {
        dispatch(s, rune(c));
      }
      final r = dispatch(s, const Key('enter'));
      expect(r.chatSend, isTrue);
      expect(s.chat.length, 1);
      expect(s.chat.first.content, 'hello');
    });

    test('Ctrl+W toggles notes<->web mode', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      expect(s.chatUseNotes, isTrue); // default
      dispatch(s, const Key('ctrl+w'));
      expect(s.chatUseNotes, isFalse);
      dispatch(s, const Key('ctrl+w'));
      expect(s.chatUseNotes, isTrue);
    });

    test('Ctrl+L clears chat history', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      for (final c in 'hi'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.chat.length, 1);
      dispatch(s, const Key('ctrl+l'));
      expect(s.chat, isEmpty);
    });

    test('Esc from chat returns to list', () {
      final s = _state();
      dispatch(s, rune(' '));
      dispatch(s, rune('a'));
      dispatch(s, const Key('esc'));
      expect(s.focus, Focus.list);
    });
  });

  group('Yank flash', () {
    test('yy in list sets register and toast', () {
      final s = _state();
      dispatch(s, rune('y'));
      dispatch(s, rune('y'));
      expect(s.register, 'note 1');
      expect(s.toast, contains('yanked'));
    });

    test('yankActive true briefly, false after time passes', () async {
      final s = _state();
      s.flashYank(0, 0, 0, 3, ms: 50);
      expect(s.yankActive, isTrue);
      await Future.delayed(const Duration(milliseconds: 80));
      expect(s.yankActive, isFalse);
    });
  });

  group('Undo/redo', () {
    test('u undoes an edit; Ctrl+R redoes it', () {
      final s = _state();
      dispatch(s, const Key('enter')); // open detail
      dispatch(s, rune('i')); // insert mode (takes snapshot)
      dispatch(s, rune('X'));
      dispatch(s, rune('Y'));
      dispatch(s, const Key('esc'));
      expect(s.bodyBuf.text.contains('XY'), isTrue);
      dispatch(s, rune('u'));
      expect(s.bodyBuf.text.contains('XY'), isFalse); // undone
      dispatch(s, const Key('ctrl+r'));
      expect(s.bodyBuf.text.contains('XY'), isTrue); // redone
    });

    test('u without history shows toast', () {
      final s = _state();
      dispatch(s, const Key('enter'));
      dispatch(s, rune('u'));
      expect(s.toast, contains('nothing to undo'));
    });
  });

  group('Help overlay', () {
    test('? toggles help', () {
      final s = _state();
      dispatch(s, rune('?'));
      expect(s.showHelp, isTrue);
      dispatch(s, const Key('esc'));
      expect(s.showHelp, isFalse);
    });

    test(':help opens help', () {
      final s = _state();
      dispatch(s, rune(':'));
      for (final c in 'help'.split('')) {
        dispatch(s, rune(c));
      }
      dispatch(s, const Key('enter'));
      expect(s.showHelp, isTrue);
    });

    test('help absorbs input until dismissed', () {
      final s = _state();
      s.showHelp = true;
      dispatch(s, rune('j'));
      expect(s.listCursor, 0); // motion ignored
      expect(s.showHelp, isTrue);
    });
  });

  group('RAG builder', () {
    test('empty notes → tells LLM to say so', () {
      final p = buildNotesSystemPrompt('anything', []);
      expect(p, contains('no notes'));
    });

    test('note titles + bodies included in prompt', () {
      final s = _state();
      final p = buildNotesSystemPrompt('work', s.notes);
      expect(p, contains('note 1'));
      expect(p, contains('body 0'));
      expect(p, contains('---NOTES BEGIN---'));
      expect(p, contains('---NOTES END---'));
    });

    test('query keywords rank matching notes higher', () {
      final s = _state();
      final p = buildNotesSystemPrompt('work', s.notes);
      // work-tagged note should appear before others in body
      final workIdx = p.indexOf('note 1'); // has 'work' tag
      final personalIdx = p.indexOf('note 2');
      expect(workIdx, greaterThanOrEqualTo(0));
      expect(personalIdx, greaterThan(workIdx));
    });

    test('char budget truncates long notes', () {
      final s = AppState()..splashDismissed = true;
      final now = DateTime.now().toUtc();
      s.notes = List.generate(
        5,
        (i) => Note(
          id: 'id-$i',
          userId: 'u',
          title: 'big-$i',
          body: 'X' * 2000,
          tags: const [],
          createdAt: now,
          updatedAt: now,
        ),
      );
      final p = buildNotesSystemPrompt('q', s.notes, maxChars: 3000);
      expect(p.length, lessThan(4500));
      expect(p, contains('---NOTES END---'));
    });
  });
}
