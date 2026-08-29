# Adding a puzzle game

The app deliberately uses a small shared shell and game-specific implementations.
This checklist is the shortest safe path for adding another game without coupling
it to the existing five.

## 1. Define the puzzle contract

Before UI work, write down the complete mathematical rules, including global
constraints. Decide how a finished board is validated and how an exact solver
can count zero, one or at least two solutions. The uniqueness search must stop at
two and generation must have explicit attempt limits.

## 2. Add one self-contained game directory

Create `Sources/PuzzleGames/Games/<Game>/` with only the files the game needs:

- `<Game>Engine.swift`: puzzle representation, exact solver/validator, bounded
  seeded generator and measured difficulty;
- `<Game>GameModel.swift`: `PuzzleSession`, selection/input, undo, timer,
  persistence, check and completion;
- `<Game>BoardView.swift`: game-specific rendering and pointer interaction.

An engine can instead be a small C/C++ target beside `Sources/SudokuEngine` when
there is a concrete performance or reuse benefit. Expose only a narrow C API and
register the target in `Package.swift`.

Do not place game rules in `PuzzleShellView`, `AppModel` or `ContentView`.

## 3. Reuse the shell at the correct level

`PuzzleSession` supplies lifecycle and input operations common to every game.
Choose one control configuration:

- `.numbers` for Sudoku-like number entry and notes;
- `.twoState(TwoStateInputStyle(...))` for two marking tools plus erase.

Only extend this seam when a new game truly needs a different interaction model.
Add reusable presentation data, not a switch case named after the game.

## 4. Register the game

There are three intentional compile-time registration points:

1. add metadata to `GameKind`;
2. add one long-lived model to `AppModel`;
3. add one `PuzzleShellView` branch to `ContentView`.

This explicit wiring keeps concrete models strongly typed and observable. Avoid
type erasure or a global service locator merely to remove these three lines of
responsibility.

Use a new, versioned `UserDefaults` key. Never change keys belonging to another
game. Restored puzzles must be rejected if dimensions, rules or exact uniqueness
validation fail.

## 5. Mirror the source in tests

Create `Tests/PuzzleGamesTests/Games/<Game>/` and cover:

- known valid, invalid, unique and ambiguous fixtures;
- every global rule, not only local clue checks;
- deterministic multi-seed generation for every difficulty;
- exact uniqueness and agreement with the stored solution;
- meaningful difficulty separation and variety;
- input, undo, erase, restart, persistence, check and completion.

Update the integration test so cycling through every `GameKind` proves that the
new session and all existing sessions retain independent state.

## 6. Finish as a product feature

Update `README.md` and `CODEX_CONTINUATION.md`, inspect the real macOS window and
run the complete gate:

```sh
./Scripts/check-project.sh --bundle
```

A game is complete only when this passes and the app remains independent of
everything under `Archive/`.
