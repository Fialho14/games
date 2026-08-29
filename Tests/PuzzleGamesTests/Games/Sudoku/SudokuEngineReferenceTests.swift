import SudokuEngine
import XCTest

private func independentSudokuSolutionCount(_ puzzle: [Int], limit: Int = 2) -> Int {
    var board = puzzle
    var rowMasks = Array(repeating: 0, count: 9)
    var columnMasks = Array(repeating: 0, count: 9)
    var boxMasks = Array(repeating: 0, count: 9)
    var solutions = 0

    for index in board.indices where board[index] != 0 {
        let value = board[index]
        guard (1...9).contains(value) else { return 0 }
        let row = index / 9
        let column = index % 9
        let box = row / 3 * 3 + column / 3
        let bit = 1 << (value - 1)
        guard rowMasks[row] & bit == 0, columnMasks[column] & bit == 0,
              boxMasks[box] & bit == 0 else { return 0 }
        rowMasks[row] |= bit
        columnMasks[column] |= bit
        boxMasks[box] |= bit
    }

    func recurse() {
        guard solutions < limit else { return }
        var bestIndex = -1
        var bestMask = 0
        var bestCount = 10

        for index in board.indices where board[index] == 0 {
            let row = index / 9
            let column = index % 9
            let box = row / 3 * 3 + column / 3
            let mask = 0x1ff & ~(rowMasks[row] | columnMasks[column] | boxMasks[box])
            let count = mask.nonzeroBitCount
            if count == 0 { return }
            if count < bestCount {
                bestIndex = index
                bestMask = mask
                bestCount = count
                if count == 1 { break }
            }
        }
        if bestIndex < 0 {
            solutions += 1
            return
        }

        let row = bestIndex / 9
        let column = bestIndex % 9
        let box = row / 3 * 3 + column / 3
        var remaining = bestMask
        while remaining != 0 && solutions < limit {
            let bit = remaining & -remaining
            remaining &= ~bit
            board[bestIndex] = bit.trailingZeroBitCount + 1
            rowMasks[row] |= bit
            columnMasks[column] |= bit
            boxMasks[box] |= bit
            recurse()
            rowMasks[row] &= ~bit
            columnMasks[column] &= ~bit
            boxMasks[box] &= ~bit
            board[bestIndex] = 0
        }
    }

    recurse()
    return solutions
}

final class SudokuEngineReferenceTests: XCTestCase {
    func testThirtyGeneratedSudokusWithIndependentSolver() throws {
        let game = try XCTUnwrap(sudoku_create())
        defer { sudoku_destroy(game) }
        let expectedEmptyCounts = [20, 35, 50]
        var generated = 0

        for difficulty in 1...3 {
            for _ in 0..<10 {
                sudoku_new_game(game, Int32(difficulty))
                let puzzle = (0..<81).map { Int(sudoku_value(game, Int32($0))) }
                let solution = (0..<81).map {
                    Int(sudoku_solution_value(game, Int32($0)))
                }
                XCTAssertEqual(puzzle.filter { $0 == 0 }.count,
                               expectedEmptyCounts[difficulty - 1])
                XCTAssertEqual(independentSudokuSolutionCount(puzzle), 1)
                for row in 0..<9 {
                    XCTAssertEqual(Set((0..<9).map { solution[row * 9 + $0] }),
                                   Set(1...9))
                    XCTAssertEqual(Set((0..<9).map { solution[$0 * 9 + row] }),
                                   Set(1...9))
                }
                generated += 1
            }
        }
        XCTAssertEqual(generated, 30)
    }
}
