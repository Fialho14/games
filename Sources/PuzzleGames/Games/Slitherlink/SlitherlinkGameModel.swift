import Combine
import Foundation

@MainActor
final class SlitherlinkGameModel: PuzzleSession {
    @Published private(set) var size = 5
    @Published private(set) var clues = Array(repeating: -1, count: 25)
    @Published private(set) var values = Array(repeating: 0, count: 60)
    @Published private(set) var solution = Array(repeating: 2, count: 60)
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
    private let saveKey = "slitherlink.mac.saved-game.v1"
    private var actions: [Action] = []
    private var generationSeed: UInt64
    private var generationCount: UInt64 = 0
    nonisolated(unsafe) private var timer: Timer?

    let validNumbers = [1, 2]
    let inputStyle: PuzzleInputStyle = .twoState(
        TwoStateInputStyle(
            primary: PuzzleInputTool(
                title: "Line",
                systemImage: "minus",
                helpTitle: "Line mode is on",
                footerText: "Draw loop"
            ),
            secondary: PuzzleInputTool(
                title: "Exclude",
                systemImage: "xmark",
                helpTitle: "Exclude mode is on",
                footerText: "Exclude edges"
            ),
            helpText: "Click an edge to mark it. Use 1 for a line, 2 for an X, arrows to move, Shift to rotate the selection, and Delete to clear."
        )
    )
    var canUndo: Bool { !actions.isEmpty }
    var edgeCount: Int { 2 * size * (size + 1) }
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
        let puzzle = SlitherlinkGenerator().generate(difficulty: difficulty, seed: seed)
        size = puzzle.size
        clues = puzzle.clues
        solution = puzzle.solution
        generationScore = puzzle.score
        values = Array(repeating: 0, count: puzzle.edgeCount)
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

    func mark(_ index: Int) {
        guard values.indices.contains(index), !completed else { return }
        selectedIndex = index
        let mark = notesMode ? 2 : 1
        setValue(values[index] == mark ? 0 : mark, at: index)
    }

    func input(_ number: Int) {
        guard validNumbers.contains(number), !completed else { return }
        notesMode = number == 2
        setValue(number, at: selectedIndex)
    }

    func erase() {
        guard !completed else { return }
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
        values = Array(repeating: 0, count: edgeCount)
        selectedIndex = 0
        actions.removeAll()
        elapsedSeconds = 0
        completed = false
        presentsCompletion = false
        notesMode = false
        objectWillChange.send()
        save()
    }

    func moveSelection(dx: Int, dy: Int) {
        let horizontalCount = size * (size + 1)
        if selectedIndex < horizontalCount {
            var row = selectedIndex / size
            var column = selectedIndex % size
            if dx != 0 { column = min(size - 1, max(0, column + dx)) }
            if dy != 0 {
                row = min(size, max(0, row + dy))
            }
            selectedIndex = row * size + column
        } else {
            let compact = selectedIndex - horizontalCount
            var row = compact / (size + 1)
            var column = compact % (size + 1)
            if dx != 0 { column = min(size, max(0, column + dx)) }
            if dy != 0 { row = min(size - 1, max(0, row + dy)) }
            selectedIndex = horizontalCount + row * (size + 1) + column
        }
        save()
    }

    func rotateSelection() {
        let horizontalCount = size * (size + 1)
        if selectedIndex < horizontalCount {
            let row = selectedIndex / size
            let column = selectedIndex % size
            let verticalRow = min(row, size - 1)
            selectedIndex = horizontalCount + verticalRow * (size + 1) + column
        } else {
            let compact = selectedIndex - horizontalCount
            let row = compact / (size + 1)
            let column = compact % (size + 1)
            let horizontalColumn = min(column, size - 1)
            selectedIndex = row * size + horizontalColumn
        }
        save()
    }

    func isNumberComplete(_ number: Int) -> Bool { false }
    func isPlayerEntry(at index: Int) -> Bool { values.indices.contains(index) }

    func isConflict(at edge: Int) -> Bool {
        guard values.indices.contains(edge), values[edge] == 1 else { return false }
        let cells = adjacentCells(to: edge)
        if cells.contains(where: { cell in
            guard clues[cell] >= 0 else { return false }
            return SlitherlinkSolver.cellEdges(row: cell / size, column: cell % size,
                                               size: size)
                .count(where: { values[$0] == 1 }) > clues[cell]
        }) { return true }

        let (a, b) = SlitherlinkSolver.vertices(for: edge, size: size)
        return [a, b].contains(where: { vertexLineCount($0) > 2 })
    }

    private func setValue(_ value: Int, at index: Int) {
        guard values.indices.contains(index), (0...2).contains(value), values[index] != value else {
            return
        }
        actions.append(Action(index: index, previous: values[index]))
        values[index] = value
        selectedIndex = index
        checkCompletion()
        objectWillChange.send()
        save()
    }

    private func checkCompletion() {
        let lineOnly = values.map { $0 == 1 ? 1 : 2 }
        guard SlitherlinkSolver.isSingleLoop(size: size, edges: lineOnly) else { return }
        for cell in clues.indices where clues[cell] >= 0 {
            let count = SlitherlinkSolver.cellEdges(row: cell / size, column: cell % size,
                                                    size: size)
                .count(where: { values[$0] == 1 })
            guard count == clues[cell] else { return }
        }
        completed = true
        presentsCompletion = true
    }

    private func adjacentCells(to edge: Int) -> [Int] {
        let horizontalCount = size * (size + 1)
        var result: [Int] = []
        if edge < horizontalCount {
            let row = edge / size
            let column = edge % size
            if row > 0 { result.append((row - 1) * size + column) }
            if row < size { result.append(row * size + column) }
        } else {
            let compact = edge - horizontalCount
            let row = compact / (size + 1)
            let column = compact % (size + 1)
            if column > 0 { result.append(row * size + column - 1) }
            if column < size { result.append(row * size + column) }
        }
        return result
    }

    private func vertexLineCount(_ vertex: Int) -> Int {
        values.indices.count(where: { edge in
            guard values[edge] == 1 else { return false }
            let (a, b) = SlitherlinkSolver.vertices(for: edge, size: size)
            return a == vertex || b == vertex
        })
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
              (4...6).contains(saved.size),
              saved.clues.count == saved.size * saved.size else { return false }
        let edgeCount = 2 * saved.size * (saved.size + 1)
        guard saved.values.count == edgeCount, saved.solution.count == edgeCount,
              saved.values.allSatisfy({ (0...2).contains($0) }),
              saved.solution.allSatisfy({ (1...2).contains($0) }) else { return false }
        let solved = SlitherlinkSolver(size: saved.size, clues: saved.clues).solve()
        guard solved.solutionCount == 1, solved.firstSolution == saved.solution else { return false }

        size = saved.size
        clues = saved.clues
        values = saved.values
        solution = saved.solution
        generationScore = saved.generationScore
        selectedIndex = min(edgeCount - 1, max(0, saved.selectedIndex))
        difficulty = saved.difficulty
        notesMode = saved.notesMode
        completed = saved.completed
        elapsedSeconds = saved.elapsedSeconds
        if !completed { elapsedSeconds += max(0, Int(Date().timeIntervalSince(saved.savedAt))) }
        return true
    }
}
