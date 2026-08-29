#include <stdio.h>
#include <stdlib.h>

#include "CalcudokuEngine.h"

#define CHECK(condition)                                                       \
    do {                                                                       \
        if (!(condition)) {                                                    \
            fprintf(stderr, "Check failed at %s:%d: %s\n", __FILE__,         \
                    __LINE__, #condition);                                     \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

static int operation_holds(int operation, int target, const int *values,
                           int count)
{
    int sum = 0;
    int product = 1;
    int i;

    if (count == 1)
        return operation == CALCUDOKU_OPERATION_NONE && values[0] == target;
    for (i = 0; i < count; i++) {
        sum += values[i];
        product *= values[i];
    }
    if (operation == CALCUDOKU_OPERATION_SUM)
        return sum == target;
    if (operation == CALCUDOKU_OPERATION_PRODUCT)
        return product == target;
    if (operation == CALCUDOKU_OPERATION_DIFFERENCE)
        return count == 2 && abs(values[0] - values[1]) == target;
    if (operation == CALCUDOKU_OPERATION_RATIO) {
        const int high = values[0] > values[1] ? values[0] : values[1];
        const int low = values[0] > values[1] ? values[1] : values[0];

        return count == 2 && low && high % low == 0 && high / low == target;
    }
    return 0;
}

static void verify_cage_geometry(CalcudokuGameRef game, int cage_id)
{
    const int size = calcudoku_size(game);
    int queue[36];
    int seen[36] = {0};
    int head = 0;
    int tail = 0;
    int expected = 0;
    int index;

    for (index = 0; index < size * size; index++) {
        if (calcudoku_cage_id(game, index) != cage_id)
            continue;
        expected++;
        if (!tail) {
            queue[tail++] = index;
            seen[index] = 1;
        }
    }
    while (head < tail) {
        const int cell = queue[head++];
        const int row = cell / size;
        const int column = cell % size;
        const int neighbours[4] = {
            row > 0 ? cell - size : -1,
            row + 1 < size ? cell + size : -1,
            column > 0 ? cell - 1 : -1,
            column + 1 < size ? cell + 1 : -1
        };
        int neighbour;

        for (neighbour = 0; neighbour < 4; neighbour++) {
            const int next = neighbours[neighbour];

            if (next >= 0 && !seen[next] &&
                calcudoku_cage_id(game, next) == cage_id) {
                seen[next] = 1;
                queue[tail++] = next;
            }
        }
    }
    CHECK(tail == expected);
    CHECK(expected >= 1 && expected <= 4);
}

static void verify_generated(CalcudokuGameRef game, int difficulty,
                             int iteration)
{
    const int size = difficulty + 3;
    int seen_cages[36] = {0};
    int row;
    int column;
    int index;

    calcudoku_seed(game, (uint64_t)(difficulty * 10000 + iteration + 1));
    CHECK(calcudoku_new_game(game, difficulty));
    CHECK(calcudoku_size(game) == size);
    CHECK(calcudoku_solution_count(game, 2) == 1);
    CHECK(calcudoku_generation_score(game) > 0);

    for (row = 0; row < size; row++) {
        int row_mask = 0;
        int column_mask = 0;

        for (column = 0; column < size; column++) {
            const int row_value =
                calcudoku_solution_value(game, row * size + column);
            const int column_value =
                calcudoku_solution_value(game, column * size + row);

            CHECK(row_value >= 1 && row_value <= size);
            CHECK(column_value >= 1 && column_value <= size);
            row_mask |= 1 << (row_value - 1);
            column_mask |= 1 << (column_value - 1);
        }
        CHECK(row_mask == (1 << size) - 1);
        CHECK(column_mask == (1 << size) - 1);
    }

    for (index = 0; index < size * size; index++) {
        const int cage_id = calcudoku_cage_id(game, index);
        int cage_values[4];
        int cage_count = 0;
        int member;

        CHECK(cage_id >= 0 && cage_id < size * size);
        CHECK(calcudoku_cage_target(game, index) > 0);
        if (!seen_cages[cage_id]) {
            const int target = calcudoku_cage_target(game, index);
            const int operation = calcudoku_cage_operation(game, index);
            int anchor_count = 0;

            seen_cages[cage_id] = 1;
            verify_cage_geometry(game, cage_id);
            for (member = 0; member < size * size; member++) {
                if (calcudoku_cage_id(game, member) != cage_id)
                    continue;
                CHECK(calcudoku_cage_target(game, member) == target);
                CHECK(calcudoku_cage_operation(game, member) == operation);
                anchor_count += calcudoku_cage_anchor(game, member) != 0;
                cage_values[cage_count++] =
                    calcudoku_solution_value(game, member);
            }
            CHECK(anchor_count == 1);
            CHECK(operation_holds(operation, target, cage_values, cage_count));
            if (cage_count == 1)
                CHECK(operation == CALCUDOKU_OPERATION_NONE);
            if (operation == CALCUDOKU_OPERATION_DIFFERENCE ||
                operation == CALCUDOKU_OPERATION_RATIO)
                CHECK(cage_count == 2);
        }
        CHECK(calcudoku_value(game, index) == 0);
        CHECK(calcudoku_apply_value(
            game, index, calcudoku_solution_value(game, index)));
    }
    CHECK(calcudoku_is_complete(game));
    calcudoku_restart(game);
    for (index = 0; index < size * size; index++)
        CHECK(calcudoku_value(game, index) == 0);
}

int main(void)
{
    CalcudokuGameRef game = calcudoku_create();
    int difficulty;
    int iteration;

    CHECK(game != NULL);
    for (difficulty = 1; difficulty <= 3; difficulty++)
        for (iteration = 0; iteration < 30; iteration++)
            verify_generated(game, difficulty, iteration);
    calcudoku_destroy(game);
    puts("Verified 90 exact, valid Calcudoku puzzles (30 per difficulty).");
    return 0;
}
