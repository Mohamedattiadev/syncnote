# SyncNote — UI Plan v2 (Fabric + Notion inspired)

Post-Fabric-audit rewrite. Current UI feels dev-tool cheap. Target: prosumer app that "feels expensive."

## Reference apps

- **Fabric.so** — hero title, generous whitespace, horizontal card rows, icon-only left nav rail, sticky bottom pill dock
- **Notion** — clean sans-serif, subtle divider hierarchy, focus mode, block-based content, generous line-heights, minimal chrome

## Core design shifts

### 1. Left icon rail replaces bottom nav (on wide screens)
- Rail 56-64px wide, icon-only (labels on hover)
- Sections stacked vertically: Chat · Notes · Tasks · Stats · Settings
- Avatar at top, sign-out at bottom
- On mobile: keep bottom nav
- Rail bg = surface, subtle border-right

### 2. Hero title on every top-level screen
- Personalized greeting: "Good morning, {name}"
- 32-40pt, tight letter-spacing (-0.02em)
- Muted timestamp below: "Sunday, Jul 19"
- Big search bar (52pt tall, rounded 12) directly under greeting
- Below search: pills for `Tags · Connections · Shared with me`

### 3. Netflix-row layout for notes home
Instead of vertical list/grid → horizontal card rows organized by category:
- **Pinned** — cards with pin badge
- **Recent items** — updated in last 7 days
- **Spaces** — folders/tags as tiles
- **AI conversations** — recent chats
- Each row: title `Recent items >` (clickable "view all"), scroll horizontally
- Card size: 200×240 (title + 4-line body preview + tag chips)
- Rounded 14, surface bg, subtle border

### 4. Sticky bottom dock (pill, floating)
- 3 icons: `+` new · `search` cmd-K · `ghost` ai chat
- Elevated pill, blurred bg (backdrop filter)
- Only shown on Notes screen
- Auto-hide on scroll down, reveal on scroll up

### 5. Typography scale (Notion-like)
```
Hero        40pt bold  letter-spacing -0.02em
Title       24pt semi  letter-spacing -0.01em
Subtitle    18pt semi
Body        16pt normal  line-height 1.6
Small       13pt normal  line-height 1.5
Meta        12pt medium  color muted
Micro       11pt medium  color muted  uppercase  letter-spacing 0.08em
```

### 6. Colors — reduce accent usage
- Base bg — pure Doom base (no accent tint)
- Card bg — Surface only, no primary borders except on hover
- Accents restricted to state: badges, active tab underline, focus ring
- Hover state — slight brightness bump only (+5% lightness), no color shift
- Focus ring — 2px primary at 40% opacity

### 7. Cards redesign — Notion-block style
```
┌────────────────────────────────────┐
│ 📌 Idea                            │
│                                    │
│ Refactor auth flow                 │
│                                    │
│ Discussed with team, need to       │
│ implement PKCE and add MFA...      │
│                                    │
│ #work #auth                        │
│                                    │
│                  4h ago  · 320 w   │
└────────────────────────────────────┘
```
- Icon prefix (kind indicator, muted)
- Title in bold Doom-fg
- 3-4 line body preview in muted
- Tags in accent (small monospace)
- Meta footer: date + word count in micro
- Padding 20 horizontal, 18 vertical
- Border on hover (Primary at 40%)

### 8. Editor — Notion-block layout
- Remove appbar completely in focus mode (just title + body)
- Title auto-focuses on new note
- Divider between title/body is subtle 1px overlay bar (not dark)
- Line-height 1.7 for body (breathe more)
- Tag input becomes chip-list at bottom, not top
- Meta footer sticky (like current) but wider padding
- Toolbar collapses to floating pill above keyboard on mobile

### 9. Chat — full-screen ChatGPT-style
- Remove sidebar/nav from chat screen (full immersion)
- Model + mode toggle in floating header (transparent)
- Bubbles: no borders, just bg + rounded corners (16pt)
- User bubbles right-aligned, base bg with primary accent text
- AI bubbles left-aligned, surface bg, text default
- Streaming indicator: subtle bottom border pulse instead of dots
- Composer sticky at bottom with rounded 20pt input, send button integrated

