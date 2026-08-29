import Foundation

struct NurikabePuzzle: Equatable {
    let size: Int
    let clues: [Int]
    let solution: [Int] // 1 = sea, 2 = island
    let score: Int
}

struct NurikabeSolveMetrics: Equatable {
    var forcedAssignments = 0
    var propagationRounds = 0
    var decisions = 0
    var backtracks = 0
    var maxDepth = 0

    var score: Int {
        forcedAssignments + propagationRounds * 10 + decisions * 110 +
            backtracks * 150 + maxDepth * 35
    }
}

struct NurikabeSolveResult {
    let solutionCount: Int
    let firstSolution: [Int]?
    let metrics: NurikabeSolveMetrics
}

struct NurikabeSolver {
    let size: Int
    let clues: [Int] // 0 = no clue; positive = island size

    func solve(limit: Int = 2) -> NurikabeSolveResult {
        guard (4...8).contains(size), clues.count == size * size, limit > 0,
              clues.allSatisfy({ (0...size * size).contains($0) }),
              clues.contains(where: { $0 > 0 }),
              clues.reduce(0, +) < size * size else {
            return NurikabeSolveResult(solutionCount: 0, firstSolution: nil,
                                       metrics: NurikabeSolveMetrics())
        }
        var states = Array(repeating: Int8(-1), count: size * size)
        for index in clues.indices where clues[index] > 0 { states[index] = 1 }
        var search = Search(size: size, clues: clues, limit: min(2, limit))
        search.search(states: states, depth: 0)
        return NurikabeSolveResult(solutionCount: search.solutionCount,
                                   firstSolution: search.firstSolution,
                                   metrics: search.metrics)
    }

    static func isValidSolution(size: Int, clues: [Int], values: [Int]) -> Bool {
        guard clues.count == size * size, values.count == size * size,
              values.allSatisfy({ $0 == 1 || $0 == 2 }) else { return false }
        let islandCells = Set(values.indices.filter { values[$0] == 2 })
        let seaCells = Set(values.indices.filter { values[$0] == 1 })
        guard !seaCells.isEmpty, connected(seaCells, size: size) else { return false }
        for row in 0..<size - 1 {
            for column in 0..<size - 1 {
                let cells = [row * size + column, row * size + column + 1,
                             (row + 1) * size + column, (row + 1) * size + column + 1]
                if cells.allSatisfy({ seaCells.contains($0) }) { return false }
            }
        }

        var remaining = islandCells
        while let start = remaining.first {
            let component = flood(from: start, within: remaining, size: size)
            let componentClues = component.filter { clues[$0] > 0 }
            guard componentClues.count == 1,
                  clues[componentClues.first!] == component.count else { return false }
            remaining.subtract(component)
        }
        return clues.indices.filter { clues[$0] > 0 }.allSatisfy { islandCells.contains($0) }
    }

    static func difficultyScore(size: Int, metrics: NurikabeSolveMetrics) -> Int {
        size * size * 1_000 + metrics.score
    }

    static func neighbors(of index: Int, size: Int) -> [Int] {
        let row = index / size
        let column = index % size
        var result: [Int] = []
        if row > 0 { result.append(index - size) }
        if row + 1 < size { result.append(index + size) }
        if column > 0 { result.append(index - 1) }
        if column + 1 < size { result.append(index + 1) }
        return result
    }

    private static func connected(_ cells: Set<Int>, size: Int) -> Bool {
        guard let start = cells.first else { return false }
        return flood(from: start, within: cells, size: size).count == cells.count
    }

    private static func flood(from start: Int, within cells: Set<Int>,
                              size: Int) -> Set<Int> {
        var visited: Set<Int> = [start]
        var stack = [start]
        while let cell = stack.popLast() {
            for neighbor in neighbors(of: cell, size: size)
                where cells.contains(neighbor) && visited.insert(neighbor).inserted {
                stack.append(neighbor)
            }
        }
        return visited
    }

    private struct Search {
        let size: Int
        let clues: [Int]
        let limit: Int
        let targetIslandCount: Int
        let targetSeaCount: Int
        var solutionCount = 0
        var firstSolution: [Int]?
        var metrics = NurikabeSolveMetrics()

