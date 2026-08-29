import Foundation

struct SlitherlinkPuzzle: Equatable {
    let size: Int
    let clues: [Int]
    let solution: [Int]
    let score: Int

    var edgeCount: Int { 2 * size * (size + 1) }
}

struct SlitherlinkSolveMetrics: Equatable {
    var forcedAssignments = 0
    var decisions = 0
    var backtracks = 0
    var maxDepth = 0

    var score: Int {
        forcedAssignments + decisions * 80 + backtracks * 120 + maxDepth * 25
    }
}

struct SlitherlinkSolveResult {
    let solutionCount: Int
    let firstSolution: [Int]?
    let metrics: SlitherlinkSolveMetrics
}

struct SlitherlinkSolver {
    let size: Int
    let clues: [Int]

    init(size: Int, clues: [Int]) {
        self.size = size
        self.clues = clues
    }

    func solve(limit: Int = 2) -> SlitherlinkSolveResult {
        guard (3...10).contains(size), clues.count == size * size, limit > 0,
              clues.allSatisfy({ (-1...3).contains($0) }) else {
            return SlitherlinkSolveResult(solutionCount: 0, firstSolution: nil,
                                          metrics: SlitherlinkSolveMetrics())
        }

        var search = Search(size: size, clues: clues, limit: min(2, limit))
        search.search(states: Array(repeating: -1, count: 2 * size * (size + 1)),
                      depth: 0)
        return SlitherlinkSolveResult(solutionCount: search.solutionCount,
                                      firstSolution: search.firstSolution,
                                      metrics: search.metrics)
    }

    static func difficultyScore(size: Int, metrics: SlitherlinkSolveMetrics) -> Int {
        // Larger grids add genuinely global connectivity work that is not fully
        // reflected by a single successful MRV path. Keep that structural cost
        // explicit, then retain the measured propagation/search work within it.
        size * size * 1_000 + metrics.score
    }

    static func isSingleLoop(size: Int, edges: [Int]) -> Bool {
        let expectedCount = 2 * size * (size + 1)
        guard edges.count == expectedCount else { return false }
        let vertexCount = (size + 1) * (size + 1)
        var adjacency = Array(repeating: [Int](), count: vertexCount)

        for edge in 0..<expectedCount where edges[edge] == 1 {
            let (a, b) = vertices(for: edge, size: size)
            adjacency[a].append(b)
            adjacency[b].append(a)
        }
        let used = adjacency.indices.filter { !adjacency[$0].isEmpty }
        guard let start = used.first,
              used.allSatisfy({ adjacency[$0].count == 2 }) else { return false }

        var visited: Set<Int> = [start]
        var stack = [start]
        while let vertex = stack.popLast() {
            for neighbor in adjacency[vertex] where visited.insert(neighbor).inserted {
                stack.append(neighbor)
            }
        }
        return visited.count == used.count
    }

    static func vertices(for edge: Int, size: Int) -> (Int, Int) {
        let horizontalCount = size * (size + 1)
        if edge < horizontalCount {
            let row = edge / size
            let column = edge % size
            let first = row * (size + 1) + column
            return (first, first + 1)
        }
        let compact = edge - horizontalCount
        let row = compact / (size + 1)
        let column = compact % (size + 1)
        let first = row * (size + 1) + column
        return (first, first + size + 1)
    }

    static func cellEdges(row: Int, column: Int, size: Int) -> [Int] {
        let horizontalCount = size * (size + 1)
        return [
            row * size + column,
            (row + 1) * size + column,
            horizontalCount + row * (size + 1) + column,
            horizontalCount + row * (size + 1) + column + 1,
        ]
    }

    private struct Search {
        let size: Int
        let clues: [Int]
        let limit: Int
        var solutionCount = 0
        var firstSolution: [Int]?
        var metrics = SlitherlinkSolveMetrics()

        mutating func search(states initialStates: [Int8], depth: Int) {
            guard solutionCount < limit else { return }
            var states = initialStates
            let decisionsBefore = solutionCount
            guard propagate(&states) else {
                if depth > 0 { metrics.backtracks += 1 }
                return
            }
            metrics.maxDepth = max(metrics.maxDepth, depth)

            guard let edge = chooseEdge(in: states) else {
                let publicStates = states.map { $0 == 1 ? 1 : 2 }
                guard Self.cluesAreSatisfied(size: size, clues: clues, states: states),
                      SlitherlinkSolver.isSingleLoop(size: size, edges: publicStates) else {
                    if depth > 0 { metrics.backtracks += 1 }
                    return
                }
                if firstSolution == nil { firstSolution = publicStates }
                solutionCount += 1
                return
            }

            metrics.decisions += 1
            for value: Int8 in [1, 0] where solutionCount < limit {
                var branch = states
                branch[edge] = value
                search(states: branch, depth: depth + 1)
            }
            if solutionCount == decisionsBefore && depth > 0 { metrics.backtracks += 1 }
        }

