# SyncNote — UI Plan

Detailed redesign for both apps. Goal: **simple, fast, doesn't look cheap.**

## Principles

1. **Content first, chrome invisible.** No wasted pixels on decorative frames.
2. **Consistent left-anchored typography.** Titles align, tags align, dates align.
3. **One accent color per state.** Doom One primary for focus, accent for AI, success/warning/error only when literal.
4. **Motion sparingly.** Only for confirming actions (save flash, toast slide).
5. **Keyboard first, mouse/tap second.** Every action reachable in ≤ 3 keystrokes.
6. **Same visual language across CLI and mobile.** Same palette, same iconography (Material Icons vector), same layout metaphors.

## Design tokens (shared between apps)

**Palette (Doom One):**
- Base `#282c34`
- Surface `#21242b`
- Overlay `#3f444a`
- Text `#bbc2cf`
- Muted `#5b6268`
- Primary (blue) `#51afef`
- Accent (magenta) `#c678dd`
- Success (green) `#98be65`
- Warning (yellow) `#ecbe7b`
- Error (red) `#ff6c6b`

**Spacing scale:** 4, 8, 12, 16, 24, 32
**Radius scale:** 4, 8, 12, 16, 20 (pill)
**Typography (mobile):** Inter or system default. Body 14, subtitle 12, title 16, hero 22
**Typography (CLI):** system monospace, one weight

---

# 📱 Mobile (Flutter) redesign

## Global chrome

**Bottom nav pill** (already shipped):
- 3 icons: chat / notes / settings
- Pill shape floating over content
- Height 56, radius 28
- Active: primary bg, base fg. Inactive: transparent, muted fg.

**Status bar:** Doom One base bg, edge-to-edge draw.

**Snackbars/toasts:**
- Slide from bottom, 3s dwell, rounded 12
- Success: green bg, base fg
- Error: red bg, base fg
- Neutral: surface bg, text fg

## Screen: Chat (home tab)

