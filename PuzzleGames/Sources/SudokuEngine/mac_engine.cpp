#include "include/SudokuEngine.h"

#include <array>

#include "scene.h"

namespace {
CScene* scene(SudokuGameRef game) { return static_cast<CScene*>(game); }
point_t pointForIndex(int index) { return {index % 9, index / 9}; }
bool validIndex(int index) { return index >= 0 && index < 81; }
}  // namespace

SudokuGameRef sudoku_create(void) { return new CScene(); }
void sudoku_destroy(SudokuGameRef game) { delete scene(game); }

void sudoku_new_game(SudokuGameRef game, int difficulty) {
    if (!game) return;
    if (difficulty < static_cast<int>(Difficulty::EASY) ||
        difficulty > static_cast<int>(Difficulty::HARD))
        difficulty = static_cast<int>(Difficulty::NORMAL);
    scene(game)->newGame(static_cast<Difficulty>(difficulty));
}

void sudoku_load_game(SudokuGameRef game, const int* values,
                      const int* givens, const int* solution) {
    if (!game || !values || !givens || !solution) return;
    std::array<int, 81> loadedValues{};
    std::array<bool, 81> loadedGivens{};
    std::array<int, 81> loadedSolution{};
    for (int index = 0; index < 81; ++index) {
        loadedValues[index] = values[index];
        loadedGivens[index] = givens[index] != 0;
        loadedSolution[index] = solution[index];
    }
    scene(game)->loadGame(loadedValues, loadedGivens, loadedSolution);
}

void sudoku_restart(SudokuGameRef game) {
    if (game) scene(game)->restart();
}

int sudoku_value(SudokuGameRef game, int index) {
    return game && validIndex(index)
        ? scene(game)->getPointValue(pointForIndex(index)) : 0;
}

int sudoku_solution_value(SudokuGameRef game, int index) {
    return game && validIndex(index)
        ? scene(game)->getSolutionValue(pointForIndex(index)) : 0;
}

int sudoku_is_given(SudokuGameRef game, int index) {
    return game && validIndex(index) && scene(game)->isGiven(pointForIndex(index));
}

int sudoku_apply_value(SudokuGameRef game, int index, int value) {
    return game && validIndex(index) && scene(game)->applyValue(pointForIndex(index), value);
}

int sudoku_undo(SudokuGameRef game) { return game && scene(game)->undoLast(); }

int sudoku_has_conflict(SudokuGameRef game, int index) {
    return game && validIndex(index) && scene(game)->hasConflict(pointForIndex(index));
}

int sudoku_is_complete(SudokuGameRef game) {
    return game && scene(game)->isComplete();
}

int sudoku_solution_count(SudokuGameRef game, int limit) {
    return game ? scene(game)->countSolutions(limit) : 0;
}