        init(size: Int, clues: [Int], limit: Int) {
            self.size = size
            self.clues = clues
            self.limit = limit
            targetIslandCount = clues.reduce(0, +)
            targetSeaCount = size * size - targetIslandCount
        }

        mutating func search(states initialStates: [Int8], depth: Int) {
            guard solutionCount < limit else { return }
            var states = initialStates
            let solutionsBefore = solutionCount
            guard propagate(&states) else {
                if depth > 0 { metrics.backtracks += 1 }
                return
            }
            metrics.maxDepth = max(metrics.maxDepth, depth)
            guard let cell = chooseCell(states) else {
                let publicValues = states.map { $0 == 0 ? 1 : 2 }
                guard NurikabeSolver.isValidSolution(size: size, clues: clues,
                                                      values: publicValues) else {
                    if depth > 0 { metrics.backtracks += 1 }
                    return
                }
                if firstSolution == nil { firstSolution = publicValues }
                solutionCount += 1
                return
            }

            metrics.decisions += 1
            let islandCount = states.count(where: { $0 == 1 })
            let seaCount = states.count(where: { $0 == 0 })
            let islandPressure = targetIslandCount - islandCount
            let seaPressure = targetSeaCount - seaCount
            let order: [Int8] = seaPressure > islandPressure ? [0, 1] : [1, 0]
            for value in order where solutionCount < limit {
                var branch = states
                branch[cell] = value
                search(states: branch, depth: depth + 1)
            }
            if solutionCount == solutionsBefore && depth > 0 { metrics.backtracks += 1 }
        }

        mutating func propagate(_ states: inout [Int8]) -> Bool {
            var changed = true
            while changed {
                changed = false
                metrics.propagationRounds += 1
                for index in clues.indices where clues[index] > 0 {
                    if !assign(1, to: index, states: &states, changed: &changed) { return false }
                }

                let islandCount = states.count(where: { $0 == 1 })
                let seaCount = states.count(where: { $0 == 0 })
                let unknown = states.indices.filter { states[$0] == -1 }
                if islandCount > targetIslandCount || seaCount > targetSeaCount ||
                    islandCount + unknown.count < targetIslandCount ||
                    seaCount + unknown.count < targetSeaCount { return false }
                if islandCount == targetIslandCount {
                    for cell in unknown where !assign(0, to: cell, states: &states,
                                                      changed: &changed) { return false }
                } else if seaCount == targetSeaCount {
                    for cell in unknown where !assign(1, to: cell, states: &states,
                                                      changed: &changed) { return false }
                }
                if changed { continue }

                for row in 0..<size - 1 {
                    for column in 0..<size - 1 {
                        let square = [row * size + column, row * size + column + 1,
                                      (row + 1) * size + column,
                                      (row + 1) * size + column + 1]
                        let seas = square.count(where: { states[$0] == 0 })
                        let blanks = square.filter { states[$0] == -1 }
                        if seas == 4 { return false }
                        if seas == 3, blanks.count == 1,
                           !assign(1, to: blanks[0], states: &states, changed: &changed) {
                            return false
                        }
                    }
                }
                if changed { continue }

                let islandComponents = components(of: 1, states: states)
                var componentForCell: [Int: Int] = [:]
                var ownerForComponent: [Int?] = []
                for (componentIndex, component) in islandComponents.enumerated() {
                    for cell in component { componentForCell[cell] = componentIndex }
                    let clueCells = component.filter { clues[$0] > 0 }
                    if clueCells.count > 1 { return false }
                    let owner = clueCells.first
                    ownerForComponent.append(owner)
                    let frontier = Set(component.flatMap { NurikabeSolver.neighbors(of: $0,
                                                                                   size: size) })
                        .filter { states[$0] == -1 }
                    if let owner {
                        let target = clues[owner]
                        if component.count > target { return false }
                        if component.count == target {
                            for cell in frontier where !assign(0, to: cell, states: &states,
                                                              changed: &changed) { return false }
                        } else if frontier.isEmpty { return false }
                    }
                }
                if changed { continue }

                for cell in states.indices where states[cell] == -1 {
                    let adjacentOwners = Set(NurikabeSolver.neighbors(of: cell, size: size)
                        .compactMap { neighbor -> Int? in
                            guard states[neighbor] == 1,
                                  let component = componentForCell[neighbor] else { return nil }
                            return ownerForComponent[component]
                        })
                    if adjacentOwners.count > 1,
                       !assign(0, to: cell, states: &states, changed: &changed) { return false }
                }
                if changed { continue }

                var reachableByAnyClue = Set<Int>()
                for clueCell in clues.indices where clues[clueCell] > 0 {
                    let reachable = reachableCells(for: clueCell, states: states,
                                                   componentForCell: componentForCell,
                                                   ownerForComponent: ownerForComponent)
                    let componentSize = islandComponents[componentForCell[clueCell] ?? 0].count
                    if reachable.count < clues[clueCell] { return false }
                    reachableByAnyClue.formUnion(reachable)
                    if reachable.count == clues[clueCell] && componentSize < clues[clueCell] {
                        for cell in reachable where states[cell] == -1 &&
                            !assign(1, to: cell, states: &states, changed: &changed) { return false }
                        if changed { break }
                    }
                }
                if changed { continue }
                for cell in states.indices where states[cell] == -1 &&
                    !reachableByAnyClue.contains(cell) {
                    if !assign(0, to: cell, states: &states, changed: &changed) { return false }
                }
                if changed { continue }
                for (componentIndex, component) in islandComponents.enumerated()
                    where ownerForComponent[componentIndex] == nil &&
                        component.isDisjoint(with: reachableByAnyClue) { return false }

                let seaComponents = components(of: 0, states: states)
                if let firstSea = seaComponents.first?.first {
                    let potentialSea = Set(states.indices.filter { states[$0] != 1 })
                    let connectedPotential = flood(from: firstSea, within: potentialSea)
                    if states.indices.contains(where: { states[$0] == 0 &&
                        !connectedPotential.contains($0) }) { return false }
                }
                if seaComponents.count > 1 {
                    var forcedSea = Set<Int>()
                    for component in seaComponents {
                        let frontier = Set(component.flatMap {
                            NurikabeSolver.neighbors(of: $0, size: size)
                        }).filter { states[$0] == -1 }
                        if frontier.isEmpty { return false }
                        if frontier.count == 1 { forcedSea.insert(frontier.first!) }
                    }
                    for cell in forcedSea where
                        !assign(0, to: cell, states: &states, changed: &changed) {
                        return false
                    }
                }
                if changed { continue }
            }
            return true
        }

