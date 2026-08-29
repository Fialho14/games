/* cdok -- Calcudoku solver/generator
 * Copyright (C) 2012 Daniel Beer <dlbeer@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* Exact replacement for the upstream candidate approximation. Every
 * candidate admitted here has an arithmetic completion for its cage, and
 * every completed grid is validated before it is counted.
 */

#include "solver.h"

#include <limits.h>
#include <stddef.h>
#include <string.h>

struct solver_context {
	const struct cdok_puzzle *puzzle;
	uint8_t values[CDOK_CELLS];
	cdok_set_t rows[CDOK_SIZE];
	cdok_set_t columns[CDOK_SIZE];
	uint8_t cell_group[CDOK_CELLS];
	uint8_t *first_solution;
	unsigned int count;
	unsigned int limit;
	uint64_t first_branch_difficulty;
};

static cdok_set_t all_values(unsigned int size)
{
	if (size == CDOK_SIZE)
		return UINT16_MAX;
	return (cdok_set_t)((1u << size) - 1u);
}

static cdok_set_t value_bit(unsigned int value)
{
	return (cdok_set_t)(1u << (value - 1u));
}

static unsigned int bit_count(cdok_set_t set)
{
	unsigned int count = 0;

	while (set) {
		set = (cdok_set_t)(set & (cdok_set_t)(set - 1u));
		count++;
	}
	return count;
}

static int group_type_is_valid(const struct cdok_group *group)
{
	switch (group->type) {
	case CDOK_SUM:
		return group->target > 0;
	case CDOK_DIFFERENCE:
		return group->size == 2 && group->target >= 0;
	case CDOK_PRODUCT:
		return group->target > 0;
	case CDOK_RATIO:
		return group->size == 2 && group->target > 0;
	default:
		return 0;
	}
}

static int group_is_contiguous(const struct cdok_group *group)
{
	unsigned int queue[CDOK_GROUP_SIZE];
	uint8_t visited[CDOK_GROUP_SIZE] = {0};
	unsigned int head = 0;
	unsigned int tail = 1;
	unsigned int count = 0;

	queue[0] = 0;
	visited[0] = 1;
	while (head < tail) {
		const cdok_pos_t cell = group->members[queue[head++]];
		const int x = CDOK_POS_X(cell);
		const int y = CDOK_POS_Y(cell);
		unsigned int i;

		count++;
		for (i = 0; i < group->size; i++) {
			const cdok_pos_t other = group->members[i];
			const int dx = CDOK_POS_X(other) - x;
			const int dy = CDOK_POS_Y(other) - y;

			if (!visited[i] &&
			    ((dx == 0 && (dy == 1 || dy == -1)) ||
			     (dy == 0 && (dx == 1 || dx == -1)))) {
				visited[i] = 1;
				queue[tail++] = i;
			}
		}
	}
	return count == group->size;
}

int cdok_validate_puzzle(const struct cdok_puzzle *puz)
{
	uint8_t expected_map[CDOK_CELLS];
	unsigned int group_index;
	unsigned int x;
	unsigned int y;

	if (!puz || puz->size < 1 || puz->size > CDOK_SIZE)
		return -1;
	memset(expected_map, CDOK_GROUP_NONE, sizeof(expected_map));

	for (y = 0; y < CDOK_SIZE; y++) {
		for (x = 0; x < CDOK_SIZE; x++) {
			const cdok_pos_t cell = CDOK_POS(x, y);
			const uint8_t value = puz->values[cell];

			if (x < puz->size && y < puz->size) {
				if (value > puz->size)
					return -1;
			} else if (value != 0 ||
				   puz->group_map[cell] != CDOK_GROUP_NONE) {
				return -1;
			}
		}
	}

	for (group_index = 0; group_index < CDOK_GROUPS; group_index++) {
		const struct cdok_group *group = &puz->groups[group_index];
		unsigned int member_index;

		if (!group->size)
			continue;
		if (group->size < 2 || group->size > CDOK_GROUP_SIZE ||
		    !group_type_is_valid(group) || !group_is_contiguous(group))
			return -1;

		for (member_index = 0; member_index < group->size; member_index++) {
			const cdok_pos_t cell = group->members[member_index];
			unsigned int previous;

			if (cell < 0 || CDOK_POS_X(cell) >= (int)puz->size ||
			    CDOK_POS_Y(cell) >= (int)puz->size)
				return -1;
			for (previous = 0; previous < member_index; previous++)
				if (group->members[previous] == cell)
					return -1;
			if (expected_map[cell] != CDOK_GROUP_NONE)
				return -1;
			expected_map[cell] = (uint8_t)group_index;
		}
	}

	for (y = 0; y < CDOK_SIZE; y++)
		for (x = 0; x < CDOK_SIZE; x++) {
			const cdok_pos_t cell = CDOK_POS(x, y);

			if (puz->group_map[cell] != expected_map[cell])
				return -1;
		}
	return 0;
}

