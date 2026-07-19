# SyncNote

Your notes. Everywhere. Zero cheap tells.

**Flutter app** — Android · iOS · Linux · macOS · Windows · Web · PWA
**CLI (`syncnote`)** — pure-Dart native binary, vim-modal, syncs same DB

Free stack. Open source. Fork it.

---

## 🚀 Install (one command)

```fish
git clone https://github.com/Mohamedattiadev/syncnote.git && cd syncnote && ./setup.sh
```

`setup.sh` does the rest:
- **Demo** mode — works right now, no signup
- **New Supabase** — walks you through a free project + auto-applies schema
- **Existing** — paste URL + key, done

Then:
```fish
syncnote          # terminal, if installed to PATH
just chrome       # Flutter in Brave/Chrome
just apk          # Android APK on plugged phone
```

---

## ✨ Features

### Sync
- Realtime cross-device via Supabase
- Offline mode with SQLite cache + pending-op queue
- Auto-save (debounced 700ms)

### Editor
- Markdown with live preview
- Task checkboxes `- [ ]` clickable
- Toolbar: bold / italic / code / heading / list / task / link
- Keyboard shortcuts (Ctrl/Cmd + B/I/K/S/E)
- Pin to top, focus mode
- Word count + read time
- Metadata footer

### Home
- Filter chips (all / notes / links / files)
- Multi-tag filter via chip tap
- Fuzzy search (substring wins, subsequence works)
- Sort: recently updated / created / alphabetical
- Card grid layout on wide screens (≥720px)
- Pull-to-refresh + haptics

### AI Chat (bring your own key)
- **OpenRouter** — one key → Claude / GPT / Gemini / Llama / DeepSeek
- **NOTES mode** — RAG over your notes (keyword scoring, no embeddings needed)
- **WEB mode** — general chat
- Tool-calling — LLM creates/deletes notes autonomously via JSON blocks
- Natural language: "create note called X, content Y" → auto-saved
- Save any reply as note via one tap
- `/note Title\nbody` command shortcut

### Tasks
- Aggregates all `- [ ]` across all notes
- Toggle done in-place
- Nav badge shows undone count

### Stats
- Notes / words / pinned / tasks-done cards
- Top tags with progress bars
- 30-day activity heatmap

### Command Palette
- `Ctrl+K` / `Cmd+K` opens fuzzy palette
- Jump to any note or command
- Fuzzy match with score ranking

### Themes
- 6 palettes: Doom One (default), Catppuccin Mocha, Nord, Gruvbox, Tokyo Night, Rosé Pine
- Picker in Settings
- Persisted via SharedPreferences

### Security
- Biometric app lock (Face ID / fingerprint)
- Enabled per-device in Settings
- Web fallback: no-op

### Backup
- One-tap export as `.zip` of `notes.json` + markdown files per note
- Restore via same file

### Bottom nav (4 tabs)
- **Chat** (home) · **Notes** · **Tasks** · **Settings**
- Badges: note count on Notes tab, undone task count on Tasks tab
- Smooth fade+slide page transitions

---

## 🖥 CLI

Full-screen native TUI with real vim modal editing.

### Keys

```
Motion:   hjkl · w b e · 0 $ · gg G · H L · <tab>hjkl · Ctrl+d/u
Counts:   5j  10k  3w  15G  5dd  3yy  4x  (any motion/operator)
Modes:    i I a A o O · v V · Esc
Edit:     y d c yy dd cc dw · x p · u Ctrl+r · . (repeat)
Nav:      Enter open · Tab · q back
Char:     f{c} F{c} t{c} T{c} · ; , (repeat)
Marks:    m{a-z} set · '{a-z} jump
Count:    g Ctrl-g  word/char/line count toast
Leader:   <space>q quit  <space>w save  <space>e tree  <space>a AI
          <space>bd del  <space>bn new  <space>fg search  <space>r reload
          <space>x  open URL under cursor (mirror of gx)
Command:  :q :w :wq :q!  |  :qa :qa! :wqa :xa  (quit-all)
          :new :del :reload :search :help
          :<N>            jump to line N
          :e <query>      fuzzy open note by title
          :s/pat/repl/[g] :%s/...     substitute
          :set wrap|nowrap|number|nonumber|theme <name>
          :pwd  :cd [path]
          :!<cmd>  :sh <cmd>          shell escape
Web:      gx  <space>x           open URL under cursor
          :o :open <url>         open URL
          :web <query>           DuckDuckGo search
          :import <url>          fetch + create note
          :export [path]         write note as markdown
          :exporthtml [path]     write note as html
          :read <path>           insert file at cursor
          :pipe <cmd>            filter buffer through cmd
          :copy :paste           system clipboard (wl/xclip/pb)
Org:      :daily :today          open/create daily note
          :sort :sort! :sortu    sort buffer lines
          :g/pat/d               delete matching lines
          :v/pat/d               keep only matching lines
          :bl :backlinks         notes linking here
          [[title]]              wiki-link (tap in Flutter preview)
Regs:     "{a-z}y  "{a-z}p      named registers (yank/paste)
Sec:      :encrypt <pass>        XOR+base64 obscure note body
          :decrypt <pass>        reverse encryption
          :undolist              show undo/redo stack sizes
Search:   / (fzf-style overlay)
Pin:      P
Help:     ? or :help
```

