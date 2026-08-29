import XCTest
@testable import PuzzleGames

@MainActor
final class GameIntegrationTests: XCTestCase {
    func testSwitchingAcrossEveryRegisteredGamePreservesIndependentStateAndSelection() {
        let suite = "GameIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let sudoku = SudokuGameModel()
        let calcudoku = CalcudokuGameModel(defaults: defaults, seed: 10)
        let slitherlink = SlitherlinkGameModel(defaults: defaults, seed: 20)
        let skyscrapers = SkyscrapersGameModel(defaults: defaults, seed: 30)
        let nurikabe = NurikabeGameModel(defaults: defaults, seed: 40)

        let sudokuSnapshot = sudoku.values
        calcudoku.input(calcudoku.solution[0])
        slitherlink.input(slitherlink.solution[0])
        skyscrapers.input(skyscrapers.solution[0])
        let nurikabeCell = nurikabe.clues.firstIndex(of: 0)!
        nurikabe.select(nurikabeCell)
        nurikabe.input(nurikabe.solution[nurikabeCell])

        let snapshots = (
            calcudoku.values, slitherlink.values, skyscrapers.values, nurikabe.values
        )
        let app = AppModel(
            sudokuModel: sudoku,
            calcudokuModel: calcudoku,
            slitherlinkModel: slitherlink,
            skyscrapersModel: skyscrapers,
            nurikabeModel: nurikabe,
            defaults: defaults,
            selectedGame: .sudoku
        )

        for game in GameKind.allCases {
            app.selectedGame = game
            XCTAssertEqual(app.selectedGame, game)
            XCTAssertEqual(sudoku.values, sudokuSnapshot)
            XCTAssertEqual(calcudoku.values, snapshots.0)
            XCTAssertEqual(slitherlink.values, snapshots.1)
            XCTAssertEqual(skyscrapers.values, snapshots.2)
            XCTAssertEqual(nurikabe.values, snapshots.3)
        }

        let restored = AppModel(
            sudokuModel: sudoku,
            calcudokuModel: calcudoku,
            slitherlinkModel: slitherlink,
            skyscrapersModel: skyscrapers,
            nurikabeModel: nurikabe,
            defaults: defaults
        )
        XCTAssertEqual(restored.selectedGame, .nurikabe)
    }
}
