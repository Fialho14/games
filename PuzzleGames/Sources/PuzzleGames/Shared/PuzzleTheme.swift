import SwiftUI

enum PuzzleTheme {
    static let accent = Color(red: 0.27, green: 0.39, blue: 0.45)
    static let surface = Color(red: 0.965, green: 0.96, blue: 0.945)
    static let ink = Color(red: 0.14, green: 0.15, blue: 0.16)
    static let appBackground = Color(red: 0.975, green: 0.97, blue: 0.955)
    static let completionBackground = Color(red: 0.98, green: 0.975, blue: 0.96)

    static let grid = Color(red: 0.81, green: 0.82, blue: 0.82)
    static let block = Color(red: 0.35, green: 0.37, blue: 0.38)
    static let paper = Color(red: 0.99, green: 0.985, blue: 0.975)
    static let peer = Color(red: 0.955, green: 0.96, blue: 0.958)
    static let conflict = Color(red: 0.96, green: 0.87, blue: 0.85)
    static let conflictInk = Color(red: 0.62, green: 0.20, blue: 0.17)
    static let checkMistake = Color(red: 0.985, green: 0.925, blue: 0.91)
    static let checkMistakeInk = Color(red: 0.66, green: 0.27, blue: 0.23)
    static let checkSuccess = Color(red: 0.22, green: 0.55, blue: 0.34)

    enum Layout {
        static let windowWidth: CGFloat = 844
        static let windowHeight: CGFloat = 690
        static let boardSide: CGFloat = 520
        static let controlsWidth: CGFloat = 220
        static let boardControlsSpacing: CGFloat = 28
        static let horizontalPadding: CGFloat = 32
        static let verticalPadding: CGFloat = 24
    }
}
