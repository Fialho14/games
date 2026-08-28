#include "include/CalcudokuEngine.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cdok.h"
#include "generator.h"
#include "solver.h"

#define CALCUDOKU_MAX_APP_SIZE 6

struct calcudoku_game {
    struct cdok_puzzle puzzle;
    struct cdok_rng rng;
    uint8_t solution[CDOK_CELLS];
    uint8_t values[CDOK_CELLS];
    int cage_ids[CDOK_CELLS];
    int cage_targets[CDOK_CELLS];
    int cage_operations[CDOK_CELLS];
    uint8_t cage_anchors[CDOK_CELLS];
    int score;
};

struct loaded_cage {
    int source_id;
    int target;
    int operation;
    unsigned int count;
    cdok_pos_t members[CDOK_GROUP_SIZE];
};

static struct calcudoku_game *typed(CalcudokuGameRef game)
{
    return (struct calcudoku_game *)game;
}

static int compact_cell(const struct calcudoku_game *game, int index,
                        cdok_pos_t *cell)
{
    const int size = game ? (int)game->puzzle.size : 0;

    if (!game || index < 0 || index >= size * size)
        return 0;
    if (cell)
        *cell = CDOK_POS(index % size, index / size);
    return 1;
}

static int operation_is_valid(int operation)
{
    return operation == CALCUDOKU_OPERATION_SUM ||
           operation == CALCUDOKU_OPERATION_DIFFERENCE ||
           operation == CALCUDOKU_OPERATION_PRODUCT ||
           operation == CALCUDOKU_OPERATION_RATIO;
}

static int cage_result_is_valid(int target, int operation,
                                const int *values, unsigned int count)
{
    unsigned int i;
    uint64_t sum = 0;
    uint64_t product = 1;

    if (count == 1)
        return operation == CALCUDOKU_OPERATION_NONE && values[0] == target;
    for (i = 0; i < count; i++) {
        sum += (unsigned int)values[i];
        product *= (unsigned int)values[i];
    }
    switch (operation) {
    case CALCUDOKU_OPERATION_SUM:
        return sum == (uint64_t)target;
    case CALCUDOKU_OPERATION_DIFFERENCE:
        return count == 2 &&
               abs(values[0] - values[1]) == target;
    case CALCUDOKU_OPERATION_PRODUCT:
        return product == (uint64_t)target;
    case CALCUDOKU_OPERATION_RATIO: {
        const int high = values[0] > values[1] ? values[0] : values[1];
        const int low = values[0] > values[1] ? values[1] : values[0];

        return count == 2 && low > 0 && high % low == 0 && high / low == target;
    }
    default:
        return 0;
    }
}

static int partial_cage_recurse(int target, int operation, int size,
                                int *values, unsigned int count,
                                unsigned int index)
{
    int candidate;

    while (index < count && values[index] != 0)
        index++;
    if (index == count)
        return cage_result_is_valid(target, operation, values, count);
    for (candidate = 1; candidate <= size; candidate++) {
        values[index] = candidate;
        if (partial_cage_recurse(target, operation, size, values, count,
                                 index + 1)) {
            values[index] = 0;
            return 1;
        }
    }
    values[index] = 0;
    return 0;
}

static int metadata_from_puzzle(struct calcudoku_game *game)
{
    const int size = (int)game->puzzle.size;
    int next_id = 0;
    int index;

    memset(game->cage_ids, 0xff, sizeof(game->cage_ids));
    memset(game->cage_targets, 0, sizeof(game->cage_targets));
    memset(game->cage_operations, 0, sizeof(game->cage_operations));
    memset(game->cage_anchors, 0, sizeof(game->cage_anchors));

    for (index = 0; index < size * size; index++) {
        const cdok_pos_t cell = CDOK_POS(index % size, index / size);
        const uint8_t group_index = game->puzzle.group_map[cell];
        unsigned int member_index;

        if (game->cage_ids[cell] >= 0)
            continue;
        if (group_index == CDOK_GROUP_NONE) {
            if (game->puzzle.values[cell] < 1 ||
                game->puzzle.values[cell] > size)
                return 0;
            game->cage_ids[cell] = next_id++;
            game->cage_targets[cell] = game->puzzle.values[cell];
            game->cage_operations[cell] = CALCUDOKU_OPERATION_NONE;
            game->cage_anchors[cell] = 1;
            continue;
        }

        {
            const struct cdok_group *group =
                &game->puzzle.groups[group_index];
            int anchor_index = size * size;

            for (member_index = 0; member_index < group->size;
                 member_index++) {
                const cdok_pos_t member = group->members[member_index];
                const int compact = CDOK_POS_Y(member) * size +
                                    CDOK_POS_X(member);

                game->cage_ids[member] = next_id;
                game->cage_targets[member] = group->target;
                game->cage_operations[member] = (int)group->type;
                if (compact < anchor_index)
                    anchor_index = compact;
            }
            game->cage_anchors[CDOK_POS(anchor_index % size,
                                        anchor_index / size)] = 1;
            next_id++;
        }
    }
    return 1;
}

