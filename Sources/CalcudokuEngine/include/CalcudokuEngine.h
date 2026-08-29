#ifndef CALCUDOKU_ENGINE_API_H
#define CALCUDOKU_ENGINE_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *CalcudokuGameRef;

enum {
    CALCUDOKU_OPERATION_NONE = 0,
    CALCUDOKU_OPERATION_SUM = '+',
    CALCUDOKU_OPERATION_DIFFERENCE = '-',
    CALCUDOKU_OPERATION_PRODUCT = '*',
    CALCUDOKU_OPERATION_RATIO = '/'
};

CalcudokuGameRef calcudoku_create(void);
void calcudoku_destroy(CalcudokuGameRef game);
void calcudoku_seed(CalcudokuGameRef game, uint64_t seed);

/* Difficulty 1/2/3 maps to 4x4, 5x5 and 6x6 respectively. */
int calcudoku_new_game(CalcudokuGameRef game, int difficulty);

/* Restore a puzzle from compact row-major arrays of size * size cells.
 * Cage target and operation are repeated for every cell in a cage. Cage IDs
 * only need to be non-negative and equal for members of the same cage.
 */
int calcudoku_load_game(CalcudokuGameRef game, int size,
                        const int *values, const int *solution,
                        const int *cage_ids, const int *cage_targets,
                        const int *cage_operations);

void calcudoku_restart(CalcudokuGameRef game);
int calcudoku_size(CalcudokuGameRef game);
int calcudoku_value(CalcudokuGameRef game, int index);
int calcudoku_solution_value(CalcudokuGameRef game, int index);
int calcudoku_apply_value(CalcudokuGameRef game, int index, int value);

int calcudoku_cage_id(CalcudokuGameRef game, int index);
int calcudoku_cage_target(CalcudokuGameRef game, int index);
int calcudoku_cage_operation(CalcudokuGameRef game, int index);
int calcudoku_cage_anchor(CalcudokuGameRef game, int index);

int calcudoku_has_row_conflict(CalcudokuGameRef game, int index);
int calcudoku_has_column_conflict(CalcudokuGameRef game, int index);
int calcudoku_has_cage_conflict(CalcudokuGameRef game, int index);
int calcudoku_is_complete(CalcudokuGameRef game);
int calcudoku_solution_count(CalcudokuGameRef game, int limit);
int calcudoku_generation_score(CalcudokuGameRef game);

#ifdef __cplusplus
}
#endif

#endif