### 10. Micro-interactions
- All buttons: 100ms scale-down on press (`Transform.scale(0.96)`)
- Selection: subtle 200ms color transition, not instant
- Snackbars: slide from bottom with soft bounce
- Card tap: brief scale + haptic before nav
- Pull-to-refresh: custom animated spinner with 3 dots

---

## Screens to redo (priority order)

### P0 — Blocks daily use
1. **Home screen** — Fabric-style hero + horizontal rows
2. **Editor** — Notion-block layout, focus mode default at wide screens
3. **Chat** — ChatGPT-style immersion

### P1 — Polish
4. **Left rail nav** (wide screens) + keep bottom nav (mobile)
5. **Command palette** — bigger, centered dialog (Notion-style)
6. **Onboarding** — 3 slides with full-bleed illustrations
7. **Settings** — sectioned with sub-navigation

### P2 — Nice
8. **Stats** — chart.js-style animations
9. **Empty states** — illustrated art (not just icons)
10. **Login** — hero image or animated gradient

---

## Spacing scale (strict)

```
Space-1  4px
Space-2  8px
Space-3  12px
Space-4  16px
Space-5  20px
Space-6  24px
Space-8  32px
Space-10 40px
Space-12 48px
Space-16 64px
```

All paddings/margins/gaps must be one of these values. No 6, 14, 18 stragglers.

## Radius scale (strict)

```
Radius-1  4  (chips, tiny buttons)
Radius-2  8  (buttons, inputs)
Radius-3  12 (cards)
Radius-4  16 (large cards, modals)
Radius-5  24 (hero elements)
Radius-6  9999 (pills, avatars)
```

## Shadow/elevation
- **No shadows.** Only subtle borders + bg differentiation.
- If elevation absolutely needed: 1px border in Overlay at 60% opacity.

## Motion library
- Add `flutter_animate` for consistent staggered entry
- Every list item fades + slides in from bottom (30px, 200ms, staggered 30ms)
- Every screen transition = fade + slight scale (0.97 → 1.0)

---

## CLI — parallel refinement

CLI stays vim-first but adopt same principles:
- Bigger vertical breathing in list rows (already 2-row)
- Less color chrome
- Uppercase micro-labels for section headers (`SPACES` `NOTES` `PREVIEW`)
- Fabric-style search overlay already done
- Add horizontal-scroll spaces bar at top when many folders

---

## Design tokens JSON (to be generated)

```json
{
  "color": {
    "base": "#282c34",
    "surface": "#21242b",
    "overlay": "#3f444a",
    "text": "#bbc2cf",
    "muted": "#5b6268",
    "primary": "#51afef",
    "accent": "#c678dd",
    "success": "#98be65",
    "warning": "#ecbe7b",
    "error": "#ff6c6b"
  },
  "space": [4, 8, 12, 16, 20, 24, 32, 40, 48, 64],
  "radius": [4, 8, 12, 16, 24],
  "typography": {
    "hero": {"size": 40, "weight": 700, "tracking": -0.02},
    "title": {"size": 24, "weight": 600, "tracking": -0.01},
    "body": {"size": 16, "weight": 400, "lineHeight": 1.6},
    "meta": {"size": 12, "weight": 500}
  }
}
```

---

## Implementation phases

**Phase A (1-2 days)** — Home + Editor
- Rewrite `home_screen.dart` with hero + rows layout
- Rewrite `editor_screen.dart` with Notion-block layout
- Add `left_rail.dart` widget
- Update `main_shell.dart` to conditionally show rail vs bottom nav

**Phase B (1 day)** — Chat + Onboarding
- Rewrite `ai_chat_screen.dart` full-screen mode
- Onboarding with illustrations

**Phase C (½ day)** — Polish
- Motion library integration
- Empty state illustrations
- Command palette redesign

Total: 3-4 days full rewrite.
