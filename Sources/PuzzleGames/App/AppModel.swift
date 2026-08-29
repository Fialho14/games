import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private static let selectedGameKey = "puzzle-games.selected-game.v1"

    let sudokuModel: SudokuGameModel
    let calcudokuModel: CalcudokuGameModel
    let slitherlinkModel: SlitherlinkGameModel
    let skyscrapersModel: SkyscrapersGameModel
    let nurikabeModel: NurikabeGameModel

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
        slitherlinkModel: SlitherlinkGameModel = SlitherlinkGameModel(),
        skyscrapersModel: SkyscrapersGameModel = SkyscrapersGameModel(),
        nurikabeModel: NurikabeGameModel = NurikabeGameModel(),
        defaults: UserDefaults = .standard,
        selectedGame: GameKind? = nil
    ) {
        self.sudokuModel = sudokuModel
        self.calcudokuModel = calcudokuModel
        self.slitherlinkModel = slitherlinkModel
        self.skyscrapersModel = skyscrapersModel
        self.nurikabeModel = nurikabeModel
        self.defaults = defaults

        let restoredGame = defaults.string(forKey: Self.selectedGameKey)
            .flatMap(GameKind.init(rawValue:))
        self.selectedGame = selectedGame ?? restoredGame ?? .sudoku
    }
}
