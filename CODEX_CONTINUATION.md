# PuzzleGames continuation record

STATUS: COMPLETE

## Global objective

Expand the existing native macOS PuzzleGames app so Slitherlink, Skyscrapers,
and Nurikabe feel native beside Sudoku and Calcudoku. Every new game must be
fully playable, persistent, procedurally generated, exactly solved/validated,
classified by meaningful solver work, tested across multiple deterministic
seeds, and integrated without regressions. Finish with a whole-project cleanup,
full build/test/stress verification, and set this file to `STATUS: COMPLETE`.

## Architecture discovered

- Swift 6 package at root `Package.swift`, macOS 14+, one SwiftUI
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
- Build/package scripts live in root `Scripts`; product bundles go under
  `Artifacts`. The root is the Git repository and the Swift package; the former
  redundant `PuzzleGames/` nesting was removed in the final organization pass.

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

- `Package.swift`
- `Sources/PuzzleGames/App/{AppModel,ContentView}.swift`
- `Sources/PuzzleGames/Shared/{PuzzleSession,PuzzleInputStyle,PuzzleShellView,KeyboardInput,PuzzleTheme}.swift`
- `Sources/PuzzleGames/Games/<Game>/*`
- `Sources/{SudokuEngine,CalcudokuEngine}`
- `Tests/{PuzzleGamesTests/Games,PuzzleGamesTests/Integration,Native}`
- `Scripts/{check-project,test-native,build-macos,verify-macos}.sh`
- `AGENTS.md` and `Documentation/ADDING_A_GAME.md`

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
- `Archive/Reference/` is optional, untrusted research material and
  must remain outside every target/runtime dependency. Ideas may be independently
  reimplemented only after mathematical review and project-native tests; do not
  copy source merely because its BSD/Apache/MIT license permits reuse.

## Optional reference-code review

- `Archive/Reference/slitherlink-master` (BSD): reviewed the Haskell solver/generator.
  It represents per-cell/per-vertex pattern domains, tracks open path endpoints,
  rejects a loop closing while other line pieces exist, generates a region
  boundary, then removes clues while exact uniqueness remains. These independently
  corroborate the current project approach. No source was copied and no rewrite
  was warranted; current Swift tests already cover multiple loops and uniqueness.
- `Archive/Reference/C-Skysrcaper-Puzzle-main` (Apache-2.0): reviewed before beginning
  Skyscrapers. It is fixed at 4x4, returns only the first backtracking solution,
  has no solution counter, generator, difficulty model, partial visibility-domain
  propagation, or uniqueness guarantee. It is unsuitable for integration and no
  code/algorithm was taken. The planned permutation-domain solver is materially
  stronger and remains the project design.
- `Archive/Reference/nurikabe-main` (MIT) exists but has not yet been inspected beyond
  license/README; its region-based C++ solver was later reviewed selectively.
  Useful conceptual checks were complete-island frontiers, unreachable cells,
  single liberties, pool prevention, confinement/connectivity, and ordering cheap
  deductions before hypotheticals. These ideas were independently represented in
  the Swift solver; no source was copied and the reference remains outside build.

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
- Confirmed this record against the real filesystem after the continuation
  handoff; all described Slitherlink source/test/integration files are present.
- Added a minimal `PuzzleInputStyle` extension to the shared session/shell so
  number games remain unchanged while edge/cell-state games get intrinsic tools.
- Implemented Slitherlink end-to-end in `Games/Slitherlink`: deterministic
  loop-first polyomino-boundary generation with diagonal-pinch rejection, clue
  derivation/removal guarded by exact uniqueness checks, exact capped solver with
  clue and vertex propagation plus global single-loop validation, solver work
  metrics, persistent session, undo/restart/timer/check/completion, accessible
  edge UI with line/X states, and app/game-menu integration.
- Added `SlitherlinkEngineTests` and `SlitherlinkGameModelTests`: known unique,
  invalid and ambiguous cases; disconnected-loop/branch rejection; 12 generated
  puzzles across all difficulties/seeds; uniqueness, invariant, metric-gradient,
  model flow, persistence, check, restart, undo and completion tests. All five
  new tests pass; the pre-existing 15 tests also remained green on integration.
- Completed Skyscrapers in `Games/Skyscrapers`: randomized backtracking Latin
  solutions (not a fixed cyclic grid), complete visibility derivation, exact
  row/column permutation-domain propagation and capped counting, bounded search
  for uniquely determined bases, clue removal guarded by uniqueness, measured
  difficulty, full number/notes model, persistence and outside-clue SwiftUI.