static int cage_is_satisfied(const struct cdok_group *group,
			     const uint8_t *values)
{
	uint64_t sum = 0;
	uint64_t product = 1;
	unsigned int i;

	for (i = 0; i < group->size; i++) {
		const unsigned int value = values[group->members[i]];

		if (!value)
			return 0;
		sum += value;
		product *= value;
	}

	switch (group->type) {
	case CDOK_SUM:
		return sum == (uint64_t)group->target;
	case CDOK_DIFFERENCE: {
		const unsigned int a = values[group->members[0]];
		const unsigned int b = values[group->members[1]];

		return (a > b ? a - b : b - a) == (unsigned int)group->target;
	}
	case CDOK_PRODUCT:
		return product == (uint64_t)group->target;
	case CDOK_RATIO: {
		const unsigned int a = values[group->members[0]];
		const unsigned int b = values[group->members[1]];
		const unsigned int high = a > b ? a : b;
		const unsigned int low = a > b ? b : a;

		return low != 0 && high % low == 0 &&
		       high / low == (unsigned int)group->target;
	}
	default:
		return 0;
	}
}

struct cage_trial {
	const struct solver_context *solver;
	const struct cdok_group *group;
	uint8_t values[CDOK_GROUP_SIZE];
	cdok_set_t rows[CDOK_SIZE];
	cdok_set_t columns[CDOK_SIZE];
};

static int cage_bounds_allow(const struct cage_trial *trial)
{
	const struct cdok_group *group = trial->group;
	uint64_t sum = 0;
	uint64_t product = 1;
	uint64_t maximum_product;
	unsigned int blanks = 0;
	unsigned int i;

	for (i = 0; i < group->size; i++) {
		if (!trial->values[i]) {
			blanks++;
			continue;
		}
		sum += trial->values[i];
		product *= trial->values[i];
	}

	if (group->type == CDOK_SUM) {
		const uint64_t target = (uint64_t)group->target;

		return sum + blanks <= target &&
		       target <= sum + (uint64_t)blanks * trial->solver->puzzle->size;
	}
	if (group->type != CDOK_PRODUCT)
		return 1;
	if ((uint64_t)group->target < product ||
	    (uint64_t)group->target % product != 0)
		return 0;

	maximum_product = product;
	for (i = 0; i < blanks; i++)
		maximum_product *= trial->solver->puzzle->size;
	return (uint64_t)group->target <= maximum_product;
}