CalcudokuGameRef calcudoku_create(void)
{
    struct calcudoku_game *game = calloc(1, sizeof(*game));
    const uint64_t seed = (uint64_t)time(NULL) ^ (uint64_t)(uintptr_t)game;

    if (!game)
        return NULL;
    cdok_rng_seed(&game->rng, seed);
    cdok_init_puzzle(&game->puzzle, 0);
    return game;
}

void calcudoku_destroy(CalcudokuGameRef game)
{
    free(game);
}

void calcudoku_seed(CalcudokuGameRef game_ref, uint64_t seed)
{
    struct calcudoku_game *game = typed(game_ref);

    if (game)
        cdok_rng_seed(&game->rng, seed);
}

int calcudoku_new_game(CalcudokuGameRef game_ref, int difficulty)
{
    struct calcudoku_game *game = typed(game_ref);
    int size;
    int iterations;
    int attempt;

    if (!game || difficulty < 1 || difficulty > 3)
        return 0;
    size = difficulty + 3;
    iterations = difficulty == 1 ? 14 : (difficulty == 2 ? 20 : 28);

    for (attempt = 0; attempt < 32; attempt++) {
        int count;

        if (cdok_generate_grid(game->solution, size, &game->rng) < 0)
            continue;
        game->score = cdok_generate(&game->puzzle, game->solution, size,
                                    CDOK_FLAGS_TWO_CELL, iterations, 0, 0,
                                    &game->rng);
        if (game->score < 0 || cdok_validate_puzzle(&game->puzzle) < 0)
            continue;
        count = cdok_count_solutions(&game->puzzle, game->solution, 2, NULL);
        if (count != 1 || !metadata_from_puzzle(game))
            continue;
        memset(game->values, 0, sizeof(game->values));
        return 1;
    }
    return 0;
}

static int find_loaded_cage(struct loaded_cage *cages, int cage_count,
                            int source_id)
{
    int index;

    for (index = 0; index < cage_count; index++)
        if (cages[index].source_id == source_id)
            return index;
    return -1;
}

int calcudoku_load_game(CalcudokuGameRef game_ref, int size,
                        const int *values, const int *solution,
                        const int *cage_ids, const int *cage_targets,
                        const int *cage_operations)
{
    struct calcudoku_game *game = typed(game_ref);
    struct cdok_puzzle puzzle;
    struct loaded_cage cages[CALCUDOKU_MAX_APP_SIZE * CALCUDOKU_MAX_APP_SIZE];
    uint8_t solved[CDOK_CELLS];
    int cage_count = 0;
    int group_count = 0;
    int index;

    if (!game || size < 2 || size > CALCUDOKU_MAX_APP_SIZE || !values ||
        !solution || !cage_ids || !cage_targets || !cage_operations)
        return 0;
    memset(cages, 0, sizeof(cages));
    cdok_init_puzzle(&puzzle, size);

    for (index = 0; index < size * size; index++) {
        const int source_id = cage_ids[index];
        const int target = cage_targets[index];
        const int operation = cage_operations[index];
        int cage_index;

        if (source_id < 0 || target < 1 || values[index] < 0 ||
            values[index] > size || solution[index] < 1 ||
            solution[index] > size)
            return 0;
        cage_index = find_loaded_cage(cages, cage_count, source_id);
        if (cage_index < 0) {
            if (cage_count >= size * size)
                return 0;
            cage_index = cage_count++;
            cages[cage_index].source_id = source_id;
            cages[cage_index].target = target;
            cages[cage_index].operation = operation;
        } else if (cages[cage_index].target != target ||
                   cages[cage_index].operation != operation) {
            return 0;
        }
        if (cages[cage_index].count >= CDOK_GROUP_SIZE)
            return 0;
        cages[cage_index].members[cages[cage_index].count++] =
            CDOK_POS(index % size, index / size);
    }

    for (index = 0; index < cage_count; index++) {
        struct loaded_cage *loaded = &cages[index];
        unsigned int member_index;

        if (loaded->count == 1) {
            if (loaded->operation != CALCUDOKU_OPERATION_NONE ||
                loaded->target > size)
                return 0;
            puzzle.values[loaded->members[0]] = (uint8_t)loaded->target;
            continue;
        }
        if (!operation_is_valid(loaded->operation) ||
            ((loaded->operation == CALCUDOKU_OPERATION_DIFFERENCE ||
              loaded->operation == CALCUDOKU_OPERATION_RATIO) &&
             loaded->count != 2) || group_count >= CDOK_GROUPS)
            return 0;
        puzzle.groups[group_count].type = (cdok_gtype_t)loaded->operation;
        puzzle.groups[group_count].target = loaded->target;
        puzzle.groups[group_count].size = loaded->count;
        for (member_index = 0; member_index < loaded->count;
             member_index++) {
            const cdok_pos_t cell = loaded->members[member_index];

            puzzle.groups[group_count].members[member_index] = cell;
            puzzle.group_map[cell] = (uint8_t)group_count;
        }
        group_count++;
    }

    if (cdok_validate_puzzle(&puzzle) < 0 ||
        cdok_count_solutions(&puzzle, solved, 2, NULL) != 1)
        return 0;
    for (index = 0; index < size * size; index++) {
        const cdok_pos_t cell = CDOK_POS(index % size, index / size);

        if (solution[index] != solved[cell])
            return 0;
    }

    game->puzzle = puzzle;
    memcpy(game->solution, solved, sizeof(game->solution));
    memset(game->values, 0, sizeof(game->values));
    for (index = 0; index < size * size; index++)
        game->values[CDOK_POS(index % size, index / size)] =
            (uint8_t)values[index];
    game->score = 0;
    return metadata_from_puzzle(game);
}

