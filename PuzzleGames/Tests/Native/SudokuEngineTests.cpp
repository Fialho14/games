#include <cassert>
#include <iostream>
#include <vector>

#include "SudokuEngine.h"
#include "scene.h"

namespace {
int emptyCount(SudokuGameRef game) {
    int count = 0;
    for (int index = 0; index < 81; ++index)
        count += sudoku_value(game, index) == 0;
    return count;
}

void testDifficultyAndGivens(SudokuGameRef game) {
    const std::vector<std::pair<int, int>> cases = {{1, 20}, {2, 35}, {3, 50}};
    for (const auto& [difficulty, expectedEmpty] : cases) {
        sudoku_new_game(game, difficulty);
        assert(emptyCount(game) == expectedEmpty);
        for (int index = 0; index < 81; ++index) {
            if (sudoku_is_given(game, index)) {
                assert(sudoku_apply_value(game, index, 0) == 0);
                assert(sudoku_value(game, index) == sudoku_solution_value(game, index));
            }
        }
    }
}

void testRepeatedUniqueGeneration(SudokuGameRef game) {
    constexpr int puzzlesPerDifficulty = 30;
    for (int difficulty = 1; difficulty <= 3; ++difficulty) {
        for (int iteration = 0; iteration < puzzlesPerDifficulty; ++iteration) {
            sudoku_new_game(game, difficulty);
            assert(sudoku_solution_count(game, 2) == 1);
            for (int index = 0; index < 81; ++index) {
                const int value = sudoku_value(game, index);
                assert(value == 0 || value == sudoku_solution_value(game, index));
            }
        }
    }
    std::cout << "Verified 90 generated puzzles with exactly one solution.\n";
}

void testSolverLimitsAndInvalidBoards() {
    CScene scene;
    std::array<int, 81> values{};
    std::array<bool, 81> givens{};
    std::array<int, 81> solution{};
    scene.loadGame(values, givens, solution);
    assert(scene.countSolutions(2) == 2);

    values[0] = values[1] = 1;
    givens[0] = givens[1] = true;
    solution[0] = solution[1] = 1;
    scene.loadGame(values, givens, solution);
    assert(scene.countSolutions(2) == 0);
}

void sampleLegacyGenerator() {
    constexpr int samplesPerDifficulty = 50;
    const std::array<int, 3> erasedCounts = {20, 35, 50};
    std::array<int, 3> ambiguous{};
    for (size_t difficulty = 0; difficulty < erasedCounts.size(); ++difficulty) {
        for (int sample = 0; sample < samplesPerDifficulty; ++sample) {
            CScene legacy;
            legacy.generate();
            legacy.eraseRandomGrids(erasedCounts[difficulty]);
            if (legacy.countSolutions(2) != 1)
                ++ambiguous[difficulty];
        }
    }
    std::cout << "Legacy non-unique sample (50 each): Easy=" << ambiguous[0]
              << ", Medium=" << ambiguous[1] << ", Hard=" << ambiguous[2] << "\n";
}

void testInputUndoAndRestart(SudokuGameRef game) {
    sudoku_new_game(game, 2);
    int editable = -1;
    for (int index = 0; index < 81; ++index) {
        if (!sudoku_is_given(game, index)) {
            editable = index;
            break;
        }
    }
    assert(editable >= 0);
    const int answer = sudoku_solution_value(game, editable);
    assert(sudoku_apply_value(game, editable, answer) != 0);
    assert(sudoku_value(game, editable) == answer);
    assert(sudoku_undo(game) != 0);
    assert(sudoku_value(game, editable) == 0);
    assert(sudoku_undo(game) == 0);

    assert(sudoku_apply_value(game, editable, answer) != 0);
    sudoku_restart(game);
    assert(sudoku_value(game, editable) == 0);
}

void testConflicts(SudokuGameRef game) {
    sudoku_new_game(game, 3);
    int editable = -1;
    int duplicateValue = 0;
    for (int row = 0; row < 9 && editable < 0; ++row) {
        for (int column = 0; column < 9 && editable < 0; ++column) {
            const int index = row * 9 + column;
            if (sudoku_is_given(game, index)) continue;
            for (int peerColumn = 0; peerColumn < 9; ++peerColumn) {
                const int peerValue = sudoku_value(game, row * 9 + peerColumn);
                if (peerValue != 0) {
                    editable = index;
                    duplicateValue = peerValue;
                    break;
                }
            }
        }
    }
    assert(editable >= 0 && duplicateValue != 0);
    assert(sudoku_apply_value(game, editable, duplicateValue) != 0);
    assert(sudoku_has_conflict(game, editable) != 0);
    assert(sudoku_undo(game) != 0);
    assert(sudoku_has_conflict(game, editable) == 0);
}

void testCompletion(SudokuGameRef game) {
    sudoku_new_game(game, 3);
    for (int index = 0; index < 81; ++index) {
        if (!sudoku_is_given(game, index)) {
            assert(sudoku_apply_value(game, index, sudoku_solution_value(game, index)) != 0);
        }
    }
    assert(sudoku_is_complete(game) != 0);
}
}  // namespace

int main() {
    SudokuGameRef game = sudoku_create();
    assert(game);
    for (int iteration = 0; iteration < 5; ++iteration)
        testDifficultyAndGivens(game);
    testRepeatedUniqueGeneration(game);
    testSolverLimitsAndInvalidBoards();
    testInputUndoAndRestart(game);
    testConflicts(game);
    testCompletion(game);
    sampleLegacyGenerator();
    sudoku_destroy(game);
    std::cout << "All native engine tests passed.\n";
    return 0;
}
