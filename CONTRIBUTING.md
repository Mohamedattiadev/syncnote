# Contributing to SyncNote

Thanks for your interest. This is a small personal-first project, but PRs are welcome.

## Ground rules

- **Small, focused PRs.** One feature or one bug per PR.
- **Tests required for logic.** Vim motions, dispatch, RAG — add a test in `cli/test/*_test.dart`.
- **No emoji in code chrome.** Titles, statuslines, labels use plain text. Emoji OK in note content only.
- **Doom One palette only** for defaults. Add new themes via `lib/config/themes.dart` if you want alternatives.
- **CLI is Dart, not Go.** Rewrite proposals will be politely declined; we chose Dart to share models with Flutter.
- **Don't add heavy deps.** Justify anything > 5 MB. Prefer stdlib.

## Dev setup

```bash
git clone https://github.com/Mohamedattiadev/syncnote.git
cd syncnote
./setup.sh    # walks you through Supabase + compiles CLI
```

Run the CLI locally:

```bash
cd cli
dart pub get
dart test          # 111 tests
dart run bin/syncnote.dart
```

Run Flutter:

```bash
flutter pub get
flutter run -d chrome
```

## Structure

- `lib/` — Flutter app (Dart)
- `cli/` — standalone CLI (Dart)
- `supabase/` — Postgres schema + migrations
- `assets/` — icons + branding
- `PLAN.md` — roadmap
- `UI_PLAN.md` — design system

## Testing

- **CLI:** `cd cli && dart test` — must be green before merge.
- **Flutter:** `flutter analyze` must pass with zero errors.

## Adding a feature

1. Open an issue first if it's not tiny — align on scope.
2. Branch off `main`: `git checkout -b feat/short-name`.
3. Write the test first when possible.
4. Implement.
5. `dart test && flutter analyze` — all green.
6. Commit using conventional prefixes:
   - `feat(scope): …` — new feature
   - `fix(scope): …` — bug fix
   - `docs: …` — README / plans
   - `test(scope): …` — tests
   - `refactor(scope): …` — no behavior change
   - `style(scope): …` — visual polish
7. Push, open PR against `main`.

## Reporting bugs

Include:
- OS + terminal (for CLI) or device (for mobile)
- Steps to reproduce
- What you expected vs what happened
- Screenshot if UI-related
- Output of `syncnote --version` if applicable

## Code style

- Dart: `dart format .` before commit.
- Follow existing patterns in `cli/lib/` and `lib/screens/`.
- Comments only for non-obvious WHY, never WHAT. If the code needs a comment to explain what it does, rename variables.

## License

By contributing you agree your code will ship under MIT.