- Added four Skyscrapers tests. Nine generated puzzles are checked across all
  difficulty/seed combinations with a separately implemented row-domain counter,
  plus unique/invalid/ambiguous fixtures, visibility, variety/rating and complete
  model flow. Release build and real macOS visual inspection passed.
- Completed Nurikabe in `Games/Nurikabe`: exact capped solver covering island
  sizes/owners/reachability, completed islands, separation, total counts, sea
  potential connectivity/liberties and 2x2 pools; solution-first generator builds
  a connected acyclic sea (therefore no 2x2), derives island clues, and accepts
  only exact unique puzzles; persistent tri-state model and Sea/Island grid UI.
- Fixed two order-dependent Nurikabe propagation bugs by restarting after stale
  island reachability changes and applying sea-component liberties from one
  snapshot. Regression seeds now repeatedly return the same unique solution.
  Nine multi-seed puzzles plus two repeated regressions and model-flow tests pass.
- All five games now build in one signed/relocatable macOS bundle. Slitherlink,
  Skyscrapers and Nurikabe were each inspected in the real 844x690 app window.
- Slitherlink keyboard navigation supports rotating only the currently selected
  edge by 90 degrees with either Shift key. Interior edges alternate between the
  horizontal/vertical edges sharing their top-left vertex; boundary selections
  clamp to the nearest valid perpendicular edge. Rotation changes no puzzle mark,
  persists the new selection, and is a no-op in every other game.
- Spotlight indexes `~/Applications/Puzzle Games.app`, so leaving only a newer
  `Artifacts` bundle creates a recurring stale-launch bug. Local builds now call
  `Scripts/install-macos.sh`, which stages/verifies the new bundle, sends the old
  installed copy to Trash, installs/verifies the replacement and refreshes the
  Spotlight index. It first closes any running app copy and refuses replacement
  if that process does not exit, preventing an old executable from remaining in
  memory. CI skips this user-facing installation. Future sessions must relaunch
  and inspect the installed copy, not an older duplicate.
- Added `GameIntegrationTests` to cycle all registered game kinds, preserve each
  long-lived model's independent state and restore the selected game.
- Updated `README.md` for the five-game product and completed the full-folder
  simplification/dead-code/documentation audit.

## Current task

Complete. The requested five-game expansion and the subsequent root-folder/
extensibility organization pass were finished on 2026-08-29.

## Remaining tasks

None for the requested scope.

## Resolved findings and limitations

- The current unrestricted workspace runs `swift test` normally; the earlier
  managed-sandbox module-cache restriction is not a product defect.
- Generators execute synchronously from `@MainActor` initializers/new-game
  actions, matching the existing architecture. All new engines are attempt-
  bounded and sampled responsiveness did not justify a risky actor rewrite.
- Existing Sudoku difficulty is not logic-based despite its uniqueness guarantee.
  Do not regress it, but do not copy that weakness into the new games.
- The workspace now has a usable root `.git` directory. The expansion and
  organization work remains deliberately uncommitted for user review.
- Continuation audit found that raw Slitherlink search metrics could overlap:
  a four-seed sample averaged Medium 9158.5 and Hard 8174 despite their larger,
  sparser Hard grids. Difficulty scoring now combines explicit grid-scale
  connectivity cost with measured propagation/search work; the multi-seed
  gradient passes.
- Initial Skyscrapers stress test exposed seed `530003`: six randomly generated
  6x6 Latin Squares all remained ambiguous even with every outside clue, causing
  bounded generation to fail. The generator now distinguishes
  cheap base-grid attempts (up to 128) from accepted unique candidates (4/6),
  never attempting clue removal until full-clue uniqueness is proven. Regression
  is fixed and all sampled seeds pass.
- First Nurikabe stress run exposed order-dependent solver behavior: generated
  puzzles could re-solve as 0/2 solutions because propagation continued using
  stale island/sea component maps after forced assignments. Each mutating phase
  now restarts propagation before further deductions. The same run
  took 86.9 s, partly due to an intentionally independent 2^N exhaustive check;
  that brute-force test was removed; repeatability and invariant stress tests now
  cover the exact solver without making the suite impractically slow.
- Generation remains synchronous, as in the original app, but every generator is
  attempt-bounded and the sampled full suite completes reliably. As with any
  bounded procedural search, an exceptionally unlucky unsampled seed can fail
  rather than loop forever; deterministic regression seeds cover the failures
  discovered during development.