static int cage_trial_recurse(struct cage_trial *trial, unsigned int index)
{
	const struct cdok_group *group = trial->group;
	unsigned int value;

	while (index < group->size && trial->values[index])
		index++;
	if (index >= group->size) {
		uint8_t complete[CDOK_CELLS] = {0};
		unsigned int i;

		for (i = 0; i < group->size; i++)
			complete[group->members[i]] = trial->values[i];
		return cage_is_satisfied(group, complete);
	}
	if (!cage_bounds_allow(trial))
		return 0;

	for (value = 1; value <= trial->solver->puzzle->size; value++) {
		const cdok_pos_t cell = group->members[index];
		const int x = CDOK_POS_X(cell);
		const int y = CDOK_POS_Y(cell);
		const cdok_set_t bit = value_bit(value);

		if ((trial->rows[y] | trial->columns[x]) & bit)
			continue;
		trial->values[index] = (uint8_t)value;
		trial->rows[y] |= bit;
		trial->columns[x] |= bit;
		if (cage_trial_recurse(trial, index + 1))
			return 1;
		trial->rows[y] = (cdok_set_t)(trial->rows[y] & ~bit);
		trial->columns[x] = (cdok_set_t)(trial->columns[x] & ~bit);
		trial->values[index] = 0;
	}
	return 0;
}

static int cage_can_complete(const struct solver_context *solver,
			     unsigned int group_index)
{
	struct cage_trial trial;
	unsigned int i;

	trial.solver = solver;
	trial.group = &solver->puzzle->groups[group_index];
	memcpy(trial.rows, solver->rows, sizeof(trial.rows));
	memcpy(trial.columns, solver->columns, sizeof(trial.columns));
	for (i = 0; i < trial.group->size; i++)
		trial.values[i] = solver->values[trial.group->members[i]];
	if (!cage_bounds_allow(&trial))
		return 0;
	return cage_trial_recurse(&trial, 0);
}

static cdok_set_t candidates_for(struct solver_context *solver,
				 cdok_pos_t cell)
{
	const int x = CDOK_POS_X(cell);
	const int y = CDOK_POS_Y(cell);
	const uint8_t group_index = solver->cell_group[cell];
	const cdok_set_t remaining =
		(cdok_set_t)(all_values(solver->puzzle->size) &
			     ~(solver->rows[y] | solver->columns[x]));
	cdok_set_t result = 0;
	unsigned int value;

	for (value = 1; value <= solver->puzzle->size; value++) {
		const cdok_set_t bit = value_bit(value);

		if (!(remaining & bit))
			continue;
		solver->values[cell] = (uint8_t)value;
		solver->rows[y] |= bit;
		solver->columns[x] |= bit;
		if (group_index == CDOK_GROUP_NONE ||
		    cage_can_complete(solver, group_index))
			result |= bit;
		solver->rows[y] = (cdok_set_t)(solver->rows[y] & ~bit);
		solver->columns[x] = (cdok_set_t)(solver->columns[x] & ~bit);
		solver->values[cell] = 0;
	}
	return result;
}

static int completed_grid_is_valid(const struct solver_context *solver)
{
	const cdok_set_t expected = all_values(solver->puzzle->size);
	unsigned int i;

	for (i = 0; i < solver->puzzle->size; i++)
		if (solver->rows[i] != expected || solver->columns[i] != expected)
			return 0;
	for (i = 0; i < CDOK_GROUPS; i++)
		if (solver->puzzle->groups[i].size &&
		    !cage_is_satisfied(&solver->puzzle->groups[i], solver->values))
			return 0;
	return 1;
}

