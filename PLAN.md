# SyncNote — Product Plan

Roadmap to turn SyncNote into a real open-source notes app people actually use daily.

## North Star

**A personal notes app that syncs everywhere, works offline, has a great terminal AND phone experience, respects your privacy, and lets you bring your own AI.**

Non-goals: enterprise SSO, team collab, wiki graphs like Obsidian. Personal-first.

---

## Phases

### Phase 0 — Foundation (✓ done)

- [x] Flutter app (Linux/Web/Android)
- [x] Standalone CLI in Dart (compiles to native binary)
- [x] Supabase realtime backend
- [x] Auth (email/password)
- [x] Doom One theme (both apps)
- [x] Basic RAG (keyword ranking)
- [x] AI chat (OpenRouter)
- [x] Markdown editor with preview
- [x] Task checkboxes
- [x] Command palette (Ctrl+K)
- [x] Tree pane (tags/spaces)
- [x] Vim modal editing in CLI
- [x] 59 CLI tests, all passing

### Phase 1 — Daily-driver (blocks real use) — **Next**

**Goal: I can uninstall Obsidian and use SyncNote as my only notes app.**

- [ ] **Offline mode (mobile)** — SQLite cache via drift; sync when online
- [ ] **Auto-save** — debounced 500ms; no "unsaved" panic
- [ ] **Undo/redo in CLI** — `u` / `Ctrl+R` with per-note history
- [ ] **`:help` command in CLI** — full keybind cheatsheet overlay
- [ ] **Better error toasts** — human-readable, actionable
- [ ] **App icon + splash** — SVG-based, launcher-icons package
- [ ] **Android APK signing** — release-signed builds
- [ ] **Onboarding** — 3-slide intro on first launch

Est: 2-3 days.

### Phase 2 — Quality-of-life

- [ ] **Full-text search (Postgres tsvector)** — replaces client-side filter, much faster on large libraries
- [ ] **File attachments** — Supabase Storage bucket, upload UI, preview inline
- [ ] **Share sheet** (Android/iOS) — receive shared text/URL/image
- [ ] **Version history** — every save = row in `note_versions`, restore diff view
- [ ] **Password / biometric lock** — Face ID / fingerprint on app open
- [ ] **Deep links** — `syncnote://note/<id>` opens direct
- [ ] **Backup/export** — one-tap ZIP of markdown files
- [ ] **Import from other apps** — Obsidian vault, Apple Notes JSON, Markdown zip

Est: 1 week.

### Phase 3 — AI upgrade

- [ ] **Real vector embeddings** — `text-embedding-3-small` via OpenAI or local `nomic-embed-text` via Ollama; stored in `notes.embedding` (pgvector col already exists)
- [ ] **Semantic search** — top-K cosine over embeddings for RAG context
- [ ] **AI actions** — LLM tool-calling: create/update/delete notes via chat ("summarize my meeting notes and save as a note called Meeting-Summary")
- [ ] **AI-assisted tags** — suggest tags from note content
- [ ] **Batch operations** — "delete all notes tagged #done older than 3 months"

Est: 3-4 days.

### Phase 4 — Power features

- [ ] **Backlinks** — `[[note-title]]` auto-linking, backlinks sidebar
- [ ] **Task view** — global TODO aggregating `- [ ]` across all notes
- [ ] **Reminders** — `!remind tomorrow 3pm` → local notification (mobile), stored on note
- [ ] **Publish note as public URL** — RLS policy toggle, shareable read-only link
- [ ] **Themes** — Catppuccin, Nord, Solarized, Rose Pine, Tokyo Night
- [ ] **Rich media** — image inline, code blocks with syntax highlight, MermaidJS render
- [ ] **Home-screen widget (Android)** — recent notes list + quick-add

Est: 1 week.

### Phase 5 — Production infra

- [ ] **Crash reporting** — Sentry free tier, both apps
- [ ] **Opt-in analytics** — PostHog cloud free tier; usage stats
- [ ] **CI/CD** — GitHub Actions:
  - Push → run tests (Dart + Flutter)
  - Tag `v*` → build web + APK + CLI binaries → publish to GitHub Releases
- [ ] **Auto-update** — `syncnote --update` for CLI; in-app check on mobile
- [ ] **Documentation site** — MkDocs Material or Docusaurus, hosted on GitHub Pages
- [ ] **Contribution guide** — `CONTRIBUTING.md`, issue templates, PR template
- [ ] **Roadmap board** — public GitHub Projects board
- [ ] **Discord/Matrix community** — optional, for questions

Est: 2 days.

### Phase 6 — Distribution

- [ ] **GitHub Releases** — signed APK, CLI binaries (Linux/macOS/Windows), web bundle
- [ ] **AUR package** — `syncnote-cli` for Arch users
- [ ] **Homebrew tap** — `brew install syncnote/tap/syncnote`
- [ ] **F-Droid** — Free-software Android store (100% FOSS deps)
- [ ] **Play Store** — later, when polished ($25 one-time)
- [ ] **Landing page** — sales pitch, screenshots, one-command install

Est: 2 days.

---

## Backend hardening

- [ ] Rate-limit inserts per user (Postgres function + trigger)
- [ ] Nightly backup script → user's own S3/local via `pg_dump`
- [ ] Row-level policies audit (verify RLS blocks cross-user reads)
- [ ] Move sensitive settings to secure enclave (Keychain on iOS, Keystore on Android)
- [ ] Migrations directory in `supabase/migrations/` with versioned SQL
- [ ] Seed script for demo data

---

## E2E encryption (opt-in)

- [ ] User-chosen master password → derives symmetric key (Argon2id)
- [ ] Encrypt `notes.body` client-side with libsodium/`cryptography` package
- [ ] Key never leaves device; Supabase stores ciphertext
- [ ] Recovery phrase for lost passwords
- [ ] Per-note encryption toggle (default: off, so search + RAG still work)

Est: 1 week — worthwhile only when we have real users.

---

## Success metrics (post-launch)

- 100 GitHub stars in month 1
- 10 daily-active users on hosted instance
- Under 5 open bugs at all times
- Weekly release cadence for first 2 months
- One "SyncNote made X easier" post per week from users

---

## Open questions

- Should we bundle a hosted Supabase for demo users? (Cost: $25/mo Supabase Pro)
- Custom domain for auth emails (`no-reply@syncnote.app`)?
- Sponsor via GitHub Sponsors from month 3?

---

## What Phase 1 unlocks

Once Phase 1 ships you can:
- Use it on your phone during commute, no signal, edits sync when back
- Trust the CLI (undo means fewer catastrophes)
- Hand the APK to a friend without embarrassment (icon, splash, signed)
- Do the "5-minute demo" without them asking "wait what is this"
