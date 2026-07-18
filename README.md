# SyncNote

Your personal notes app. Syncs everywhere. **Free.** Bring-your-own-AI.

**Runs on:** Android · iOS · Linux · macOS · Windows · Web · Terminal (vim-native)

---

## 🚀 One-command install

```bash
git clone https://github.com/YOU/syncnote.git && cd syncnote && ./setup.sh
```

That's it. The script walks you through everything:

1. Picks a backend (**Demo** = no signup, **Supabase** = free cloud sync)
2. Runs the DB schema for you
3. Compiles the terminal binary → `~/.local/bin/syncnote`
4. Prints the exact command to launch on each platform

You do **one thing:** paste the SyncNote SQL into a Supabase SQL editor when the script says so. Everything else is automated.

---

## 🖥 What you get

| App | Where | How to run |
|---|---|---|
| Notes app | phone / desktop / web | `just chrome` · `just android` · `just apk` |
| Terminal CLI | Linux/macOS/WSL | `syncnote` |
| AI chat | in both | 📁 notes mode (RAG) · 🌐 web mode |

Everything syncs live via Supabase Realtime. Edit a note on your phone → watch it appear in the terminal on your PC.

---

## 🎯 Quick start (after `./setup.sh`)

```bash
syncnote        # terminal
just chrome     # web
just apk        # install on plugged Android phone
```

---

## ✨ Terminal keys (nvim-native)

```
Navigation:   h j k l · gg · G · w b · 0 $
Modes:        i I a A · o O · v V · Esc
Yank/paste:   yy · dd · cc · p · y (visual)
Search:       /  followed by query
Command:      :q  :w  :new  :reload  :del
Leader (Space):
  <space>a    AI chat        <space>e   toggle tree
  <space>fg   search         <space>bd  delete note
  <space>bn   new note       <space>q   quit
Boost:        <tab>hjkl = jump 5, H/L = 5x
```

---

## 🤖 AI chat

**Both apps** support chat with your notes as context.

Get a free OpenRouter key (one key → Claude / GPT / Gemini / Llama):
👉 https://openrouter.ai/keys

**Web app:** open chat → gear icon → paste key → done.

**CLI:** either export the env var, or drop a config file:

```bash
# option 1 — for this shell only
export OPENROUTER_KEY=sk-or-your-key

# option 2 — permanent
mkdir -p ~/.config/syncnote
cat > ~/.config/syncnote/ai.json <<'EOF'
{
  "apiKey": "sk-or-your-key",
  "model": "anthropic/claude-3.5-sonnet",
  "maxTokens": 2048
}
EOF
```

Then in CLI press `<space>a`. Toggle `Ctrl+W` between 📁 **notes** (RAG over your notes) and 🌐 **web** (plain chat).

**Cheap models to start with:**
- `openai/gpt-4o-mini` — great default
- `google/gemini-flash-1.5` — very cheap
- `deepseek/deepseek-chat` — cheapest

---

## 🔧 If `just` isn't installed

Arch: `sudo pacman -S just android-tools`
Debian/Ubuntu: `sudo apt install just adb`
macOS: `brew install just android-platform-tools`

Or just use the raw commands:

```bash
./bin/syncnote                                # CLI
flutter run -d chrome                         # web
flutter build apk --release && flutter install # Android
```

---

## 🏗 What's inside

```
lib/                   Flutter app
cli/                   standalone Dart terminal binary (source)
bin/syncnote           compiled CLI (8 MB, no runtime needed)
supabase/schema.sql    the Postgres schema
setup.sh               the one-command installer
justfile               task recipes
```

The CLI is a real modal terminal editor: buffer + cursor + visual selection + yank register + realtime sync + AI chat with RAG. All in one static binary.

---

## 🐛 Report bugs

Anything weird → screenshot + paste `$ syncnote --version` output.

---

## 📜 License

MIT. Fork it, hack it, use it.
