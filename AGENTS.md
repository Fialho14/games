# PuzzleGames repository guide

This repository contains one native macOS app with five independent puzzle
sessions. Before changing it, read `README.md`, `Documentation/ADDING_A_GAME.md`
and the current status in `CODEX_CONTINUATION.md`.

## Active project

- `Package.swift`, `Sources/`, `Tests/`, `Scripts/`, `Assets/` and `macOS/` are
  the active build inputs.
- `Archive/` contains historical or external reference material. It is never a
  package, runtime or test dependency. Preserve upstream licence files and do
  not copy reference code without validating both its licence and correctness.
- `Artifacts/` and `.build/` are generated and ignored.
- Spotlight normally opens `~/Applications/Puzzle Games.app`, not the copy in
  `Artifacts/`. Every local delivery must update it. `build-macos.sh` does this
  automatically through `Scripts/install-macos.sh`; relaunch and verify the
  installed copy rather than opening a stale artifact or leaving both running.

## Architectural rules

- Keep one long-lived model per game in `AppModel`; switching games must preserve
  every session.
- A game owns its engine/generator, model, board and tests under matching game
  directories. Share only genuine UI/session primitives.
- Do not create a universal engine or add unrelated product features.
- Generated puzzles must be attempt-bounded, procedurally varied and accepted
  only after an exact solution counter capped at two proves uniqueness.
- Preserve existing `UserDefaults` keys and validate restored state.
- Number games use `.numbers`; two-tool marking games should configure
  `.twoState(...)` instead of adding game-specific branches to the shell.

## Required validation

Run `./Scripts/check-project.sh` during development. Before delivery run:

```sh
./Scripts/check-project.sh --bundle
```

That command compiles with Swift warnings treated as errors, runs all Swift and
native tests, then builds and verifies the signed relocatable app and ZIP and
refreshes the copy in the user's Applications directory.