static void solve_recurse(struct solver_context *solver,
			  uint64_t branch_difficulty)
{
	cdok_pos_t best_cell = -1;
	cdok_set_t best_candidates = 0;
	unsigned int best_count = UINT_MAX;
	unsigned int x;
	unsigned int y;

	if (solver->count >= solver->limit)
		return;
	for (y = 0; y < solver->puzzle->size; y++) {
		for (x = 0; x < solver->puzzle->size; x++) {
			const cdok_pos_t cell = CDOK_POS(x, y);
			cdok_set_t candidates;
			unsigned int count;

			if (solver->values[cell])
				continue;
			candidates = candidates_for(solver, cell);
			count = bit_count(candidates);
			if (!count)
				return;
			if (count < best_count) {
				best_cell = cell;
				best_candidates = candidates;
				best_count = count;
				if (count == 1)
					break;
			}
		}
		if (best_count == 1)
			break;
	}

	if (best_cell < 0) {
		if (!completed_grid_is_valid(solver))
			return;
		if (!solver->count) {
			if (solver->first_solution)
				memcpy(solver->first_solution, solver->values,
				       sizeof(solver->values));
			solver->first_branch_difficulty = branch_difficulty;
		}
		solver->count++;
		return;
	}

	{
		const uint64_t branch = best_count - 1u;
		const uint64_t increment = branch * branch;
		const int x_pos = CDOK_POS_X(best_cell);
		const int y_pos = CDOK_POS_Y(best_cell);
		unsigned int value;

		if (UINT64_MAX - branch_difficulty < increment)
			branch_difficulty = UINT64_MAX;
		else
			branch_difficulty += increment;
		for (value = 1; value <= solver->puzzle->size; value++) {
			const cdok_set_t bit = value_bit(value);

			if (!(best_candidates & bit))
				continue;
			solver->values[best_cell] = (uint8_t)value;
			solver->rows[y_pos] |= bit;
			solver->columns[x_pos] |= bit;
			solve_recurse(solver, branch_difficulty);
			solver->rows[y_pos] =
				(cdok_set_t)(solver->rows[y_pos] & ~bit);
			solver->columns[x_pos] =
				(cdok_set_t)(solver->columns[x_pos] & ~bit);
			solver->values[best_cell] = 0;
			if (solver->count >= solver->limit)
				return;
		}
	}
}

int cdok_count_solutions(const struct cdok_puzzle *puz, uint8_t *solution,
			 int limit, int *diff)
{
	struct solver_context solver;
	unsigned int group_index;
	unsigned int empty_count = 0;
	unsigned int x;
	unsigned int y;

	if (limit < 1 || cdok_validate_puzzle(puz) < 0)
		return -1;
	if (limit > 2)
		limit = 2;
	memset(&solver, 0, sizeof(solver));
	solver.puzzle = puz;
	solver.first_solution = solution;
	solver.limit = (unsigned int)limit;
	memcpy(solver.values, puz->values, sizeof(solver.values));
	memset(solver.cell_group, CDOK_GROUP_NONE, sizeof(solver.cell_group));

	for (group_index = 0; group_index < CDOK_GROUPS; group_index++) {
		const struct cdok_group *group = &puz->groups[group_index];
		unsigned int member_index;

		for (member_index = 0; member_index < group->size; member_index++)
			solver.cell_group[group->members[member_index]] =
				(uint8_t)group_index;
	}

	for (y = 0; y < puz->size; y++) {
		for (x = 0; x < puz->size; x++) {
			const cdok_pos_t cell = CDOK_POS(x, y);
			const unsigned int value = solver.values[cell];
			cdok_set_t bit;

			if (!value) {
				empty_count++;
				continue;
			}
			bit = value_bit(value);
			if ((solver.rows[y] | solver.columns[x]) & bit) {
				if (diff)
					*diff = 0;
				return 0;
			}
			solver.rows[y] |= bit;
			solver.columns[x] |= bit;
		}
	}

	for (group_index = 0; group_index < CDOK_GROUPS; group_index++)
		if (puz->groups[group_index].size &&
		    !cage_can_complete(&solver, group_index)) {
			if (diff)
				*diff = 0;
			return 0;
		}
	solve_recurse(&solver, 0);

	if (diff) {
		uint64_t multiplier = 1;
		uint64_t score;

		while (multiplier < (uint64_t)puz->size * puz->size)
			multiplier *= 10;
		score = solver.first_branch_difficulty * multiplier + empty_count;
		*diff = score > INT_MAX ? INT_MAX : (int)score;
	}
	return (int)solver.count;
}

int cdok_solve(const struct cdok_puzzle *puz, uint8_t *solution, int *diff)
{
	const int count = cdok_count_solutions(puz, solution, 2, diff);

	if (count < 1)
		return -1;
	return count > 1 ? 1 : 0;
}
