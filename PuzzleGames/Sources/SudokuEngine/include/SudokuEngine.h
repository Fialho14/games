#ifndef SUDOKU_ENGINE_API_H
#define SUDOKU_ENGINE_API_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* SudokuGameRef;

SudokuGameRef sudoku_create(void);
void sudoku_destroy(SudokuGameRef game);
void sudoku_new_game(SudokuGameRef game, int difficulty);
void sudoku_load_game(SudokuGameRef game, const int* values,
                      const int* givens, const int* solution);
void sudoku_restart(SudokuGameRef game);
int sudoku_value(SudokuGameRef game, int index);
int sudoku_solution_value(SudokuGameRef game, int index);
int sudoku_is_given(SudokuGameRef game, int index);
int sudoku_apply_value(SudokuGameRef game, int index, int value);
int sudoku_undo(SudokuGameRef game);
int sudoku_has_conflict(SudokuGameRef game, int index);
int sudoku_is_complete(SudokuGameRef game);
int sudoku_solution_count(SudokuGameRef game, int limit);

#ifdef __cplusplus
}
#endif

#endif
