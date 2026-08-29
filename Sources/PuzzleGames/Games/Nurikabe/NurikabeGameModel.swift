import Combine
import Foundation

@MainActor
final class NurikabeGameModel: PuzzleSession {
    @Published private(set) var size = 6
    @Published private(set) var clues = Array(repeating: 0, count: 36)
    @Published private(set) var values = Array(repeating: 0, count: 36)
    @Published private(set) var solution = Array(repeating: 0, count: 36)
    @Published private(set) var generationScore = 0
    @Published var selectedIndex = 0
    @Published var difficulty: GameDifficulty = .medium
    @Published var notesMode = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var completed = false
    @Published var presentsCompletion = false

    private struct Action {
        let index: Int
        let previous: Int
    }

    private struct SavedGame: Codable {
        let size: Int
        let clues: [Int]
        let values: [Int]
        let solution: [Int]
        let generationScore: Int
        let selectedIndex: Int
        let difficulty: GameDifficulty
        let notesMode: Bool
        let elapsedSeconds: Int
        let savedAt: Date
        let completed: Bool
    }

    private let defaults: UserDefaults
    private let saveKey = "nurikabe.mac.saved-game.v1"
    private var actions: [Action] = []
    private var generationSeed: UInt64
    private var generationCount: UInt64 = 0
    nonisolated(unsafe) private var timer: Timer?

    let validNumbers = [1, 2]
    let inputStyle: PuzzleInputStyle = .twoState(
        TwoStateInputStyle(
            primary: PuzzleInputTool(
                title: "Sea",
                systemImage: "square.fill",
                helpTitle: "Sea mode is on",
                footerText: "Mark sea"
            ),
            secondary: PuzzleInputTool(
                title: "Island",
                systemImage: "square",
                helpTitle: "Island mode is on",
                footerText: "Mark islands"
            ),
            helpText: "Click a cell to mark it. Use 1 for sea, 2 for island, arrows to move, and Delete to clear."
        )
    )
    var canUndo: Bool { !actions.isEmpty }
    var cellCount: Int { size * size }
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
        let puzzle = NurikabeGenerator().generate(difficulty: difficulty, seed: seed)
        size = puzzle.size
        clues = puzzle.clues
        solution = puzzle.solution
        generationScore = puzzle.score
        values = clues.map { $0 > 0 ? 2 : 0 }
        selectedIndex = values.firstIndex(of: 0) ?? 0
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

    func mark(_ index: Int) {
        guard values.indices.contains(index) else { return }
        selectedIndex = index
        guard clues[index] == 0, !completed else {
            save()
            return
        }
        let mark = notesMode ? 2 : 1
        setValue(values[index] == mark ? 0 : mark, at: index)
    }

    func input(_ number: Int) {
        guard validNumbers.contains(number), clues[selectedIndex] == 0, !completed else { return }
        notesMode = number == 2
        setValue(number, at: selectedIndex)
    }

    func erase() {
        guard clues[selectedIndex] == 0, !completed else { return }
        setValue(0, at: selectedIndex)
    }

    func undo() {
        guard let action = actions.popLast(), !completed else { return }
        values[action.index] = action.previous
        selectedIndex = action.index
        objectWillChange.send()
        save()
    }

    func restart() {
        values = clues.map { $0 > 0 ? 2 : 0 }
        selectedIndex = values.firstIndex(of: 0) ?? 0
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        objectWillChange.send()
        save()
    }

    func moveSelection(dx: Int, dy: Int) {
        let row = selectedIndex / size
        let column = selectedIndex % size
        selectedIndex = min(size - 1, max(0, row + dy)) * size +
            min(size - 1, max(0, column + dx))
        save()
    }

    func isNumberComplete(_ number: Int) -> Bool { false }
    func isPlayerEntry(at index: Int) -> Bool {
        values.indices.contains(index) && clues[index] == 0
    }

    func isConflict(at index: Int) -> Bool {
        guard values.indices.contains(index), values[index] != 0 else { return false }
        if values[index] == 1 {
            let row = index / size
            let column = index % size
            for r in max(0, row - 1)...min(size - 2, row) {
                for c in max(0, column - 1)...min(size - 2, column) {
                    let square = [r * size + c, r * size + c + 1,
                                  (r + 1) * size + c, (r + 1) * size + c + 1]
                    if square.allSatisfy({ values[$0] == 1 }) { return true }
                }
            }
            if !values.contains(0) {
                let sea = Set(values.indices.filter { values[$0] == 1 })
                return !isConnected(sea)
            }
            return false
        }

        let component = component(from: index, matching: 2)
        let clueCells = component.filter { clues[$0] > 0 }
        if clueCells.count > 1 { return true }
        if let clue = clueCells.first, component.count > clues[clue] { return true }
        return false
    }

    private func setValue(_ value: Int, at index: Int) {
        guard values[index] != value else { return }
        actions.append(Action(index: index, previous: values[index]))
        values[index] = value
        selectedIndex = index
        checkCompletion()
        objectWillChange.send()
        save()
    }

    private func checkCompletion() {
        guard !values.contains(0),
              NurikabeSolver.isValidSolution(size: size, clues: clues, values: values) else {
            return
        }
        completed = true
        presentsCompletion = true
    }

    private func component(from start: Int, matching value: Int) -> Set<Int> {
        var visited: Set<Int> = [start]
        var stack = [start]
        while let cell = stack.popLast() {
            for neighbor in NurikabeSolver.neighbors(of: cell, size: size)
                where values[neighbor] == value && visited.insert(neighbor).inserted {
                stack.append(neighbor)
            }
        }
        return visited
    }

    private func isConnected(_ cells: Set<Int>) -> Bool {
        guard let start = cells.first else { return false }
        return component(from: start, matching: 1).count == cells.count
    }

    private func save() {
        let saved = SavedGame(size: size, clues: clues, values: values,
                              solution: solution, generationScore: generationScore,
                              selectedIndex: selectedIndex, difficulty: difficulty,
                              notesMode: notesMode, elapsedSeconds: elapsedSeconds,
                              savedAt: Date(), completed: completed)
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: saveKey) }
    }

    private func restore() -> Bool {
        guard let data = defaults.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              (5...7).contains(saved.size) else { return false }
        let count = saved.size * saved.size
        guard saved.clues.count == count, saved.values.count == count,
              saved.solution.count == count,
              saved.values.allSatisfy({ (0...2).contains($0) }),
              saved.clues.indices.allSatisfy({ saved.clues[$0] == 0 || saved.values[$0] == 2 }) else {
            return false
        }
        let result = NurikabeSolver(size: saved.size, clues: saved.clues).solve()
        guard result.solutionCount == 1, result.firstSolution == saved.solution else { return false }

        size = saved.size
        clues = saved.clues
        values = saved.values
        solution = saved.solution
        generationScore = saved.generationScore
        selectedIndex = min(count - 1, max(0, saved.selectedIndex))
        difficulty = saved.difficulty
        notesMode = saved.notesMode
        completed = NurikabeSolver.isValidSolution(size: size, clues: clues, values: values)
        elapsedSeconds = saved.elapsedSeconds
        if !completed { elapsedSeconds += max(0, Int(Date().timeIntervalSince(saved.savedAt))) }
        return true
    }
}
