import CalcudokuEngine
import Combine
import Foundation

@MainActor
final class CalcudokuGameModel: PuzzleSession {
    @Published private(set) var size = 5
    @Published private(set) var values = Array(repeating: 0, count: 25)
    @Published private(set) var solution = Array(repeating: 0, count: 25)
    @Published private(set) var notes = Array(repeating: UInt16(0), count: 25)
    @Published private(set) var cageIDs = Array(repeating: 0, count: 25)
    @Published private(set) var cageTargets = Array(repeating: 0, count: 25)
    @Published private(set) var cageOperations = Array(repeating: 0, count: 25)
    @Published private(set) var cageAnchors = Array(repeating: false, count: 25)
    @Published var selectedIndex = 0
    @Published var difficulty: GameDifficulty = .medium
    @Published var notesMode = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var completed = false
    @Published var presentsCompletion = false

    private enum Action {
        case value(index: Int, previousValue: Int, previousNotes: UInt16)
        case notes(index: Int, previous: UInt16)
    }

    private struct SavedGame: Codable {
        let size: Int
        let values: [Int]
        let solution: [Int]
        let notes: [UInt16]
        let cageIDs: [Int]
        let cageTargets: [Int]
        let cageOperations: [Int]
        let selectedIndex: Int
        let difficulty: GameDifficulty
        let elapsedSeconds: Int
        let savedAt: Date
        let completed: Bool
    }

    nonisolated(unsafe) private let game: UnsafeMutableRawPointer
    private let defaults: UserDefaults
    private let saveKey = "calcudoku.mac.saved-game.v1"
    private var actions: [Action] = []
    nonisolated(unsafe) private var timer: Timer?

    var canUndo: Bool { !actions.isEmpty }
    var validNumbers: [Int] { Array(1...size) }
    var cellCount: Int { size * size }
    var selectedValue: Int { values[selectedIndex] }
    var formattedTime: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    init(defaults: UserDefaults = .standard, seed: UInt64? = nil) {
        guard let game = calcudoku_create() else {
            fatalError("Unable to create Calcudoku engine")
        }
        self.game = game
        self.defaults = defaults
        calcudoku_seed(game, seed ?? UInt64.random(in: 1...UInt64.max))
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
        calcudoku_destroy(game)
    }

    func startNewGame() {
        startNewGame(difficulty: nil)
    }

    func startNewGame(difficulty newDifficulty: GameDifficulty?) {
        difficulty = newDifficulty ?? difficulty
        guard calcudoku_new_game(game, Int32(difficulty.rawValue)) != 0 else {
            fatalError("Unable to generate a unique Calcudoku puzzle")
        }
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        syncFromEngine(resetNotes: true)
        selectedIndex = 0
        save()
    }

    func select(_ index: Int) {
        guard values.indices.contains(index) else { return }
        selectedIndex = index
        save()
    }

    func moveSelection(dx: Int, dy: Int) {
        let row = selectedIndex / size
        let column = selectedIndex % size
        selectedIndex = min(size - 1, max(0, row + dy)) * size +
            min(size - 1, max(0, column + dx))
    }

    func input(_ number: Int) {
        guard validNumbers.contains(number), !completed else { return }
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
        guard !completed else { return }
        if values[selectedIndex] == 0 && notes[selectedIndex] != 0 {
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
        case let .value(index, previousValue, previousNotes):
            guard calcudoku_apply_value(game, Int32(index), Int32(previousValue)) != 0 else {
                return
            }
            notes[index] = previousNotes
            syncValues()
        case let .notes(index, previous):
            notes[index] = previous
            objectWillChange.send()
        }
        save()
    }

    func restart() {
        calcudoku_restart(game)
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        syncValues()
        notes = Array(repeating: 0, count: cellCount)
        selectedIndex = 0
        save()
    }

    func isLineConflict(at index: Int) -> Bool {
        calcudoku_has_row_conflict(game, Int32(index)) != 0 ||
            calcudoku_has_column_conflict(game, Int32(index)) != 0
    }

    func isCageConflict(at index: Int) -> Bool {
        calcudoku_has_cage_conflict(game, Int32(index)) != 0
    }

    func isConflict(at index: Int) -> Bool {
        isLineConflict(at: index) || isCageConflict(at: index)
    }

    func noteIsSet(_ number: Int, at index: Int) -> Bool {
        notes[index] & UInt16(1 << (number - 1)) != 0
    }

    func isNumberComplete(_ number: Int) -> Bool {
        let indexes = values.indices.filter { values[$0] == number }
        return indexes.count == size && indexes.allSatisfy { !isLineConflict(at: $0) }
    }

    func isPlayerEntry(at index: Int) -> Bool {
        values.indices.contains(index)
    }

    func isPeer(_ index: Int) -> Bool {
        guard index != selectedIndex else { return false }
        return index / size == selectedIndex / size || index % size == selectedIndex % size
    }