        func chooseCell(_ states: [Int8]) -> Int? {
            states.indices.filter { states[$0] == -1 }.max { first, second in
                pressure(first, states: states) < pressure(second, states: states)
            }
        }

        func pressure(_ cell: Int, states: [Int8]) -> Int {
            var score = NurikabeSolver.neighbors(of: cell, size: size)
                .count(where: { states[$0] != -1 }) * 3
            let row = cell / size
            let column = cell % size
            for r in max(0, row - 1)...min(size - 2, row) {
                for c in max(0, column - 1)...min(size - 2, column) {
                    let square = [r * size + c, r * size + c + 1,
                                  (r + 1) * size + c, (r + 1) * size + c + 1]
                    score += square.count(where: { states[$0] == 0 }) * 2
                }
            }
            return score
        }

        mutating func assign(_ value: Int8, to cell: Int, states: inout [Int8],
                             changed: inout Bool) -> Bool {
            if states[cell] == value { return true }
            if states[cell] != -1 { return false }
            states[cell] = value
            metrics.forcedAssignments += 1
            changed = true
            return true
        }

        func components(of value: Int8, states: [Int8]) -> [Set<Int>] {
            var remaining = Set(states.indices.filter { states[$0] == value })
            var result: [Set<Int>] = []
            while let start = remaining.min() {
                let component = flood(from: start, within: remaining)
                result.append(component)
                remaining.subtract(component)
            }
            return result
        }

