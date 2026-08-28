import Combine
import Foundation
import SudokuEngine

@MainActor
final class SudokuGameModel: PuzzleSession {
    @Published private(set) var values = Array(repeating: 0, count: 81)
    @Published private(set) var givens = Array(repeating: false, count: 81)
    @Published private(set) var solution = Array(repeating: 0, count: 81)
    @Published private(set) var notes = Array(repeating: UInt16(0), count: 81)
    @Published var selectedIndex = 0
    @Published var difficulty: GameDifficulty = .medium
    @Published var notesMode = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var completed = false
    @Published var presentsCompletion = false

    private enum Action {
        case value(index: Int, previousNotes: UInt16)
        case notes(index: Int, previous: UInt16)
    }

    private struct SavedGame: Codable {
        let values: [Int]
        let givens: [Bool]
        let solution: [Int]
        let notes: [UInt16]
        let selectedIndex: Int
        let difficulty: GameDifficulty
        let elapsedSeconds: Int
        let savedAt: Date
        let completed: Bool
    }

    nonisolated(unsafe) private let game: UnsafeMutableRawPointer
    private var actions: [Action] = []
    nonisolated(unsafe) private var timer: Timer?
    private let saveKey = "sudoku.mac.saved-game.v1"

    var canUndo: Bool { !actions.isEmpty }
    let validNumbers = Array(1...9)

    init() {
        guard let game = sudoku_create() else { fatalError("Unable to create Sudoku engine") }
        self.game = game
        if !restore() { startNewGame(difficulty: .medium) }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.completed else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds.isMultiple(of: 10) { self.save() }
            }
        }
    }

    deinit {
        timer?.invalidate()
        sudoku_destroy(game)
    }

    func startNewGame() {
        startNewGame(difficulty: nil)
    }

    func startNewGame(difficulty newDifficulty: GameDifficulty?) {
        difficulty = newDifficulty ?? difficulty
        sudoku_new_game(game, Int32(difficulty.rawValue))
        notes = Array(repeating: 0, count: 81)
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        syncFromEngine()
        selectedIndex = values.firstIndex(of: 0) ?? 0
        save()
    }

    func select(_ index: Int) {
        guard values.indices.contains(index) else { return }
        selectedIndex = index
        save()
    }

    func moveSelection(dx: Int, dy: Int) {
        let row = selectedIndex / 9
        let column = selectedIndex % 9
        selectedIndex = min(8, max(0, row + dy)) * 9 + min(8, max(0, column + dx))
    }

    func input(_ number: Int) {
        guard (1...9).contains(number), !givens[selectedIndex], !completed else { return }
        if notesMode {
            guard values[selectedIndex] == 0 else { return }
            let previous = notes[selectedIndex]
            notes[selectedIndex] ^= UInt16(1 << (number - 1))
            actions.append(.notes(index: selectedIndex, previous: previous))
            objectWillChange.send()
            save()
            return
        }
        setValue(number)
    }

    func erase() {
        guard !givens[selectedIndex], !completed else { return }
        if notes[selectedIndex] != 0 && values[selectedIndex] == 0 {
            let previous = notes[selectedIndex]
            notes[selectedIndex] = 0
            actions.append(.notes(index: selectedIndex, previous: previous))
            objectWillChange.send()
            save()
        } else if values[selectedIndex] != 0 {
            setValue(0)
        }
    }

    func undo() {
        guard let action = actions.popLast(), !completed else { return }
        switch action {
        case let .value(index, previousNotes):
            guard sudoku_undo(game) != 0 else { return }
            notes[index] = previousNotes
            syncFromEngine()
        case let .notes(index, previous):
            notes[index] = previous
            objectWillChange.send()
        }
        save()
    }

    func restart() {
        sudoku_restart(game)
        notes = Array(repeating: 0, count: 81)
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        syncFromEngine()
        selectedIndex = values.firstIndex(of: 0) ?? 0
        save()
    }

    func isConflict(at index: Int) -> Bool {
        sudoku_has_conflict(game, Int32(index)) != 0
    }

    func noteIsSet(_ number: Int, at index: Int) -> Bool {
        notes[index] & UInt16(1 << (number - 1)) != 0
    }

    func isNumberComplete(_ number: Int) -> Bool {
        let expectedIndexes = solution.indices.filter { solution[$0] == number }
        return expectedIndexes.count == 9 && expectedIndexes.allSatisfy {
            values[$0] == number && !isConflict(at: $0)
        }
    }

    func isPlayerEntry(at index: Int) -> Bool {
        givens.indices.contains(index) && !givens[index]
    }

    func isPeer(_ index: Int) -> Bool {
        guard index != selectedIndex else { return false }
        let selectedRow = selectedIndex / 9
        let selectedColumn = selectedIndex % 9
        let row = index / 9
        let column = index % 9
        return row == selectedRow || column == selectedColumn ||
            (row / 3 == selectedRow / 3 && column / 3 == selectedColumn / 3)
    }

    var selectedValue: Int { values[selectedIndex] }
    var formattedTime: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private func setValue(_ value: Int) {
        guard values[selectedIndex] != value else { return }
        let previousNotes = notes[selectedIndex]
        if sudoku_apply_value(game, Int32(selectedIndex), Int32(value)) != 0 {
            actions.append(.value(index: selectedIndex, previousNotes: previousNotes))
            notes[selectedIndex] = 0
            syncFromEngine()
            checkCompletion()
            save()
        }
    }

    private func syncFromEngine() {
        for index in 0..<81 {
            values[index] = Int(sudoku_value(game, Int32(index)))
            givens[index] = sudoku_is_given(game, Int32(index)) != 0
            solution[index] = Int(sudoku_solution_value(game, Int32(index)))
        }
        objectWillChange.send()
    }

    private func checkCompletion() {
        guard sudoku_is_complete(game) != 0 else { return }
        completed = true
        presentsCompletion = true
    }

    private func save() {
        let saved = SavedGame(values: values, givens: givens, solution: solution,
                              notes: notes, selectedIndex: selectedIndex,
                              difficulty: difficulty, elapsedSeconds: elapsedSeconds,
                              savedAt: Date(), completed: completed)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.values.count == 81, saved.givens.count == 81,
              saved.solution.count == 81, saved.notes.count == 81 else { return false }
        var loadedValues = saved.values.map(Int32.init)
        var loadedGivens = saved.givens.map { $0 ? Int32(1) : Int32(0) }
        var loadedSolution = saved.solution.map(Int32.init)
        loadedValues.withUnsafeMutableBufferPointer { valuesBuffer in
            loadedGivens.withUnsafeMutableBufferPointer { givensBuffer in
                loadedSolution.withUnsafeMutableBufferPointer { solutionBuffer in
                    sudoku_load_game(game, valuesBuffer.baseAddress,
                                     givensBuffer.baseAddress, solutionBuffer.baseAddress)
                }
            }
        }
        guard sudoku_solution_count(game, 2) == 1 else { return false }
        syncFromEngine()
        notes = saved.notes
        selectedIndex = min(80, max(0, saved.selectedIndex))
        difficulty = saved.difficulty
        completed = saved.completed
        elapsedSeconds = saved.elapsedSeconds
        if !completed { elapsedSeconds += max(0, Int(Date().timeIntervalSince(saved.savedAt))) }
        return true
    }
}