        mutating func propagate(_ states: inout [Int8]) -> Bool {
            var changed = true
            while changed {
                changed = false
                for cell in clues.indices where clues[cell] >= 0 {
                    let row = cell / size
                    let column = cell % size
                    let edges = SlitherlinkSolver.cellEdges(row: row, column: column,
                                                            size: size)
                    let on = edges.count(where: { states[$0] == 1 })
                    let unknown = edges.filter { states[$0] == -1 }
                    let clue = clues[cell]
                    if on > clue || on + unknown.count < clue { return false }
                    if on == clue {
                        for edge in unknown {
                            states[edge] = 0
                            metrics.forcedAssignments += 1
                            changed = true
                        }
                    } else if on + unknown.count == clue {
                        for edge in unknown {
                            states[edge] = 1
                            metrics.forcedAssignments += 1
                            changed = true
                        }
                    }
                }

                for vertex in 0..<(size + 1) * (size + 1) {
                    let edges = vertexEdges(vertex)
                    let on = edges.count(where: { states[$0] == 1 })
                    let unknown = edges.filter { states[$0] == -1 }
                    if on > 2 || (on == 1 && unknown.isEmpty) { return false }
                    if on == 2 {
                        for edge in unknown {
                            states[edge] = 0
                            metrics.forcedAssignments += 1
                            changed = true
                        }
                    } else if on == 1 && unknown.count == 1 {
                        states[unknown[0]] = 1
                        metrics.forcedAssignments += 1
                        changed = true
                    } else if on == 0 && unknown.count == 1 {
                        states[unknown[0]] = 0
                        metrics.forcedAssignments += 1
                        changed = true
                    }
                }

                if hasImpossibleClosedComponent(states) { return false }
            }
            return true
        }

        func chooseEdge(in states: [Int8]) -> Int? {
            var best: (edge: Int, pressure: Int)?
            for cell in clues.indices where clues[cell] >= 0 {
                let edges = SlitherlinkSolver.cellEdges(row: cell / size,
                                                        column: cell % size,
                                                        size: size)
                let unknown = edges.filter { states[$0] == -1 }
                guard !unknown.isEmpty else { continue }
                let pressure = 10 - unknown.count
                if best == nil || pressure > best!.pressure {
                    best = (unknown[0], pressure)
                }
            }
            return best?.edge ?? states.firstIndex(of: -1)
        }

        func vertexEdges(_ vertex: Int) -> [Int] {
            let row = vertex / (size + 1)
            let column = vertex % (size + 1)
            let horizontalCount = size * (size + 1)
            var result: [Int] = []
            if column > 0 { result.append(row * size + column - 1) }
            if column < size { result.append(row * size + column) }
            if row > 0 { result.append(horizontalCount + (row - 1) * (size + 1) + column) }
            if row < size { result.append(horizontalCount + row * (size + 1) + column) }
            return result
        }

        func hasImpossibleClosedComponent(_ states: [Int8]) -> Bool {
            let vertexCount = (size + 1) * (size + 1)
            var lineAdjacency = Array(repeating: [Int](), count: vertexCount)
            for edge in states.indices where states[edge] == 1 {
                let (a, b) = SlitherlinkSolver.vertices(for: edge, size: size)
                lineAdjacency[a].append(b)
                lineAdjacency[b].append(a)
            }
            var visited = Set<Int>()
            var foundClosed = false
            let usedVertexCount = lineAdjacency.count(where: { !$0.isEmpty })
            for start in lineAdjacency.indices where !lineAdjacency[start].isEmpty {
                guard !visited.contains(start) else { continue }
                var component: Set<Int> = [start]
                var stack = [start]
                var closed = true
                while let vertex = stack.popLast() {
                    if lineAdjacency[vertex].count != 2 { closed = false }
                    for neighbor in lineAdjacency[vertex]
                        where component.insert(neighbor).inserted {
                        stack.append(neighbor)
                    }
                }
                visited.formUnion(component)
                if closed {
                    if foundClosed { return true }
                    foundClosed = true
                    if component.count < usedVertexCount { return true }
                }
            }
            return false
        }

        static func cluesAreSatisfied(size: Int, clues: [Int], states: [Int8]) -> Bool {
            clues.indices.allSatisfy { cell in
                guard clues[cell] >= 0 else { return true }
                return SlitherlinkSolver.cellEdges(row: cell / size,
                                                   column: cell % size,
                                                   size: size)
                    .count(where: { states[$0] == 1 }) == clues[cell]
            }
        }
    }
}

