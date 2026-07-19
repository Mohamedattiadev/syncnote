// Application state — pure data class, no I/O.

import 'ai.dart';
import 'model.dart';
import 'vim.dart';

/// AppState holds ALL UI state. Rendering + dispatch operate on this.
class AppState {
  // Data
  List<Note> notes = [];
  Note? current;

  // Views
  Focus focus = Focus.list;
  int listCursor = 0;
  int listScroll = 0;

  // Mode
  Mode mode = Mode.normal;

  // Which field of the note we're editing (when focus=detail).
  int fieldIdx = 0; // 0=title, 1=tags, 2=body
  Buffer titleBuf = Buffer.fromText('');
  Buffer tagsBuf = Buffer.fromText('');
  Buffer bodyBuf = Buffer.fromText('');

  Buffer get activeBuf => switch (fieldIdx) {
        0 => titleBuf,
        1 => tagsBuf,
        _ => bodyBuf,
      };

  // Search
  String search = '';
  String searchInput = '';
  int searchCursor = 0;

  // Cmd-line
  String cmdInput = '';
  int cmdCursor = 0;

  // Pending vim prefix keys
  bool pendingG = false;
  bool pendingD = false;
  bool pendingY = false;
  bool pendingC = false;
  bool pendingLeader = false;
  bool pendingLeaderB = false;
  bool pendingLeaderF = false;
  bool pendingTab = false;

  // Register (yank/delete buffer)
  String register = '';
  bool registerLinewise = false;

  // Feedback
  String toast = '';
  bool toastErr = false;
  bool dirty = false;

  bool quit = false;
  bool showHelp = false;

  // ---- Chat state ----
  List<ChatMsg> chat = [];
  String chatInput = '';
  int chatCursor = 0;
  String? chatStreaming;
  int chatScroll = 0;
  AiCfg? aiCfg;
  bool chatBusy = false;
  bool chatUseNotes = true; // Notes RAG mode ON by default

  // Yank flash — highlighted region + expiry time
  int? yankStartRow;
  int? yankStartCol;
  int? yankEndRow;
  int? yankEndCol;
  int yankUntilMillis = 0;

  bool get yankActive =>
      yankStartRow != null &&
      DateTime.now().millisecondsSinceEpoch < yankUntilMillis;

  void flashYank(int r1, int c1, int r2, int c2, {int ms = 400}) {
    yankStartRow = r1;
    yankStartCol = c1;
    yankEndRow = r2;
    yankEndCol = c2;
    yankUntilMillis = DateTime.now().millisecondsSinceEpoch + ms;
  }

  // Tree pane visibility
  bool treeOpen = false;
  int treeCursor = 0;
  String? treeFilter; // active tag filter

  // ---- helpers ----
  List<Note> filtered() {
    Iterable<Note> it = notes;
    if (treeFilter != null) {
      if (treeFilter == '__untagged__') {
        it = it.where((n) => n.tags.isEmpty);
      } else if (treeFilter == '__all__') {
        // no tag filter
      } else {
        it = it.where((n) => n.tags.contains(treeFilter));
      }
    }
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      // Score-based fuzzy match: substring > subsequence.
      final scored = it.map((n) {
        final hay = '${n.title.toLowerCase()} ${n.body.toLowerCase()} ${n.tags.join(' ').toLowerCase()}';
        final score = _fuzzyScore(q, hay);
        return (score, n);
      }).where((e) => e.$1 > 0).toList();
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      return scored.map((e) => e.$2).toList();
    }
    return it.toList();
  }

  /// 0 = no match, higher = better.
  /// - Exact substring: 1000 - position
  /// - Subsequence: chars-in-order but not adjacent, weighted by density
  static int _fuzzyScore(String query, String haystack) {
    if (query.isEmpty) return 1;
    final idx = haystack.indexOf(query);
    if (idx >= 0) return 1000 - idx; // reward early substring hits
    // Fuzzy subsequence match
    int hi = 0;
    int hits = 0;
    int lastPos = -1;
    int score = 0;
    for (final ch in query.runes) {
      final rest = haystack.substring(hi);
      final found = rest.indexOf(String.fromCharCode(ch));
      if (found < 0) return 0;
      hi += found + 1;
      hits++;
      // Reward adjacency (chars close together)
      if (lastPos >= 0 && found == 0) score += 5;
      lastPos = hi;
      score += 1;
    }
    return hits > 0 ? score : 0;
  }

  /// Ordered list of tag entries for tree pane: (label, filter-key, count).
  List<({String label, String key, int count})> treeItems() {
    final tagCounts = <String, int>{};
    int untagged = 0;
    for (final n in notes) {
      if (n.tags.isEmpty) untagged++;
      for (final t in n.tags) {
        tagCounts[t] = (tagCounts[t] ?? 0) + 1;
      }
    }
    final tags = tagCounts.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return [
      (label: 'all',       key: '__all__',      count: notes.length),
      (label: 'untagged',  key: '__untagged__', count: untagged),
      ...tags.map((e) => (label: '#${e.key}', key: e.key, count: e.value)),
    ];
  }

  Note? currentUnderList() {
    final f = filtered();
    if (f.isEmpty) return null;
    return f[listCursor.clamp(0, f.length - 1)];
  }

  void openNoteForEdit(Note n) {
    current = n;
    titleBuf = Buffer.fromText(n.title);
    tagsBuf = Buffer.fromText(n.tags.join(', '));
    bodyBuf = Buffer.fromText(n.body);
    focus = Focus.detail;
    fieldIdx = 2; // land on body
    mode = Mode.normal;
  }

  void closeDetail() {
    current = null;
    focus = Focus.list;
    mode = Mode.normal;
    fieldIdx = 0;
  }

  void syncBufsToNote() {
    if (current == null) return;
    current!.title = titleBuf.text;
    current!.body = bodyBuf.text;
    current!.tags = tagsBuf.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
