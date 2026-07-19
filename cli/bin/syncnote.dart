// syncnote — terminal notes UI, standalone Dart binary.

import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

import 'package:syncnote_cli/ai.dart' as ai_svc;
import 'package:syncnote_cli/ansi.dart';
import 'package:syncnote_cli/config.dart';
import 'package:syncnote_cli/dispatch.dart';
import 'package:syncnote_cli/keys.dart';
import 'package:syncnote_cli/model.dart';
import 'package:syncnote_cli/rag.dart';
import 'package:syncnote_cli/render.dart';
import 'package:syncnote_cli/state.dart';

Future<void> main(List<String> args) async {
  // Guard: TUI needs a real TTY on both stdin and stdout.
  if (!stdin.hasTerminal || !stdout.hasTerminal) {
    stderr.writeln('syncnote: no interactive terminal detected.');
    stderr.writeln('This is a full-screen TUI — run it in an interactive shell.');
    stderr.writeln('Piped input / redirected stdout is not supported.');
    exit(2);
  }
  // Extra safety: try setting raw mode; if it fails, exit cleanly.
  try {
    stdin.echoMode = false;
    stdin.lineMode = false;
    // Restore so nothing changes for main flow
    stdin.echoMode = true;
    stdin.lineMode = true;
  } catch (_) {
    stderr.writeln('syncnote: terminal does not support raw input mode.');
    exit(2);
  }

  final cfg = Env.load();
  final store = TokenStore.userScope();
  final client = SupabaseClient(cfg.url, cfg.key);

  final saved = store.read();
  if (saved != null) {
    try {
      await client.auth.setSession(saved['refresh_token'] as String);
    } catch (_) {
      store.clear();
    }
  }
  if (client.auth.currentSession == null) {
    await _signIn(client, store);
  }

  final state = AppState();
  state.aiCfg = ai_svc.loadAi();
  await _reload(state, client);

  final channel = client
      .channel('notes_${client.auth.currentUser!.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: client.auth.currentUser!.id,
        ),
        callback: (_) async {
          await _reload(state, client);
          _draw(state);
        },
      )
      .subscribe();

  enterAlt();

  var cleaned = false;
  void cleanup() {
    if (cleaned) return;
    cleaned = true;
    // Restore stdin FIRST so we don't accidentally paint raw keys
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {}
    terminalReset();
    try { stdout.write('\n'); } catch (_) {}
    try { stdout.flush(); } catch (_) {}
  }
  final signals = <StreamSubscription>[];
  signals.add(ProcessSignal.sigint.watch().listen((_) {
    state.quit = true;
  }));
  signals.add(ProcessSignal.sigterm.watch().listen((_) {
    cleanup();
    exit(0);
  }));

  final reader = KeyReader()..start();
  signals.add(
      ProcessSignal.sigwinch.watch().listen((_) => _draw(state)));

  // Periodic redraws: splash animation + yank fade + chat spinner.
  Timer.periodic(const Duration(milliseconds: 100), (t) {
    if (state.quit) { t.cancel(); return; }
    if (state.shouldShowSplash || state.yankActive || state.chatBusy) _draw(state);
    if (!state.shouldShowSplash && !state.splashDismissed) {
      state.splashDismissed = true;
      _draw(state);
    }
  });

  _draw(state);

  try {
  await for (final k in reader.stream) {
    final r = dispatch(state, k);
    if (r.needsReload) await _reload(state, client);
    if (r.save && state.current != null) {
      state.syncBufsToNote();
      try {
        state.current!.updatedAt = DateTime.now().toUtc();
        await client
            .from('notes')
            .update(state.current!.toMap())
            .eq('id', state.current!.id);
        state.dirty = false;
        state.toast = 'saved';
        state.toastErr = false;
      } catch (e) {
        state.toast = 'save err: $e';
        state.toastErr = true;
      }
    }
    if (r.create) {
      final n = await _create(client);
      state.notes.insert(0, n);
      state.listCursor = 0;
      state.openNoteForEdit(n);
    }
    if (r.delete) {
      final n = state.current ?? state.currentUnderList();
      if (n != null) {
        try {
          await client.from('notes').delete().eq('id', n.id);
          state.notes.removeWhere((x) => x.id == n.id);
          state.closeDetail();
          state.toast = 'deleted';
        } catch (e) {
          state.toast = 'del err: $e';
          state.toastErr = true;
        }
      }
    }
    if (r.chatSend) {
      _sendChat(state);
    }
    // Pin toggle: detect ★/unpinned toast and persist
    if (state.toast == '★ pinned' || state.toast == 'unpinned') {
      final n = state.currentUnderList();
      if (n != null) {
        try {
          n.updatedAt = DateTime.now().toUtc();
          await client.from('notes').update(n.toMap()).eq('id', n.id);
        } catch (_) {}
      }
    }
    _draw(state);
    if (r.quit || state.quit) break;
  }
  } finally {
    for (final s in signals) { await s.cancel(); }
    await reader.stop();
    await channel.unsubscribe();
    cleanup();
    await client.dispose();
  }
}

