# PuzzleGames continuation record

STATUS: IN PROGRESS

## Global objective

Expand the existing native macOS PuzzleGames app so Slitherlink, Skyscrapers,
and Nurikabe feel native beside Sudoku and Calcudoku. Every new game must be
fully playable, persistent, procedurally generated, exactly solved/validated,
classified by meaningful solver work, tested across multiple deterministic
seeds, and integrated without regressions. Finish with a whole-project cleanup,
full build/test/stress verification, and set this file to `STATUS: COMPLETE`.

## Architecture discovered

- Swift 6 package at `PuzzleGames/Package.swift`, macOS 14+, one SwiftUI
  executable target and two native engine targets (`SudokuEngine` C++ and
  `CalcudokuEngine` C).
- `Sources/PuzzleGames/App`: `AppModel` owns one long-lived model per game;
  `ContentView` switches the visible session without destroying other games.
- `Sources/PuzzleGames/Shared`: `PuzzleShellView` owns consistent header,
  difficulty picker, new/restart/undo/erase/notes controls, timer, completion
  sheet, game popover, keyboard monitoring, and check feedback. `PuzzleTheme`
  fixes the 844x690 window, 520 board, 220 controls, type, colors, and spacing.
- `PuzzleSession` is deliberately small but currently assumes number-entry
  puzzles (`values`, `solution`, number strip, notes). Skyscrapers maps directly;
  Slitherlink and Nurikabe need game-specific input/tool presentation while
  retaining the shell's common chrome. Do not create a universal puzzle engine.
- State is saved as per-game Codable JSON in `UserDefaults`; selected game is
  also persisted. Each model has a one-second timer, periodic autosave, undo,
  restart, completion presentation, and an optional deterministic seed for
  engine-backed tests where supported.
- Build/package scripts live in `PuzzleGames/Scripts`; product bundles go under
  `PuzzleGames/Artifacts`. No repository metadata is present in the supplied
  workspace (`git status` cannot run).

## How Sudoku works

- `SudokuGameModel` bridges the compact C API in `SudokuEngine.h`; C++ `CScene`
  owns values, givens, solution, command history, validation, generation, and an
  exact MRV backtracking solution counter capped at two.
- Generation creates a randomized full 9x9 solution and removes exactly
  20/35/50 cells for Easy/Medium/Hard, accepting each removal only while unique.
  This guarantees uniqueness but difficulty is clue-count based, not logical.
- Swift owns notes, selection, timer, completion sheet state, and persistence.
  Board UI shows given/player colors, peers, duplicates, notes, selected values,
  check feedback, accessibility, and 3x3 block lines.

## How Calcudoku works

- `CalcudokuGameModel` bridges `CalcudokuEngine` C, with app sizes 4/5/6 for the
  shared Easy/Medium/Hard labels. It persists cage metadata and validates saved
  games by loading them into the exact solver and requiring one solution.
- The engine generates a varied Latin grid, mutates contiguous cages, accepts
  only changes that increase its solver score, and verifies uniqueness with a
  solution counter capped at two. Difference/ratio cages are exactly two cells.
- The exact solver propagates row/column candidates and cage completion, uses
  MRV branching, and exposes a branch-weighted generation score. The board reuses
  Sudoku number/notes behavior but draws cage borders and operation clues.

## Existing product patterns to preserve

- Exactly three shared difficulty labels: Easy, Medium, Hard.
- One persistent model/session per game; switching games preserves each state.
- Same header, popover, board/control proportions, theme, timer, new-game,
  confirmation restart, undo, check, completion modal, keyboard conventions,
  accessibility, and autosave wording where semantically valid.
- The UI permits tentative/incorrect entries and highlights conflicts; it does
  not prevent experimentation. Completion is rule-based, not merely equality to
  a stored solution. Check feedback compares player state with the known unique
  solution.
- Seeds are internal/testing aids, never new user-facing UI.
- Prefer small shared shell primitives plus game-specific engines/models/views.

## Important files

- `PuzzleGames/Package.swift`
- `PuzzleGames/Sources/PuzzleGames/App/{AppModel,ContentView}.swift`
- `PuzzleGames/Sources/PuzzleGames/Shared/{PuzzleSession,PuzzleShellView,KeyboardInput,PuzzleTheme}.swift`
- `PuzzleGames/Sources/PuzzleGames/Games/Sudoku/*`
- `PuzzleGames/Sources/PuzzleGames/Games/Calcudoku/*`
- `PuzzleGames/Sources/{SudokuEngine,CalcudokuEngine}`
- `PuzzleGames/Tests/{PuzzleGamesTests,Native}`
- `PuzzleGames/Scripts/{test-native,build-macos,verify-macos}.sh`

