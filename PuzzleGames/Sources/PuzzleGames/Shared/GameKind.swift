import Foundation

enum GameKind: String, CaseIterable, Codable, Identifiable {
    case sudoku
    case calcudoku

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sudoku: "Sudoku"
        case .calcudoku: "Calcudoku"
        }
    }

    var difficultySystemImage: String {
        switch self {
        case .sudoku: "circle.grid.3x3"
        case .calcudoku: "square.grid.3x3"
        }
    }
}