struct SlitherlinkGenerator {
    func generate(difficulty: GameDifficulty, seed: UInt64) -> SlitherlinkPuzzle {
        let size = difficulty.rawValue + 3
        var rng = SeededGenerator(seed: seed)
        var best: SlitherlinkPuzzle?

        for _ in 0..<40 {
            guard let loop = makeLoop(size: size, rng: &rng) else { continue }
            let fullClues = deriveClues(size: size, loop: loop)
            let fullResult = SlitherlinkSolver(size: size, clues: fullClues).solve()
            guard fullResult.solutionCount == 1 else { continue }

            var clues = fullClues
            var order = Array(clues.indices)
            order.shuffle(using: &rng)
            let desiredClues = Int((Double(size * size) * clueRatio(difficulty)).rounded(.up))
            for index in order where clues.count(where: { $0 >= 0 }) > desiredClues {
                let previous = clues[index]
                clues[index] = -1
                if SlitherlinkSolver(size: size, clues: clues).solve().solutionCount != 1 {
                    clues[index] = previous
                }
            }

            let result = SlitherlinkSolver(size: size, clues: clues).solve()
            guard result.solutionCount == 1, let solution = result.firstSolution else { continue }
            let puzzle = SlitherlinkPuzzle(size: size, clues: clues, solution: solution,
                                           score: SlitherlinkSolver.difficultyScore(
                                               size: size, metrics: result.metrics
                                           ))
            if best == nil || prefers(puzzle, over: best!, difficulty: difficulty) {
                best = puzzle
            }
            if clues.count(where: { $0 >= 0 }) <= desiredClues { return puzzle }
        }

        if let best { return best }
        preconditionFailure("Unable to generate a unique Slitherlink puzzle for seed \(seed)")
    }

    private func clueRatio(_ difficulty: GameDifficulty) -> Double {
        switch difficulty {
        case .easy: 0.78
        case .medium: 0.60
        case .hard: 0.44
        }
    }

    private func prefers(_ candidate: SlitherlinkPuzzle, over current: SlitherlinkPuzzle,
                         difficulty: GameDifficulty) -> Bool {
        let candidateClues = candidate.clues.count(where: { $0 >= 0 })
        let currentClues = current.clues.count(where: { $0 >= 0 })
        if candidateClues != currentClues { return candidateClues < currentClues }
        return difficulty == .easy ? candidate.score < current.score : candidate.score > current.score
    }

    private func makeLoop(size: Int, rng: inout SeededGenerator) -> [Int]? {
        let minimum = max(4, size * size / 3)
        let maximum = max(minimum, size * size * 2 / 3)
        let target = Int.random(in: minimum...maximum, using: &rng)
        var cells: Set<Int> = [Int.random(in: 0..<(size * size), using: &rng)]

        while cells.count < target {
            var candidates = Set<Int>()
            for cell in cells {
                let row = cell / size
                let column = cell % size
                for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let r = row + dr
                    let c = column + dc
                    if (0..<size).contains(r), (0..<size).contains(c) {
                        let candidate = r * size + c
                        if !cells.contains(candidate) { candidates.insert(candidate) }
                    }
                }
            }
            var shuffled = Array(candidates)
            shuffled.shuffle(using: &rng)
            guard let candidate = shuffled.first(where: {
                orthogonalNeighborCount($0, cells: cells, size: size) == 1 &&
                    !hasDiagonalPinch(cells.union([$0]), size: size)
            }) else { return nil }
            cells.insert(candidate)
        }

        var loop = Array(repeating: 2, count: 2 * size * (size + 1))
        let horizontalCount = size * (size + 1)
        for row in 0...size {
            for column in 0..<size {
                let above = row > 0 && cells.contains((row - 1) * size + column)
                let below = row < size && cells.contains(row * size + column)
                if above != below { loop[row * size + column] = 1 }
            }
        }
        for row in 0..<size {
            for column in 0...size {
                let left = column > 0 && cells.contains(row * size + column - 1)
                let right = column < size && cells.contains(row * size + column)
                if left != right {
                    loop[horizontalCount + row * (size + 1) + column] = 1
                }
            }
        }
        return SlitherlinkSolver.isSingleLoop(size: size, edges: loop) ? loop : nil
    }

    private func orthogonalNeighborCount(_ cell: Int, cells: Set<Int>, size: Int) -> Int {
        let row = cell / size
        let column = cell % size
        return [(-1, 0), (1, 0), (0, -1), (0, 1)].count { dr, dc in
            let r = row + dr
            let c = column + dc
            return (0..<size).contains(r) && (0..<size).contains(c) &&
                cells.contains(r * size + c)
        }
    }

    private func hasDiagonalPinch(_ cells: Set<Int>, size: Int) -> Bool {
        for row in 0..<size - 1 {
            for column in 0..<size - 1 {
                let nw = cells.contains(row * size + column)
                let ne = cells.contains(row * size + column + 1)
                let sw = cells.contains((row + 1) * size + column)
                let se = cells.contains((row + 1) * size + column + 1)
                if (nw && se && !ne && !sw) || (ne && sw && !nw && !se) { return true }
            }
        }
        return false
    }

    private func deriveClues(size: Int, loop: [Int]) -> [Int] {
        (0..<(size * size)).map { cell in
            SlitherlinkSolver.cellEdges(row: cell / size, column: cell % size, size: size)
                .count(where: { loop[$0] == 1 })
        }
    }
}