    func isSameCage(_ first: Int, _ second: Int) -> Bool {
        values.indices.contains(first) && values.indices.contains(second) &&
            cageIDs[first] == cageIDs[second]
    }

    func clue(at index: Int) -> String? {
        guard cageAnchors[index] else { return nil }
        let symbol: String
        switch cageOperations[index] {
        case Int(CALCUDOKU_OPERATION_SUM): symbol = "+"
        case Int(CALCUDOKU_OPERATION_DIFFERENCE): symbol = "−"
        case Int(CALCUDOKU_OPERATION_PRODUCT): symbol = "×"
        case Int(CALCUDOKU_OPERATION_RATIO): symbol = "÷"
        default: symbol = ""
        }
        return "\(cageTargets[index])\(symbol)"
    }

    private func setValue(_ value: Int) {
        guard values[selectedIndex] != value else { return }
        let previousValue = values[selectedIndex]
        let previousNotes = notes[selectedIndex]
        guard calcudoku_apply_value(game, Int32(selectedIndex), Int32(value)) != 0 else {
            return
        }
        actions.append(.value(index: selectedIndex, previousValue: previousValue,
                              previousNotes: previousNotes))
        notes[selectedIndex] = 0
        syncValues()
        checkCompletion()
        save()
    }

    private func syncFromEngine(resetNotes: Bool) {
        size = Int(calcudoku_size(game))
        let count = cellCount
        values = (0..<count).map { Int(calcudoku_value(game, Int32($0))) }
        solution = (0..<count).map { Int(calcudoku_solution_value(game, Int32($0))) }
        cageIDs = (0..<count).map { Int(calcudoku_cage_id(game, Int32($0))) }
        cageTargets = (0..<count).map { Int(calcudoku_cage_target(game, Int32($0))) }
        cageOperations = (0..<count).map { Int(calcudoku_cage_operation(game, Int32($0))) }
        cageAnchors = (0..<count).map { calcudoku_cage_anchor(game, Int32($0)) != 0 }
        if resetNotes { notes = Array(repeating: 0, count: count) }
        objectWillChange.send()
    }

    private func syncValues() {
        for index in 0..<cellCount {
            values[index] = Int(calcudoku_value(game, Int32(index)))
        }
        objectWillChange.send()
    }

    private func checkCompletion() {
        guard calcudoku_is_complete(game) != 0 else { return }
        completed = true
        presentsCompletion = true
    }

    private func save() {
        let saved = SavedGame(
            size: size, values: values, solution: solution, notes: notes,
            cageIDs: cageIDs, cageTargets: cageTargets,
            cageOperations: cageOperations, selectedIndex: selectedIndex,
            difficulty: difficulty, elapsedSeconds: elapsedSeconds,
            savedAt: Date(), completed: completed
        )
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: saveKey)
        }
    }

    private func restore() -> Bool {
        guard let data = defaults.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              (4...6).contains(saved.size) else { return false }
        let count = saved.size * saved.size
        guard saved.values.count == count, saved.solution.count == count,
              saved.notes.count == count, saved.cageIDs.count == count,
              saved.cageTargets.count == count,
              saved.cageOperations.count == count else { return false }

        var values32 = saved.values.map(Int32.init)
        var solution32 = saved.solution.map(Int32.init)
        var ids32 = saved.cageIDs.map(Int32.init)
        var targets32 = saved.cageTargets.map(Int32.init)
        var operations32 = saved.cageOperations.map(Int32.init)
        let loaded = values32.withUnsafeMutableBufferPointer { valuesBuffer in
            solution32.withUnsafeMutableBufferPointer { solutionBuffer in
                ids32.withUnsafeMutableBufferPointer { idsBuffer in
                    targets32.withUnsafeMutableBufferPointer { targetsBuffer in
                        operations32.withUnsafeMutableBufferPointer { operationsBuffer in
                            calcudoku_load_game(
                                game, Int32(saved.size), valuesBuffer.baseAddress,
                                solutionBuffer.baseAddress, idsBuffer.baseAddress,
                                targetsBuffer.baseAddress, operationsBuffer.baseAddress
                            )
                        }
                    }
                }
            }
        }
        guard loaded != 0, calcudoku_solution_count(game, 2) == 1 else {
            return false
        }

        syncFromEngine(resetNotes: false)
        let notesMask = UInt16((1 << saved.size) - 1)
        notes = saved.notes.map { $0 & notesMask }
        selectedIndex = min(count - 1, max(0, saved.selectedIndex))
        difficulty = saved.difficulty
        completed = calcudoku_is_complete(game) != 0
        elapsedSeconds = saved.elapsedSeconds
        if !completed {
            elapsedSeconds += max(0, Int(Date().timeIntervalSince(saved.savedAt)))
        }
        return true
    }
}
