import Combine
import Foundation

@MainActor
final class SkyscrapersGameModel: PuzzleSession {
    @Published private(set) var size = 5
    @Published private(set) var clues = SkyscrapersClues(
        top: Array(repeating: 0, count: 5), bottom: Array(repeating: 0, count: 5),
        left: Array(repeating: 0, count: 5), right: Array(repeating: 0, count: 5)
    )
    @Published private(set) var values = Array(repeating: 0, count: 25)
    @Published private(set) var solution = Array(repeating: 0, count: 25)
    @Published private(set) var notes = Array(repeating: UInt16(0), count: 25)
    @Published private(set) var generationScore = 0
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
        let clues: SkyscrapersClues
        let values: [Int]
        let solution: [Int]
        let notes: [UInt16]
        let generationScore: Int
        let selectedIndex: Int
        let difficulty: GameDifficulty
        let elapsedSeconds: Int
        let savedAt: Date
        let completed: Bool
    }

    private let defaults: UserDefaults
    private let saveKey = "skyscrapers.mac.saved-game.v1"
    private var actions: [Action] = []
    private var generationSeed: UInt64
    private var generationCount: UInt64 = 0
    nonisolated(unsafe) private var timer: Timer?

    var canUndo: Bool { !actions.isEmpty }
    var validNumbers: [Int] { Array(1...size) }
    var cellCount: Int { size * size }
    var selectedValue: Int { values[selectedIndex] }
    var formattedTime: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    init(defaults: UserDefaults = .standard, seed: UInt64? = nil) {
        self.defaults = defaults
        generationSeed = seed ?? UInt64.random(in: 1...UInt64.max)
        if !restore() { startNewGame(difficulty: .medium) }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.completed else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds.isMultiple(of: 10) { self.save() }
            }
        }
    }

    deinit { timer?.invalidate() }

    func startNewGame() { startNewGame(difficulty: nil) }

    func startNewGame(difficulty newDifficulty: GameDifficulty?) {
        difficulty = newDifficulty ?? difficulty
        let seed = generationSeed &+ generationCount &* 0x9e3779b97f4a7c15
        generationCount &+= 1
        let puzzle = SkyscrapersGenerator().generate(difficulty: difficulty, seed: seed)
        size = puzzle.size
        clues = puzzle.clues
        values = Array(repeating: 0, count: size * size)
        solution = puzzle.solution
        notes = Array(repeating: 0, count: size * size)
        generationScore = puzzle.score
        selectedIndex = 0
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
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
        save()
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
            values[index] = previousValue
            notes[index] = previousNotes
            selectedIndex = index
        case let .notes(index, previous):
            notes[index] = previous
            selectedIndex = index
        }
        objectWillChange.send()
        save()
    }

    func restart() {
        values = Array(repeating: 0, count: cellCount)
        notes = Array(repeating: 0, count: cellCount)
        selectedIndex = 0
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        objectWillChange.send()
        save()
    }

    func noteIsSet(_ number: Int, at index: Int) -> Bool {
        notes[index] & UInt16(1 << (number - 1)) != 0
    }

    func isNumberComplete(_ number: Int) -> Bool {
        let indexes = values.indices.filter { values[$0] == number }
        return indexes.count == size && indexes.allSatisfy { !isConflict(at: $0) }
    }

    func isPlayerEntry(at index: Int) -> Bool { values.indices.contains(index) }

    func isPeer(_ index: Int) -> Bool {
        guard index != selectedIndex else { return false }
        return index / size == selectedIndex / size || index % size == selectedIndex % size
    }

    func isConflict(at index: Int) -> Bool {
        guard values.indices.contains(index), values[index] != 0 else { return false }
        let row = index / size
        let column = index % size
        let value = values[index]
        if (0..<size).contains(where: { $0 != column && values[row * size + $0] == value }) ||
            (0..<size).contains(where: { $0 != row && values[$0 * size + column] == value }) {
            return true
        }
        return completeLineConflict(row: row) || completeColumnConflict(column: column)
    }

    private func completeLineConflict(row: Int) -> Bool {
        let line = Array(values[row * size..<(row + 1) * size])
        guard !line.contains(0) else { return false }
        return (clues.left[row] > 0 && SkyscrapersSolver.visibility(line) != clues.left[row]) ||
            (clues.right[row] > 0 &&
             SkyscrapersSolver.visibility(line.reversed()) != clues.right[row])
    }

    private func completeColumnConflict(column: Int) -> Bool {
        let line = (0..<size).map { values[$0 * size + column] }
        guard !line.contains(0) else { return false }
        return (clues.top[column] > 0 && SkyscrapersSolver.visibility(line) != clues.top[column]) ||
            (clues.bottom[column] > 0 &&
             SkyscrapersSolver.visibility(line.reversed()) != clues.bottom[column])
    }

    private func setValue(_ value: Int) {
        guard values[selectedIndex] != value else { return }
        actions.append(.value(index: selectedIndex, previousValue: values[selectedIndex],
                              previousNotes: notes[selectedIndex]))
        values[selectedIndex] = value
        notes[selectedIndex] = 0
        checkCompletion()
        objectWillChange.send()
        save()
    }

    private func checkCompletion() {
        guard SkyscrapersSolver.isValidSolution(size: size, clues: clues,
                                                 values: values) else { return }
        completed = true
        presentsCompletion = true
    }

    private func save() {
        let saved = SavedGame(size: size, clues: clues, values: values,
                              solution: solution, notes: notes,
                              generationScore: generationScore,
                              selectedIndex: selectedIndex, difficulty: difficulty,
                              elapsedSeconds: elapsedSeconds, savedAt: Date(),
                              completed: completed)
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: saveKey) }
    }

    private func restore() -> Bool {
        guard let data = defaults.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              (4...6).contains(saved.size), saved.clues.isValid(for: saved.size) else {
            return false
        }
        let count = saved.size * saved.size
        guard saved.values.count == count, saved.solution.count == count,
              saved.notes.count == count,
              saved.values.allSatisfy({ (0...saved.size).contains($0) }) else { return false }
        let result = SkyscrapersSolver(size: saved.size, clues: saved.clues).solve()
        guard result.solutionCount == 1, result.firstSolution == saved.solution else { return false }

        size = saved.size
        clues = saved.clues
        values = saved.values
        solution = saved.solution
        notes = saved.notes.map { $0 & UInt16((1 << saved.size) - 1) }
        generationScore = saved.generationScore
        selectedIndex = min(count - 1, max(0, saved.selectedIndex))
        difficulty = saved.difficulty
        completed = SkyscrapersSolver.isValidSolution(size: size, clues: clues, values: values)
        elapsedSeconds = saved.elapsedSeconds
        if !completed { elapsedSeconds += max(0, Int(Date().timeIntervalSince(saved.savedAt))) }
        return true
    }
}
