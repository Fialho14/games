import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private static let selectedGameKey = "puzzle-games.selected-game.v1"

    let sudokuModel: SudokuGameModel
    let calcudokuModel: CalcudokuGameModel

    @Published var selectedGame: GameKind {
        didSet {
            guard selectedGame != oldValue else { return }
            defaults.set(selectedGame.rawValue, forKey: Self.selectedGameKey)
        }
    }

    private let defaults: UserDefaults

    init(
        sudokuModel: SudokuGameModel = SudokuGameModel(),
        calcudokuModel: CalcudokuGameModel = CalcudokuGameModel(),
        defaults: UserDefaults = .standard,
        selectedGame: GameKind? = nil
    ) {
        self.sudokuModel = sudokuModel
        self.calcudokuModel = calcudokuModel
        self.defaults = defaults

        let restoredGame = defaults.string(forKey: Self.selectedGameKey)
            .flatMap(GameKind.init(rawValue:))
        self.selectedGame = selectedGame ?? restoredGame ?? .sudoku
    }
}