void calcudoku_restart(CalcudokuGameRef game_ref)
{
    struct calcudoku_game *game = typed(game_ref);

    if (game)
        memset(game->values, 0, sizeof(game->values));
}

int calcudoku_size(CalcudokuGameRef game_ref)
{
    const struct calcudoku_game *game = typed(game_ref);

    return game ? (int)game->puzzle.size : 0;
}

int calcudoku_value(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->values[cell] : 0;
}

int calcudoku_solution_value(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->solution[cell] : 0;
}

int calcudoku_apply_value(CalcudokuGameRef game_ref, int index, int value)
{
    struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    if (!compact_cell(game, index, &cell) || value < 0 ||
        value > (int)game->puzzle.size)
        return 0;
    game->values[cell] = (uint8_t)value;
    return 1;
}

int calcudoku_cage_id(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->cage_ids[cell] : -1;
}

int calcudoku_cage_target(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->cage_targets[cell] : 0;
}

int calcudoku_cage_operation(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->cage_operations[cell] : 0;
}

int calcudoku_cage_anchor(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;

    return compact_cell(game, index, &cell) ? game->cage_anchors[cell] : 0;
}

int calcudoku_has_row_conflict(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;
    int x;
    int value;

    if (!compact_cell(game, index, &cell) || !(value = game->values[cell]))
        return 0;
    for (x = 0; x < (int)game->puzzle.size; x++) {
        const cdok_pos_t other = CDOK_POS(x, CDOK_POS_Y(cell));

        if (other != cell && game->values[other] == value)
            return 1;
    }
    return 0;
}

int calcudoku_has_column_conflict(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;
    int y;
    int value;

    if (!compact_cell(game, index, &cell) || !(value = game->values[cell]))
        return 0;
    for (y = 0; y < (int)game->puzzle.size; y++) {
        const cdok_pos_t other = CDOK_POS(CDOK_POS_X(cell), y);

        if (other != cell && game->values[other] == value)
            return 1;
    }
    return 0;
}

int calcudoku_has_cage_conflict(CalcudokuGameRef game_ref, int index)
{
    const struct calcudoku_game *game = typed(game_ref);
    cdok_pos_t cell;
    int cage_id;
    int trial[CDOK_GROUP_SIZE] = {0};
    unsigned int count = 0;
    int compact;

    if (!compact_cell(game, index, &cell))
        return 0;
    cage_id = game->cage_ids[cell];
    for (compact = 0; compact < (int)(game->puzzle.size * game->puzzle.size);
         compact++) {
        const cdok_pos_t member =
            CDOK_POS(compact % (int)game->puzzle.size,
                     compact / (int)game->puzzle.size);

        if (game->cage_ids[member] == cage_id)
            trial[count++] = game->values[member];
    }
    if (!count || count > CDOK_GROUP_SIZE)
        return 1;
    return !partial_cage_recurse(game->cage_targets[cell],
                                 game->cage_operations[cell],
                                 (int)game->puzzle.size, trial, count, 0);
}

int calcudoku_is_complete(CalcudokuGameRef game_ref)
{
    const struct calcudoku_game *game = typed(game_ref);
    int index;

    if (!game)
        return 0;
    for (index = 0; index < (int)(game->puzzle.size * game->puzzle.size);
         index++) {
        if (!calcudoku_value(game_ref, index) ||
            calcudoku_has_row_conflict(game_ref, index) ||
            calcudoku_has_column_conflict(game_ref, index) ||
            calcudoku_has_cage_conflict(game_ref, index))
            return 0;
    }
    return 1;
}

int calcudoku_solution_count(CalcudokuGameRef game_ref, int limit)
{
    const struct calcudoku_game *game = typed(game_ref);

    return game ? cdok_count_solutions(&game->puzzle, NULL, limit, NULL) : -1;
}

int calcudoku_generation_score(CalcudokuGameRef game_ref)
{
    const struct calcudoku_game *game = typed(game_ref);

    return game ? game->score : 0;
}