### AI setup

Two options:

```fish
# 1. Env var (per shell)
set -Ux OPENROUTER_KEY sk-or-YOUR-KEY

# 2. Config file (persistent)
mkdir -p ~/.config/syncnote
cat > ~/.config/syncnote/ai.json <<'EOF'
{
  "apiKey": "sk-or-YOUR-KEY",
  "model": "anthropic/claude-3.5-sonnet",
  "maxTokens": 2048
}
EOF
```

Get key: https://openrouter.ai/keys

### Layout

3-pane responsive:
- **< 60 cols** — list only
- **60-79** — list only (tree hidden)
- **80-119** — tree + list
- **≥ 120** — tree + list + preview

Preview auto-updates as cursor moves. Markdown rendered (headings, tasks, bold/italic, code fences, blockquotes).

---

## 🏗 Structure

```
lib/                      Flutter app
  main.dart               entry + auth gate + onboarding
  config/
    env.dart              secrets (gitignored)
    env.example.dart      template
    theme.dart            Material 3 theme wired to palettes
    themes.dart           6 named palettes
  models/note.dart
  services/
    ai.dart               OpenRouter streaming client
    ai_actions.dart       parse ```syncnote-action``` blocks
    ai_settings.dart      SharedPreferences persistence
    app_lock.dart         biometric gate
    auth.dart
    backlinks.dart        [[note title]] index
    backup.dart           zip export/import
    deep_links.dart       syncnote:// URI parser
    local_cache.dart      SQLite offline cache + pending ops
    mock_repo.dart        demo mode
    notes_repo.dart       Supabase + cache
    rag.dart              keyword-ranked context builder
    templates.dart        daily/meeting/idea templates
  providers.dart          Riverpod graph
  screens/
    ai_chat_screen.dart   RAG + web + streaming
    ai_settings_screen.dart
    app_lock_screen.dart
    command_palette.dart  Ctrl+K
    editor_screen.dart    markdown editor + preview
    home_screen.dart      list + grid + filters
    login_screen.dart
    main_shell.dart       bottom nav shell
    onboarding_screen.dart
    setup_wizard.dart     first-run supabase guide
    stats_screen.dart     analytics
    tasks_screen.dart     global task view
    theme_picker.dart
  widgets/
    skeleton.dart         shimmer loaders
    typing_dots.dart      chat 3-dot pulse

cli/                      standalone Dart CLI
  bin/syncnote.dart       entry
  lib/
    ai.dart               OpenRouter for CLI
    ansi.dart             escape sequences + Doom One
    config.dart           env + token store
    dispatch.dart         keymap dispatcher
    keys.dart             raw byte parser
    markdown.dart         ANSI-styled markdown renderer
    model.dart            Note + Mode + Focus
    rag.dart              keyword ranker (matches Flutter)
    render.dart           frame builder
    state.dart            AppState + fuzzy search
    vim.dart              Buffer + motions + selection + undo
  test/                   111 tests

supabase/
  schema.sql              base schema
  migrations/             time-stamped SQL migrations

.github/
  workflows/
    ci.yml                push/PR runs tests + builds
    release.yml           v* tags → binaries + web zip + APK
  ISSUE_TEMPLATE/
    bug.yml
    feature.yml

setup.sh                  one-command bootstrap
justfile                  task recipes
CONTRIBUTING.md
LICENSE                   MIT
PLAN.md                   product roadmap
UI_PLAN.md                design system
```

---

## 📊 Health

- **111** CLI tests passing
- **0** Flutter errors
- CI enforces both on every push

---

## 🔮 Roadmap

See [PLAN.md](PLAN.md). Highlights not yet shipped:
- Real vector embeddings for semantic RAG
- File attachments via Supabase Storage
- Version history (per-note revision log)
- Sharing single notes as public URL
- E2E encryption for note bodies
- Share sheet handlers (Android/iOS)
- Push reminders

---

## 📜 License

MIT. Fork, hack, use.
