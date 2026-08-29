import Combine
import Foundation

@MainActor
protocol PuzzleSession: AnyObject, ObservableObject {
    var values: [Int] { get }
    var solution: [Int] { get }
    var difficulty: GameDifficulty { get set }
    var notesMode: Bool { get set }
    var elapsedSeconds: Int { get }
    var formattedTime: String { get }
    var completed: Bool { get }
    var presentsCompletion: Bool { get set }
    var canUndo: Bool { get }
    var validNumbers: [Int] { get }
    var inputStyle: PuzzleInputStyle { get }

    func startNewGame()
    func input(_ number: Int)
    func erase()
    func undo()
    func restart()
    func moveSelection(dx: Int, dy: Int)
    func rotateSelection()
    func isNumberComplete(_ number: Int) -> Bool
    func isPlayerEntry(at index: Int) -> Bool
}

extension PuzzleSession {
    var inputStyle: PuzzleInputStyle { .numbers }
    func rotateSelection() {}

    func incorrectPlayerEntryIndexes() -> Set<Int> {
        Set(values.indices.filter { index in
            isPlayerEntry(at: index) && values[index] != 0 &&
                solution.indices.contains(index) && values[index] != solution[index]
        })
    }
}
