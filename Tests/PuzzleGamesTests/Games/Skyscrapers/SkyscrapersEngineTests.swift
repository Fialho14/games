import XCTest
@testable import PuzzleGames

final class SkyscrapersEngineTests: XCTestCase {
    func testVisibilityAndKnownUniqueInvalidAmbiguousPuzzles() {
        XCTAssertEqual(SkyscrapersSolver.visibility([5, 2, 4, 1, 3]), 1)
        XCTAssertEqual(SkyscrapersSolver.visibility([1, 3, 2, 5, 4]), 3)

        let clues = SkyscrapersClues(
            top: [4, 3, 2, 1], bottom: [1, 2, 2, 2],
            left: [4, 3, 2, 1], right: [1, 2, 2, 2]
        )
        let expected = [
            1, 2, 3, 4,
            2, 3, 4, 1,
            3, 4, 1, 2,
            4, 1, 2, 3,
        ]
        let unique = SkyscrapersSolver(size: 4, clues: clues).solve()
        XCTAssertEqual(unique.solutionCount, 1)
        XCTAssertEqual(unique.firstSolution, expected)
        XCTAssertTrue(SkyscrapersSolver.isValidSolution(size: 4, clues: clues,
                                                         values: expected))

        let invalid = SkyscrapersClues(top: [5, 0, 0, 0], bottom: [0, 0, 0, 0],
                                       left: [0, 0, 0, 0], right: [0, 0, 0, 0])
        XCTAssertEqual(SkyscrapersSolver(size: 4, clues: invalid).solve().solutionCount, 0)
        let empty = SkyscrapersClues(top: [0, 0, 0, 0], bottom: [0, 0, 0, 0],
                                     left: [0, 0, 0, 0], right: [0, 0, 0, 0])
        XCTAssertEqual(SkyscrapersSolver(size: 4, clues: empty).solve().solutionCount, 2)
    }

    func testGeneratedPuzzlesAcrossSeedsAreUniqueValidVariedAndRated() {
        var signatures = Set<String>()
        var averageScores: [Double] = []
        for difficulty in GameDifficulty.allCases {
            var scores: [Int] = []
            for seed in 1...3 {
                let puzzle = SkyscrapersGenerator().generate(
                    difficulty: difficulty,
                    seed: UInt64(500_000 + difficulty.rawValue * 10_000 + seed)
                )
                XCTAssertEqual(puzzle.size, difficulty.rawValue + 3)
                XCTAssertTrue(puzzle.clues.isValid(for: puzzle.size))
                XCTAssertEqual(puzzle.solution.count, puzzle.size * puzzle.size)
                XCTAssertTrue(puzzle.clues.all.contains(0), "generator should remove clues")
                XCTAssertTrue(SkyscrapersSolver.isValidSolution(
                    size: puzzle.size, clues: puzzle.clues, values: puzzle.solution
                ))

                let result = SkyscrapersSolver(size: puzzle.size, clues: puzzle.clues).solve()
                XCTAssertEqual(result.solutionCount, 1)
                XCTAssertEqual(result.firstSolution, puzzle.solution)
                XCTAssertEqual(independentSolutionCount(size: puzzle.size,
                                                        clues: puzzle.clues), 1)
                XCTAssertEqual(puzzle.score, SkyscrapersSolver.difficultyScore(
                    size: puzzle.size, metrics: result.metrics
                ))
                XCTAssertGreaterThan(result.metrics.domainEliminations, 0)
                scores.append(puzzle.score)
                signatures.insert("\(puzzle.size):\(puzzle.clues.all):\(puzzle.solution)")
            }
            averageScores.append(Double(scores.reduce(0, +)) / Double(scores.count))
        }
        XCTAssertEqual(signatures.count, GameDifficulty.allCases.count * 3)
        XCTAssertLessThan(averageScores[0], averageScores[1], "scores: \(averageScores)")
        XCTAssertLessThan(averageScores[1], averageScores[2], "scores: \(averageScores)")
    }

    private func independentSolutionCount(size: Int, clues: SkyscrapersClues,
                                          limit: Int = 2) -> Int {
        var permutations: [[Int]] = []
        var current: [Int] = []
        func make(_ remaining: Set<Int>) {
            if remaining.isEmpty {
                permutations.append(current)
                return
            }
            for value in remaining.sorted() {
                current.append(value)
                make(remaining.subtracting([value]))
                current.removeLast()
            }
        }
        make(Set(1...size))

        let rowDomains = (0..<size).map { row in
            permutations.filter { permutation in
                (clues.left[row] == 0 ||
                 SkyscrapersSolver.visibility(permutation) == clues.left[row]) &&
                (clues.right[row] == 0 ||
                 SkyscrapersSolver.visibility(permutation.reversed()) == clues.right[row])
            }
        }
        var columnDomains = (0..<size).map { column in
            permutations.filter { permutation in
                (clues.top[column] == 0 ||
                 SkyscrapersSolver.visibility(permutation) == clues.top[column]) &&
                (clues.bottom[column] == 0 ||
                 SkyscrapersSolver.visibility(permutation.reversed()) == clues.bottom[column])
            }
        }
        var count = 0
        func search(row: Int) {
            guard count < limit else { return }
            if row == size {
                count += 1
                return
            }
            let saved = columnDomains
            for permutation in rowDomains[row] where count < limit {
                var valid = true
                for column in 0..<size {
                    columnDomains[column].removeAll { $0[row] != permutation[column] }
                    if columnDomains[column].isEmpty { valid = false; break }
                }
                if valid { search(row: row + 1) }
                columnDomains = saved
            }
        }
        search(row: 0)
        return count
    }
}
