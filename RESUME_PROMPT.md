# Resume Prompt — copy this into a new Claude Code session

I'm continuing work on **SyncNote** — a cross-platform notes app (Flutter + Dart CLI + Supabase). Repo: https://github.com/Mohamedattiadev/syncnote

**Current state:**
- Flutter app runs Android/iOS/Linux/macOS/Windows/Web with realtime sync via Supabase
- Standalone Dart CLI at `bin/syncnote` — vim-modal, AI chat, RAG, offline SQLite cache
- 111 CLI tests passing, zero Flutter errors
- Theme: 6 palettes (Doom One default), full features working
- Everything documented in `README.md`, `PLAN.md`, `UI_PLAN_V2.md`

**What I want you to do:**

Read these files first:
- `UI_PLAN_V2.md` — the Fabric.so + Notion inspired redesign spec
- `README.md` — current feature set
- `PLAN.md` — long-term roadmap

Then implement **Phase A of UI_PLAN_V2** exactly as spec:

1. **Home screen rewrite** (`lib/screens/home_screen.dart`):
   - Big hero title "Good {morning/afternoon}, {name}" with muted date under
   - Prominent search bar under hero (52pt tall, rounded 12)
   - Chip row: `Tags · Connections · Shared with me`
   - Horizontal card rows (Netflix-style): **Pinned**, **Recent items**, **Spaces**, **AI conversations**
   - Card 200×240, title bold + 4-line preview + tag chips + meta footer

2. **Editor screen rewrite** (`lib/screens/editor_screen.dart`):
   - Notion-block layout — remove appbar in focus mode
   - Auto-focus title on new note
   - Line-height 1.7 body, 24pt title with tight tracking
   - Tags become chip-list at BOTTOM (not top)
   - Meta footer sticky with wider padding
   - Floating toolbar pill above keyboard on mobile

3. **Left rail nav on wide screens** (new `lib/widgets/left_rail.dart`):
   - 56-64px wide, icon-only
   - Vertical stack: Chat · Notes · Tasks · Stats · Settings
   - Avatar at top, sign-out at bottom
   - `main_shell.dart` picks rail vs bottom nav based on `MediaQuery.width >= 900`

4. **Strict spacing scale** — audit everything to use only: `4, 8, 12, 16, 20, 24, 32, 40, 48, 64`. Kill 6, 14, 18 stragglers.

5. **Radius scale** — audit everything to use only: `4, 8, 12, 16, 24, 9999 (pill)`.

6. **No shadows** — verify nothing has `BoxShadow`. Replace with 1px overlay borders where needed.

7. **Motion library** — add `flutter_animate` package. Every list item fades + slides in from bottom (30px, 200ms, staggered 30ms). Every screen transition = fade + slight scale (0.97 → 1.0).

**Constraints:**
- Keep Doom One as default theme (all 6 palettes stay)
- Zero regressions in existing features
- CLI untouched in this phase (Phase C addresses it)
- All existing tests must still pass
- Commit + push to `main` after each screen rewrite (feat(flutter): rewrite home per UI_PLAN_V2)

**Verification checklist before commit:**
- [ ] `flutter analyze` — 0 errors
- [ ] `flutter build web --release` — passes
- [ ] `cd cli && dart test` — 111 tests pass
- [ ] Screenshot the home screen and paste it in your response

**Start with:** run `git status` to see current tree, then read `UI_PLAN_V2.md` fully before writing any code.

**Ping me if:** you find a design decision that isn't spec'd (e.g. shadow between hero and search bar) — ask before assuming.
