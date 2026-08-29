import Foundation

/// Describes the controls supplied by the common shell without coupling it to
/// a specific puzzle. Number games use the built-in number strip; two-state
/// games provide their own labels while keeping the same input behavior.
enum PuzzleInputStyle: Sendable {
    case numbers
    case twoState(TwoStateInputStyle)
}

struct TwoStateInputStyle: Sendable {
    let primary: PuzzleInputTool
    let secondary: PuzzleInputTool
    let helpText: String
}

struct PuzzleInputTool: Sendable {
    let title: String
    let systemImage: String
    let helpTitle: String
    let footerText: String
}