Future<void> _signIn(SupabaseClient client, TokenStore store) async {
  stdout.writeln(sty([Colors.accent]) + 'SyncNote — sign in' + sty(['0']));
  stdout.write('email: ');
  final email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('password: ');
  stdin.echoMode = false;
  final pw = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  try {
    final r = await client.auth.signInWithPassword(email: email, password: pw);
    if (r.session == null) throw Exception('no session');
    store.write({
      'refresh_token': r.session!.refreshToken,
      'email': r.session!.user.email,
    });
  } catch (e) {
    stdout.writeln(sty([Colors.error]) + 'sign-in failed: $e' + sty(['0']));
    exit(1);
  }
}

Future<void> _reload(AppState s, SupabaseClient client) async {
  try {
    final uid = client.auth.currentUser!.id;
    final rows = await client
        .from('notes')
        .select()
        .eq('user_id', uid)
        .order('updated_at', ascending: false);
    s.notes =
        (rows as List).map((e) => Note.fromMap(e as Map<String, dynamic>)).toList();
    if (s.listCursor >= s.filtered().length) {
      s.listCursor = s.filtered().length - 1;
    }
    if (s.listCursor < 0) s.listCursor = 0;
    if (s.current != null) {
      final match = s.notes.where((n) => n.id == s.current!.id).toList();
      if (match.isNotEmpty) s.current = match.first;
    }
  } catch (e) {
    s.toast = 'load err: $e';
    s.toastErr = true;
  }
}

Timer? _redrawTimer;

void _sendChat(AppState s) {
  final cfg = ai_svc.loadAi();
  s.aiCfg = cfg;
  if (cfg == null || !cfg.valid) {
    s.toast = 'add OPENROUTER_KEY env var OR ~/.config/syncnote/ai.json (need sk-or-… key)';
    s.toastErr = true;
    return;
  }
  s.chatBusy = true;
  s.chatStreaming = '';
  final buf = StringBuffer();

  // Coalesce redraws to avoid concurrent stdout writes.
  _redrawTimer?.cancel();
  _redrawTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
    if (!s.chatBusy) return;
    _draw(s);
  });

  // Build messages with mode-specific system prompt.
  final msgs = <ai_svc.ChatMsg>[];
  if (s.chatUseNotes) {
    final query = s.chat.isNotEmpty ? s.chat.last.content : '';
    final sys = buildNotesSystemPrompt(query, s.notes);
    msgs.add(ai_svc.ChatMsg('system', sys));
  }
  msgs.addAll(s.chat);

  ai_svc.streamChat(cfg, msgs).listen(
    (delta) {
      buf.write(delta);
      s.chatStreaming = buf.toString();
    },
    onError: (e) {
      s.toast = 'ai err: ${_shortErr(e.toString())}';
      s.toastErr = true;
      s.chatStreaming = null;
      s.chatBusy = false;
      _redrawTimer?.cancel();
      _redrawTimer = null;
      _draw(s);
    },
    onDone: () {
      if (buf.isNotEmpty) {
        s.chat.add(ai_svc.ChatMsg('assistant', buf.toString()));
      }
      s.chatStreaming = null;
      s.chatBusy = false;
      _redrawTimer?.cancel();
      _redrawTimer = null;
      _draw(s);
    },
  );
}

String _shortErr(String e) {
  if (e.length <= 200) return e;
  return '${e.substring(0, 200)}…';
}

Future<Note> _create(SupabaseClient client) async {
  final now = DateTime.now().toUtc();
  final n = Note(
    id: const Uuid().v4(),
    userId: client.auth.currentUser!.id,
    title: 'new note',
    body: '',
    tags: [],
    createdAt: now,
    updatedAt: now,
  );
  await client.from('notes').insert(n.toMap());
  return n;
}

bool _drawing = false;
bool _drawPending = false;

void _draw(AppState s) {
  // Coalesce concurrent draws (timer + key + realtime callback can race
  // on the same stdout sink → "StreamSink is bound to a stream" crash).
  if (_drawing) {
    _drawPending = true;
    return;
  }
  _drawing = true;
  try {
    final w = termCols();
    final h = termRows();
    final frame = renderFrame(s, w, h);
    // Build entire frame into ONE string, single write = atomic.
    final buf = StringBuffer();
    buf.write('${csi}?25l'); // hide cursor
    buf.write('${csi}2J${csi}H'); // clear + home
    for (int i = 0; i < frame.rows.length && i < h; i++) {
      buf.write('${csi}${i + 1};1H');
      buf.write(frame.rows[i]);
    }
    if (frame.cursorRow != null && frame.cursorCol != null) {
      buf.write('${csi}${frame.cursorRow! + 1};${frame.cursorCol! + 1}H');
      buf.write(s.mode == Mode.insert ? '$esc[5 q' : '$esc[2 q');
      buf.write('${csi}?25h');
    }
    stdout.write(buf.toString());
  } catch (_) {
    // swallow — better than crashing the whole app
  } finally {
    _drawing = false;
    if (_drawPending) {
      _drawPending = false;
      scheduleMicrotask(() => _draw(s));
    }
  }
}
