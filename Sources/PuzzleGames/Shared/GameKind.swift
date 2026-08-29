import Foundation

enum GameKind: String, CaseIterable, Codable, Identifiable {
    case sudoku
    case calcudoku
    case slitherlink
    case skyscrapers
    case nurikabe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sudoku: "Sudoku"
        case .calcudoku: "Calcudoku"
        case .slitherlink: "Slitherlink"
        case .skyscrapers: "Skyscrapers"
        case .nurikabe: "Nurikabe"
        }
    }

    var difficultySystemImage: String {
        switch self {
        case .sudoku: "circle.grid.3x3"
        case .calcudoku: "square.grid.3x3"
        case .slitherlink: "point.topleft.down.to.point.bottomright.curvepath"
        case .skyscrapers: "building.2"
        case .nurikabe: "square.grid.3x3.fill"
        }
    }
}
