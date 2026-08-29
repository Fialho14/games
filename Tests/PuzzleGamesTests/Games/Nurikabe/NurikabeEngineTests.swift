import XCTest
@testable import PuzzleGames

final class NurikabeEngineTests: XCTestCase {
    func testAmbiguousPuzzleStopsAfterTwoSolutions() {
        let clues = [
            0, 0, 0, 0,
            4, 0, 0, 2,
            0, 0, 0, 0,
            0, 0, 1, 0,
        ]
        XCTAssertEqual(NurikabeSolver(size: 4, clues: clues).solve().solutionCount, 2)
    }

    func testPreviouslyOrderDependentSeedsResolveRepeatably() {
        for (difficulty, seed) in [(GameDifficulty.medium, UInt64(820_003)),
                                   (.hard, UInt64(830_003))] {
            let puzzle = NurikabeGenerator().generate(difficulty: difficulty, seed: seed)
            for _ in 0..<3 {
                let result = NurikabeSolver(size: puzzle.size, clues: puzzle.clues).solve()
                XCTAssertEqual(result.solutionCount, 1, "\(difficulty), seed \(seed)")
                XCTAssertEqual(result.firstSolution, puzzle.solution)
            }
        }
    }

    func testValidatorRejectsDisconnectedSeaPoolsAndBadIslands() {
        let size = 4
        let clues = [
            1, 0, 0, 1,
            0, 0, 0, 0,
            0, 0, 0, 0,
            1, 0, 0, 1,
        ]
        let allSeaExceptClues = clues.map { $0 > 0 ? 2 : 1 }
        XCTAssertFalse(NurikabeSolver.isValidSolution(size: size, clues: clues,
                                                       values: allSeaExceptClues))

        var disconnectedSea = Array(repeating: 2, count: 16)
        disconnectedSea[0] = 1
        disconnectedSea[15] = 1
        XCTAssertFalse(NurikabeSolver.isValidSolution(size: size, clues: clues,
                                                       values: disconnectedSea))

        XCTAssertEqual(NurikabeSolver(size: 4, clues: Array(repeating: 0, count: 16))
            .solve().solutionCount, 0)
    }

    func testGeneratedPuzzlesAcrossSeedsAreUniqueValidVariedAndRated() {
        var signatures = Set<String>()
        var averageScores: [Double] = []
        for difficulty in GameDifficulty.allCases {
            var scores: [Int] = []
            for seed in 1...3 {
                let puzzle = NurikabeGenerator().generate(
                    difficulty: difficulty,
                    seed: UInt64(800_000 + difficulty.rawValue * 10_000 + seed)
                )
                XCTAssertEqual(puzzle.size, difficulty.rawValue + 4)
                XCTAssertEqual(puzzle.clues.count, puzzle.size * puzzle.size)
                XCTAssertEqual(puzzle.solution.count, puzzle.size * puzzle.size)
                XCTAssertGreaterThanOrEqual(puzzle.clues.count(where: { $0 > 0 }), 3)
                XCTAssertTrue(NurikabeSolver.isValidSolution(
                    size: puzzle.size, clues: puzzle.clues, values: puzzle.solution
                ))
                let result = NurikabeSolver(size: puzzle.size, clues: puzzle.clues).solve()
                XCTAssertEqual(result.solutionCount, 1, "\(difficulty), seed \(seed)")
                XCTAssertEqual(result.firstSolution, puzzle.solution)
                XCTAssertGreaterThanOrEqual(puzzle.score, puzzle.size * puzzle.size * 1_000)
                XCTAssertGreaterThan(result.metrics.forcedAssignments, 0)
                scores.append(puzzle.score)
                signatures.insert("\(puzzle.size):\(puzzle.clues):\(puzzle.solution)")
            }
            averageScores.append(Double(scores.reduce(0, +)) / Double(scores.count))
        }
        XCTAssertEqual(signatures.count, GameDifficulty.allCases.count * 3)
        XCTAssertLessThan(averageScores[0], averageScores[1], "scores: \(averageScores)")
        XCTAssertLessThan(averageScores[1], averageScores[2], "scores: \(averageScores)")
    }
}
