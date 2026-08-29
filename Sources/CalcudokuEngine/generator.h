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

#ifndef GENERATOR_H_
#define GENERATOR_H_

#include <stdint.h>

/* Per-game deterministic random source. Keeping it explicit makes puzzle
 * generation thread-safe and allows reproducible native tests.
 */
struct cdok_rng {
	uint64_t state;
};

void cdok_rng_seed(struct cdok_rng *rng, uint64_t seed);

/* Generate a valid solution grid. Returns 0 on success, -1 for invalid
 * input or an unexpected fill failure.
 */
int cdok_generate_grid(uint8_t *values, int size, struct cdok_rng *rng);

/* Generator flags. Difference and ratio groups may be of arbitrary
 * size, but some definitions of Calcudoku limit them to two cells
 * only. Use the CDOK_FLAGS_TWO_CELL flag to impose this requirement
 * on the generator.
 */
typedef enum {
	CDOK_FLAGS_NONE		= 0x00,
	CDOK_FLAGS_TWO_CELL	= 0x01
} cdok_flags_t;

/* Take a solution and use it to build a puzzle. Arguments are:
 *
 *    flags:      constraints (CDOK_FLAGS_TWO_CELL or CDOK_FLAGS_NONE)
 *    iterations: upper limit on hardening iterations
 *    limit:      maximum puzzle difficulty
 *    target:     difficulty threshold to stop hardening
 *
 * The difficulty of the new puzzle is returned.
 */
int cdok_generate(struct cdok_puzzle *puz,
		  const uint8_t *solution, int size,
		  cdok_flags_t fl, int iterations, int limit, int target,
		  struct cdok_rng *rng);

#endif