## Tests and useful commands

From the repository root:

```sh
swift test
./Scripts/test-native.sh
./Scripts/check-project.sh --bundle
./Scripts/build-macos.sh
./Scripts/verify-macos.sh "Artifacts/Puzzle Games.app"
```

Final results on 2026-08-29:

- `swift test`: 31 tests, 0 failures in 37.263 s. This includes deterministic
  multi-seed uniqueness/difficulty checks, invalid and ambiguous fixtures,
  model/persistence flows, and five-game state/menu switching.
- `./Scripts/test-native.sh`: 90 exact valid Calcudoku puzzles and 90 unique
  Sudoku puzzles verified; all native tests passed.
- `swift build -Xswiftc -warnings-as-errors`: passed with no warnings.
- `./Scripts/build-macos.sh`: Release build, signature, installed-path copy,
  relocated copy and ZIP extraction all verified.
- Final products: `Artifacts/Puzzle Games.app` and `Artifacts/Puzzle Games.zip`.

The subsequent organization/extensibility pass was validated with the new
canonical `./Scripts/check-project.sh --bundle` command: 31 Swift tests passed
with warnings as errors (0 failures in 46.422 s), both native 90-puzzle suites
passed, the Release product built, staging/relocated/ZIP copies passed strict
signature and dependency checks, and the final app launched successfully. The
Desktop File Provider can recreate `com.apple.FinderInfo` on the visible `.app`
after signing; the build now normalizes and verifies that delivery copy
immediately, while the transport ZIP remains the durable fully strict artifact.

The Slitherlink Shift-selection feature was then validated with the same full
gate: 33 Swift tests passed with warnings as errors (0 failures in 26.942 s),
including left/right Shift mapping, key release, interior/boundary rotation and
mark preservation; both native suites and every bundle verification also passed.

## Decisions that must not be reverted

- Do not replace the app, redesign it, add unrelated product features, expose
  seeds, or combine all games into a conditional universal engine.
- Preserve existing UserDefaults keys and Sudoku/Calcudoku saved-game compatibility.
- Preserve uniqueness checks and capped search on every generated/restored puzzle.
- Preserve independent live session state when switching between all five games.

## Final audit conclusions

- Difficulty tests combine structural scale with measured propagation/search
  work and pass across the deterministic seed matrix.
- The generators are bounded and their sampled latency is acceptable for the
  existing synchronous session architecture; no risky actor/persistence rewrite
  was justified.
- Edge hit targets, outside clues, tri-state cells and all controls were inspected
  in the real fixed-size macOS window and fit the established layout.
- Check feedback deliberately ignores unknown/tentative state and flags only
  explicit wrong marks, matching the number-game experimentation model.
- A five-game integration regression proves each long-lived session preserves
  independent state while the menu cycles through every `GameKind`.
- Shared code was limited to the seed generator and input-style shell seam;
  solver/model/view logic remains game-specific instead of becoming a universal
  conditional engine.
- `README.md` now documents all five games, rules, controls, generation,
  structure, tests, build outputs and the non-runtime status of
  `Archive/Reference/`.
- The obsolete `Artifacts/Puzzle Games 2.app` duplicate was moved to macOS Trash
  (recoverable); only the canonical app and transport ZIP remain in Artifacts.

## Per-game status

- Slitherlink: complete; automated tests, Release build and visual check pass.
- Skyscrapers: complete; independent uniqueness/property/model tests, Release
  build and visual check pass.
- Nurikabe: complete; property/repeatability/model tests, Release build and visual
  check pass.

## General integration status

All five games are registered with independent persistent models. Shared shell
supports number, edge and cell-state controls. Signed bundle and individual new
game visual checks pass; combined regression and final verification pass.

## Final simplification/refactor status

Complete. The Git root is now also the Swift package root; active code, tests,
scripts, assets and bundle configuration are top-level, while historical and
external sources are isolated under `Archive/`. Tests mirror the source game
folders. Common mechanics remain in the shell/session seam and seeded RNG;
domain-specific engines, state and rendering stay isolated per game. Two-state
games provide data-driven `PuzzleInputStyle` controls, so the shell no longer
contains game-named input branches. `AGENTS.md`, an addition checklist and one
strict verification command make future Codex extensions predictable. Temporary
search code, duplicate icon source, stale artifact links, generated cache and the
obsolete duplicate bundle were removed.