        func flood(from start: Int, within cells: Set<Int>) -> Set<Int> {
            var visited: Set<Int> = [start]
            var stack = [start]
            while let cell = stack.popLast() {
                for neighbor in NurikabeSolver.neighbors(of: cell, size: size)
                    where cells.contains(neighbor) && visited.insert(neighbor).inserted {
                    stack.append(neighbor)
                }
            }
            return visited
        }

        func reachableCells(for clueCell: Int, states: [Int8],
                            componentForCell: [Int: Int],
                            ownerForComponent: [Int?]) -> Set<Int> {
            var visited: Set<Int> = [clueCell]
            var queue = [clueCell]
            while !queue.isEmpty {
                let cell = queue.removeFirst()
                for neighbor in NurikabeSolver.neighbors(of: cell, size: size) {
                    guard states[neighbor] != 0, !visited.contains(neighbor) else { continue }
                    if states[neighbor] == 1, let component = componentForCell[neighbor],
                       let owner = ownerForComponent[component], owner != clueCell { continue }
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }
            return visited
        }
    }
}

struct NurikabeGenerator {
    func generate(difficulty: GameDifficulty, seed: UInt64) -> NurikabePuzzle {
        let size = difficulty.rawValue + 4
        var rng = SeededGenerator(seed: seed)

        for _ in 0..<160 {
            guard let generated = makeSolution(size: size, difficulty: difficulty, rng: &rng) else {
                continue
            }
            let islandComponents = components(of: 2, values: generated, size: size)
            guard islandComponents.count >= 3 else { continue }
            var clues = Array(repeating: 0, count: size * size)
            for component in islandComponents {
                let clueCell = component.randomElement(using: &rng)!
                clues[clueCell] = component.count
            }
            let result = NurikabeSolver(size: size, clues: clues).solve()
            guard result.solutionCount == 1, result.firstSolution == generated else { continue }
            let candidate = NurikabePuzzle(
                size: size, clues: clues, solution: generated,
                score: NurikabeSolver.difficultyScore(size: size, metrics: result.metrics)
            )
            return candidate
        }
        preconditionFailure("Unable to generate a unique Nurikabe puzzle for seed \(seed)")
    }

    private func makeSolution(size: Int, difficulty: GameDifficulty,
                              rng: inout SeededGenerator) -> [Int]? {
        let density: Double = switch difficulty {
        case .easy: 0.48
        case .medium: 0.52
        case .hard: 0.56
        }
        let targetSea = Int((Double(size * size) * density).rounded())
        var sea: Set<Int> = [Int.random(in: 0..<(size * size), using: &rng)]
        while sea.count < targetSea {
            var candidates = Set<Int>()
            for cell in sea {
                for neighbor in NurikabeSolver.neighbors(of: cell, size: size)
                    where !sea.contains(neighbor) {
                    candidates.insert(neighbor)
                }
            }
            var valid = Array(candidates.filter { candidate in
                NurikabeSolver.neighbors(of: candidate, size: size)
                    .count(where: { sea.contains($0) }) == 1
            })
            valid.shuffle(using: &rng)
            guard let next = valid.first else { return nil }
            sea.insert(next)
        }
        var solution = Array(repeating: 2, count: size * size)
        for cell in sea { solution[cell] = 1 }
        guard NurikabeSolver.isValidSolution(
            size: size,
            clues: cluesForSolution(solution, size: size),
            values: solution
        ) else { return nil }
        return solution
    }

    private func cluesForSolution(_ solution: [Int], size: Int) -> [Int] {
        var clues = Array(repeating: 0, count: size * size)
        for component in components(of: 2, values: solution, size: size) {
            if let cell = component.first { clues[cell] = component.count }
        }
        return clues
    }

    private func components(of value: Int, values: [Int], size: Int) -> [Set<Int>] {
        var remaining = Set(values.indices.filter { values[$0] == value })
        var result: [Set<Int>] = []
        while let start = remaining.min() {
            var component: Set<Int> = [start]
            var stack = [start]
            while let cell = stack.popLast() {
                for neighbor in NurikabeSolver.neighbors(of: cell, size: size)
                    where remaining.contains(neighbor) && component.insert(neighbor).inserted {
                    stack.append(neighbor)
                }
            }
            result.append(component)
            remaining.subtract(component)
        }
        return result
    }

}