**Header:**
- 56pt tall
- Left: model name + "tap to change" caret
- Right: `Notes / Web` mode toggle pill + "new chat" refresh icon
- No back arrow (it's a tab)

**Empty state:**
- Centered avatar (accent color, 60pt circle, `Icons.auto_awesome`)
- Headline: "Ask me anything"
- Subtitle: "Chat streams live · markdown supported"
- 4 preset chips below, wrap layout, 8pt gap
- Chips: `💡 brainstorm ideas` / `📝 summarize my notes` / `+ note Groceries` / `📚 explain X`

**Message list:**
- User: right-aligned, primary bg, base fg, rounded 16 with tail (bottomRight 4)
- Assistant: left-aligned, surface bg, text fg, rounded 16 with tail (bottomLeft 4), accent avatar
- Max width 85% of viewport
- 4pt vertical gap between messages, 16pt between turns
- Streaming: `▍` caret at end of assistant bubble
- Actions row under assistant: `copy` / `save as note` / `retry` — muted, 11pt, 12pt gap

**Composer:**
- Sticky bottom, 12pt padding
- Left: `+` icon → save current draft as note
- Middle: text field, filled surface, rounded 12, expands to 5 lines max
- Right: send FAB (primary bg, base fg, 44pt)
- Hint text explains `/note <title>` shortcut

## Screen: Notes (tab 2)

**Header:**
- Sticky sliver AppBar, collapsed 56pt, expanded 130pt
- Left: title "SyncNote" + note count badge in overlay bg
- Right: sign-out icon

**Search + filters (below header):**
- Search field: filled surface, rounded 12, `Icons.search` prefix, clear button suffix
- Filter chips row: `all / notes / links / files`, horizontal scroll, 8pt gap, active = primary tint

**List:**
- Card per note: rounded 12, surface bg, overlay border 1pt
- Left icon: 40x40 rounded 10, colored bg (kind color at 20% opacity), Material icon centered
- Middle: title (15pt semibold, 1 line) + body preview (13pt muted, 2 lines) + tag chips (10pt, overlay bg, 4pt radius)
- Right: relative date (11pt muted)
- Card padding 14pt
- 6pt gap between cards
- Tap: open editor. Long-press: delete dialog.

**Empty state:**
- Centered circle (surface bg), icon (muted, 48pt)
- Headline + subtitle
- Different variants for "no notes" vs "no matches"

**FAB:**
- Extended: `+ new`, primary bg, base fg
- Bottom-right, 16pt inset above bottom nav

## Screen: Editor

**AppBar:**
- Back arrow, title "new note" / "edit"
- Actions: `[ ]` insert task · `👁` toggle preview · `✓` save

**Body:**
- Title field: 22pt bold, no border, autofocus on new
- Divider (overlay)
- Tag field: filled, `#` prefix icon, comma-separated
- Body field: expands to fill, monospaced-ish for markdown feel, 14pt

**Preview mode:**
- Same layout but body area rendered as Markdown
- Task checkboxes tappable (☐/☑ with strikethrough on done)
- Code blocks: base bg, warning fg, monospace
- Blockquotes: accent left border 3pt
- Headings: h1 accent 26pt, h2 accent 22pt, h3 primary 18pt

**Behavior:**
- Auto-save on every keystroke, debounced 500pt
- Ctrl+S saves immediately + shows toast
- Cmd+B / Ctrl+B wraps selection in `**bold**`
- Cmd+I wraps in `_italic_`
- Cmd+K inserts link
- Cmd+Enter toggles preview

## Screen: AI Settings (tab 3)

**Content:**
- Big card: "OpenRouter" logo/icon + one-line pitch + `get key` link to `openrouter.ai/keys`
- Section: API key
  - Filled text field with obscure toggle
  - Paste button
  - Green check icon appears when key valid (starts with `sk-or-`)
- Section: Model
  - List of 7 curated models, radio-select style
  - Each row: label + vendor + monospace ID + tag chip (`cheap` / `balanced` / etc)
- Section: System prompt
  - Multi-line text field

## Screen: Command palette (Ctrl+K overlay)

- Full-screen modal, base bg 85% opacity
- Centered dialog: max 640pt wide, radius 14, surface bg
- Search input at top with `Icons.terminal` prefix, `esc` badge suffix
- List below:
  - Left border stripe (transparent → primary when selected)
  - Icon + label + subtitle
  - `⌘` symbol on right for commands (not notes)
- Fuzzy match, arrow keys nav, Enter opens, Esc closes

---

# 🖥 CLI (Dart) redesign

## Layout principles

- Terminal is small; every glyph earns its space
- Never draw box-drawing frames — use whitespace and thin dividers
- One accent color at a time (mode-driven)
- Bottom-anchored controls (statusline + hint)

## Global layout (list mode, wide terminal)

```
✦ SyncNote                                          ● realtime · Doom One
─────────────────────────────────────────────────────────────────────────
 📁 spaces         ▎  new note              #work  4h  │ 👁 preview
 ● all       6     ▎  another note                 1h  │   
   untagged  4                                         │   another note
   #work     3                                         │   4h · #work
                                                       │   ────────────
                                                       │   body preview
                                                       │   wraps here
                                                       │   ~
                                                       │   ~
─────────────────────────────────────────────────────────────────────────
 NORMAL   4/6   📥 inbox                                 ● sync · Doom One
 hjkl move · Enter open · n new · dd delete · yy yank · <space>e tree
```

Three panes:
- **Tree** (left, 16-32 cols depending on terminal): tags/spaces, `● all` active dot, cursor stripe `▎`
- **List** (middle): notes, thin cursor stripe `▎` on selected, muted body preview
- **Preview** (right, 28-46 cols when terminal ≥ 120): current-under-cursor note detail

## Responsive rules

| Width | Layout |
|---|---|
| < 60 | list only |
| 60-89 | list only (tree hidden) |
| 90-119 | tree + list (no preview) |
| ≥ 120 | tree + list + preview (3-pane) |

## Cursor style

- **Normal / Visual:** thin stripe `▎` in Primary + slightly darker Surface bg on that row
- **Insert:** bar shape via DECSCUSR (`\x1b[5 q`)
- **Terminal cursor** aligned with buffer cursor position; block by default

## Statusline (bottom-1)

Segments left to right:
- Mode badge (color per mode: primary / success / accent / warning / error)
- Location `4/6` or `12:5`
- Context: `📥 inbox` / `📝 editing` / `✨ ai chat` / `📁 tree`
- Right side: `● sync` + `Doom One` theme badge

## Hint line (bottom-0)

- Context-sensitive keybind cheatsheet
- When toast set: replace with colored one-line message (2s dwell then reverts)
- When search/cmd mode: replaces with input line `/ query` or `: command`

## Chat pane

```
✦ SyncNote                                          ● realtime · Doom One
─────────────────────────────────────────────────────────────────────────
 📁 NOTES  Claude 3.5 Sonnet  key: env   Ctrl+W mode  Ctrl+L clear  Esc

  👤   what did we decide about pricing in the Q1 meeting?

  ✨   Based on your notes [Q1-Planning]:
       - Free tier caps at 100 notes
       - Pro at $5/mo

  ❯ can you save that as a note about pricing model                    
─────────────────────────────────────────────────────────────────────────
 CHAT · 4  ✨ ai chat                                  ● sync · Doom One
 Enter send · Ctrl+W notes/web · Ctrl+L clear · Esc back
```

- 👤 for user avatar (surface bg, base fg, rounded)
- ✨ for AI avatar (accent bg, base fg)
- Streaming shows `▍` caret at end of message
- Word-wrap to composer width
- Composer at bottom with `❯` prompt in warn color

## Detail (editor) pane

```
✦ SyncNote                                          ● realtime · Doom One
─────────────────────────────────────────────────────────────────────────
 title    Meeting notes                                                 
 tags     work, q1                                                      
 ──────────────────────────────────────                                 
   1  # Q1 Planning
   2                                                                    
   3  Decisions:                                                        
   4  - Ship v1 in Feb                                                  
   5  - Skip iOS for MVP                                                
   ~                                                                    
   ~                                                                    
─────────────────────────────────────────────────────────────────────────
 INSERT · 4:1   📝 editing   [body]                    ● sync · Doom One
 hjkl move · i insert · v visual · y yank · Tab field · Ctrl+S save
```

- Field labels: label bg = surface (or warn when active), then value in fg
- Body area: gutter with line numbers (relative in Normal, absolute in Insert)
- Selected row: subtle surface bg (cursorline)
- Visual selection: overlay bg
- Yank flash: warning bg for 400ms

## Colors table (used everywhere consistently)

| Purpose | Foreground | Background |
|---|---|---|
| Default text | text | base |
| Muted / gutters | muted | base |
| Selected item | primary | surface |
| Active pane header | accent / base | surface / accent |
| Insert mode | success bg on badge | - |
| Warning / attention | warn | base |
| Errors | error | base |
| Diff / removed | error | overlay |
| Diff / added | success | overlay |

## Animations (subtle only)

- Yank flash: 400ms warning-bg on yanked cells
- Toast: instant appear, 2s dwell, instant clear
- Streaming caret: solid `▍` (no blink — the streaming itself is motion)
- Mode transitions: instant (vim expectation)

## Icons (no emoji when possible)

Emoji look childish in serious tools. Prefer:
- `✦` for brand
- `▸` `▾` for tree expand/collapse
- `●` for status dots
- `▎` for cursor stripe
- `▍` for streaming caret
- `⟡` for yank marker
- `❯` for prompt
- `─` `│` for dividers
- `~` for empty rows

Reserved emoji (culturally universal, still legible):
- `📁` for spaces/tree (only in title)
- `📝` `🔖` `📄` in list mode (kind indicator)
- `👤` `✨` chat avatars

## Reduced-emoji mode

Add `--no-emoji` flag → replace all emoji with ASCII equivalents:
- `📁` → `[+]`
- `📝` → `[N]`
- `🔖` → `[L]`
- `📄` → `[F]`
- `👤` → `[you]`
- `✨` → `[ai]`

For users on terminals without emoji fonts.

---

# Rollout order (paired with PLAN.md phases)

**Phase 1 UI (with daily-driver):**
- Onboarding slides (mobile)
- App icon + splash (mobile)
- CLI `:help` overlay
- CLI reduced-emoji mode

**Phase 2 UI (with QoL):**
- File attachment picker + inline previews
- Version history diff view
- Password-lock unlock animation
- Deep-link handoff visual (splash → note fade)

**Phase 3 UI (with AI upgrade):**
- Embedding-quality indicator ("indexing N notes…")
- Semantic-vs-keyword toggle in chat

**Phase 4 UI (with power features):**
- Backlinks sidebar
- Global task view (aggregated `[ ]` from all notes)
- Reminder chip in note (`!remind` visual)

---

# Design tests (manual QA)

Before releasing:
- Boot Flutter app, take screenshots at 360, 768, 1024, 1440 widths
- Boot CLI at 40, 80, 120, 200 cols and 20, 40, 60 lines. Verify each is legible.
- All screens in both light-terminal and dark-terminal
- Every keyboard-only interaction reachable without mouse

---

# What "not looking cheap" means for us

- **No default Material icons at default sizes.** Always in a colored container.
- **No `Colors.blueGrey`** or any built-in Material color leaking through. Everything is Doom One.
- **No default Flutter splash white flash** on cold boot. Custom splash with brand mark.
- **No `TextButton` default underline hover** style. All buttons themed.
- **No shadow/elevation.** Flat design.
- **Aligned text baselines.** Titles, subtitles, dates all share a baseline grid.
- **Real content on empty screens.** Onboarding slides, not "no data" text.