## Architectural decisions taken

- Keep the existing SwiftUI app and shared visual shell. Extend it only with a
  narrowly scoped way for non-number games to supply their intrinsic controls,
  help text, and check semantics.
- Implement each new puzzle as an isolated engine/model/view group. Share only
  genuinely common grid/seed/session helpers discovered during implementation.
- Use deterministic seeded generators internally, bounded attempts, an exact
  solver that stops at two for uniqueness, and solver metrics for difficulty.
- Complete and validate games in the required order: Slitherlink, Skyscrapers,
  Nurikabe. Do not leave all three as scaffolds.

## Implementation plan

1. Adapt the common shell minimally for state/edge-based sessions while leaving
   Sudoku/Calcudoku behavior unchanged.
2. Slitherlink: exact solver with local clue/vertex propagation and single-loop
   global validation; seeded loop-first generator, clue minimization, logical/
   search metrics; model, persistence, edge interaction, integration, tests and
   stress tests.
3. Skyscrapers: permutation-based exact solver/propagator, varied Latin solution
   generator, clue removal with uniqueness, metric bands; Sudoku-like model/UI,
   outside clues, persistence, integration and stress tests.
4. Nurikabe: exact island/sea solver with island reachability, sea connectivity,
   2x2 prevention and capped search; solution-first seeded generator and unique
   clue puzzle; tri-state UI/model/persistence/integration and stress tests.
5. Exercise all five sessions, build, native tests, resizing/keyboard/UI checks.
6. Audit the complete folder for concrete simplifications, dead code, duplicated
   temporary helpers, warnings and performance issues; update documentation and
   mark this record complete.

## Completed tasks

- Read all user requirements.
- Mapped every source/test/script/assets area and inspected all Swift app/shared/
  game code plus native engine APIs and generation/solver implementations.
- Established clean baseline: `swift test` passed 15 tests on 2026-08-28;
  `./Scripts/test-native.sh` passed 90 generated Calcudokus and 90 generated
  Sudokus (and reported the intentionally non-unique legacy comparison sample).
- Created this continuation record before substantive changes.

## Current task

Phase B/C: identify the minimal reusable shell adaptation, then implement
Slitherlink completely from solver/generator through model/view/tests.

## Remaining tasks

- All implementation and validation steps 1-6 above.
- Update `README.md`, package configuration/test scripts if new engine targets are
  introduced, and final bundle artifacts only after verification.

## Known bugs/problems

- Baseline `swift test` cannot write the toolchain/module cache in the managed
  sandbox; it succeeds when run with approved elevated filesystem access.
- Existing generators execute synchronously from `@MainActor` initializers/new
  game actions. New engines must be bounded and fast; responsiveness must be
  measured before deciding whether a safe asynchronous session state is needed.
- Existing Sudoku difficulty is not logic-based despite its uniqueness guarantee.
  Do not regress it, but do not copy that weakness into the new games.
- The workspace has no usable `.git` directory, so changes must be tracked through
  filesystem inspection and this record rather than Git status/diffs.

## Tests and useful commands

From `PuzzleGames/`:

```sh
swift test
./Scripts/test-native.sh
./Scripts/build-macos.sh
./Scripts/verify-macos.sh "Artifacts/Puzzle Games.app"
```

Baseline results are recorded above. Add deterministic multi-seed tests for each
new solver/generator and model-flow tests mirroring the existing suites.

## Decisions that must not be reverted

- Do not replace the app, redesign it, add unrelated product features, expose
  seeds, or combine all games into a conditional universal engine.
- Preserve existing UserDefaults keys and Sudoku/Calcudoku saved-game compatibility.
- Preserve uniqueness checks and capped search on every generated/restored puzzle.
- Preserve independent live session state when switching between all five games.

## Points requiring verification

- Difficulty bands yield materially distinct solver work and Hard does not
  habitually fall back to easy puzzles.
- Worst-case generation latency stays reasonable on the main thread or is moved
  off it without breaking actor isolation/persistence.
- Edge hit targets and outside clue layout remain usable at the fixed 520 board;
  all views fit the existing 844x690 resizable-content window.
- Check feedback semantics for edge/cell-state games remain clear and consistent.

## Per-game status

- Slitherlink: audit/design complete; implementation not started.
- Skyscrapers: requirements mapped; implementation not started.
- Nurikabe: requirements mapped; implementation not started.

## General integration status

Baseline two-game integration understood and passing. No integration changes yet.

## Final simplification/refactor status

Not started; intentionally deferred until all three games are complete and stable.
