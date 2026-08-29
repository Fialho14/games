import SwiftUI

struct ContentView: View {
    @StateObject private var appModel: AppModel

    init(appModel: AppModel = AppModel()) {
        _appModel = StateObject(wrappedValue: appModel)
    }

    init(model: SudokuGameModel) {
        _appModel = StateObject(
            wrappedValue: AppModel(sudokuModel: model, selectedGame: .sudoku)
        )
    }

    var body: some View {
        switch appModel.selectedGame {
        case .sudoku:
            PuzzleShellView(
                game: .sudoku,
                session: appModel.sudokuModel,
                selectedGame: $appModel.selectedGame
            ) {
                SudokuBoardView(model: appModel.sudokuModel)
            }

        case .calcudoku:
            PuzzleShellView(
                game: .calcudoku,
                session: appModel.calcudokuModel,
                selectedGame: $appModel.selectedGame
            ) {
                CalcudokuBoardView(model: appModel.calcudokuModel)
            }

        case .slitherlink:
            PuzzleShellView(
                game: .slitherlink,
                session: appModel.slitherlinkModel,
                selectedGame: $appModel.selectedGame
            ) {
                SlitherlinkBoardView(model: appModel.slitherlinkModel)
            }

        case .skyscrapers:
            PuzzleShellView(
                game: .skyscrapers,
                session: appModel.skyscrapersModel,
                selectedGame: $appModel.selectedGame
            ) {
                SkyscrapersBoardView(model: appModel.skyscrapersModel)
            }

        case .nurikabe:
            PuzzleShellView(
                game: .nurikabe,
                session: appModel.nurikabeModel,
                selectedGame: $appModel.selectedGame
            ) {
                NurikabeBoardView(model: appModel.nurikabeModel)
            }
        }
    }
}
