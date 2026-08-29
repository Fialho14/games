import XCTest
@testable import PuzzleGames

final class SlitherlinkEngineTests: XCTestCase {
    func testKnownUniqueInvalidAndAmbiguousPuzzles() {
        let unique = SlitherlinkSolver(size: 3, clues: [
            2, 1, 2,
            1, 0, 1,
            2, 1, 2,
        ]).solve()
        XCTAssertEqual(unique.solutionCount, 1)
        XCTAssertNotNil(unique.firstSolution)
        XCTAssertTrue(SlitherlinkSolver.isSingleLoop(size: 3,
                                                      edges: unique.firstSolution!))

        XCTAssertEqual(SlitherlinkSolver(size: 3, clues: Array(repeating: 4, count: 9))
            .solve().solutionCount, 0)
        XCTAssertEqual(SlitherlinkSolver(size: 3, clues: Array(repeating: -1, count: 9))
            .solve().solutionCount, 2)
    }

    func testSingleLoopValidatorRejectsSeparateLoopsAndBranches() {
        let size = 3
        var edges = Array(repeating: 2, count: 2 * size * (size + 1))
        for cell in [0, 8] {
            for edge in SlitherlinkSolver.cellEdges(row: cell / size,
                                                    column: cell % size,
                                                    size: size) {
                edges[edge] = 1
            }
        }
        XCTAssertFalse(SlitherlinkSolver.isSingleLoop(size: size, edges: edges))

        edges = Array(repeating: 2, count: edges.count)
        edges[0] = 1
        edges[1] = 1
        edges[size * (size + 1) + 1] = 1
        XCTAssertFalse(SlitherlinkSolver.isSingleLoop(size: size, edges: edges))
    }

    func testGeneratedPuzzlesAcrossSeedsAreUniqueAndValid() {
        var signatures = Set<String>()
        var averageScores: [Double] = []
        for difficulty in GameDifficulty.allCases {
            var scores: [Int] = []
            for seed in 1...4 {
                let puzzle = SlitherlinkGenerator().generate(
                    difficulty: difficulty,
                    seed: UInt64(difficulty.rawValue * 10_000 + seed)
                )
                XCTAssertEqual(puzzle.size, difficulty.rawValue + 3)
                XCTAssertEqual(puzzle.clues.count, puzzle.size * puzzle.size)
                XCTAssertEqual(puzzle.solution.count, puzzle.edgeCount)
                XCTAssertTrue(puzzle.clues.allSatisfy { (-1...3).contains($0) })
                XCTAssertTrue(SlitherlinkSolver.isSingleLoop(size: puzzle.size,
                                                             edges: puzzle.solution))

                let result = SlitherlinkSolver(size: puzzle.size, clues: puzzle.clues).solve()
                XCTAssertEqual(result.solutionCount, 1,
                               "difficulty \(difficulty), seed \(seed)")
                XCTAssertEqual(result.firstSolution, puzzle.solution)
                XCTAssertEqual(
                    SlitherlinkSolver.difficultyScore(size: puzzle.size,
                                                      metrics: result.metrics),
                    puzzle.score
                )
                XCTAssertGreaterThan(result.metrics.forcedAssignments, 0)
                scores.append(puzzle.score)
                signatures.insert("\(puzzle.size):\(puzzle.clues):\(puzzle.solution)")
            }
            averageScores.append(Double(scores.reduce(0, +)) / Double(scores.count))
        }
        XCTAssertEqual(signatures.count, GameDifficulty.allCases.count * 4)
        XCTAssertLessThan(averageScores[0], averageScores[1], "scores: \(averageScores)")
        XCTAssertLessThan(averageScores[1], averageScores[2], "scores: \(averageScores)")
    }
}
