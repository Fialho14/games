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

#ifndef SOLVER_H_
#define SOLVER_H_

#include "cdok.h"

/* Validate the structural invariants required by the exact solver.
 * Returns 0 for a valid puzzle and -1 otherwise.
 */
int cdok_validate_puzzle(const struct cdok_puzzle *puz);

/* Count solutions exactly, stopping at limit. If solution is non-NULL,
 * the first solution found is copied to it. If diff is non-NULL, a stable
 * generator score based on branching and empty cells is returned.
 *
 * Returns -1 for an invalid puzzle, otherwise a count in [0, limit].
 */
int cdok_count_solutions(const struct cdok_puzzle *puz, uint8_t *solution,
			 int limit, int *diff);

/* Attempt to solve the given puzzle, optionally producing a solution and
 * difficulty score. This compatibility entry point counts up to two exact
 * solutions.
 *
 * Return values are:
 *
 *    -1: the puzzle is unsolvable
 *     0: the puzzle is uniquely solvable
 *     1: the puzzle is solvable, but the solution is not unique
 */
int cdok_solve(const struct cdok_puzzle *puz, uint8_t *solution, int *diff);

#endif
