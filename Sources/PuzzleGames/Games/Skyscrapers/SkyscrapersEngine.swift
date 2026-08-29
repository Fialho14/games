import Foundation

struct SkyscrapersClues: Codable, Equatable {
    var top: [Int]
    var bottom: [Int]
    var left: [Int]
    var right: [Int]

    var all: [Int] { top + bottom + left + right }

    func isValid(for size: Int) -> Bool {
        [top, bottom, left, right].allSatisfy { side in
            side.count == size && side.allSatisfy { (0...size).contains($0) }
        }
    }

    subscript(compact index: Int) -> Int {
        get {
            let size = top.count
            return switch index / size {
            case 0: top[index % size]
            case 1: bottom[index % size]
            case 2: left[index % size]
            default: right[index % size]
            }
        }
        set {
            let size = top.count
            switch index / size {
            case 0: top[index % size] = newValue
            case 1: bottom[index % size] = newValue
            case 2: left[index % size] = newValue
            default: right[index % size] = newValue
            }
        }
    }
}

struct SkyscrapersPuzzle: Equatable {
    let size: Int
    let clues: SkyscrapersClues
    let solution: [Int]
    let score: Int
}

struct SkyscrapersSolveMetrics: Equatable {
    var domainEliminations = 0
    var propagationRounds = 0
    var decisions = 0
    var backtracks = 0
    var maxDepth = 0

    var score: Int {
        domainEliminations + propagationRounds * 8 + decisions * 100 +
            backtracks * 140 + maxDepth * 30
    }
}

struct SkyscrapersSolveResult {
    let solutionCount: Int
    let firstSolution: [Int]?
    let metrics: SkyscrapersSolveMetrics
}

struct SkyscrapersSolver {
    let size: Int
    let clues: SkyscrapersClues

    func solve(limit: Int = 2) -> SkyscrapersSolveResult {
        guard (4...6).contains(size), clues.isValid(for: size), limit > 0 else {
            return SkyscrapersSolveResult(solutionCount: 0, firstSolution: nil,
                                          metrics: SkyscrapersSolveMetrics())
        }
        let permutations = SkyscrapersPermutationCache.bySize[size] ?? []
        var rowDomains = Array(repeating: Array(permutations.indices), count: size)
        var columnDomains = rowDomains
        for index in 0..<size {
            rowDomains[index].removeAll { permutation in
                !Self.matches(permutations[permutation], near: clues.left[index],
                              far: clues.right[index])
            }
            columnDomains[index].removeAll { permutation in
                !Self.matches(permutations[permutation], near: clues.top[index],
                              far: clues.bottom[index])
            }
        }

        var search = Search(size: size, clues: clues, permutations: permutations,
                            limit: min(2, limit))
        search.search(rows: rowDomains, columns: columnDomains, depth: 0)
        return SkyscrapersSolveResult(solutionCount: search.solutionCount,
                                      firstSolution: search.firstSolution,
                                      metrics: search.metrics)
    }

    static func visibility<Values: Collection>(_ values: Values) -> Int
        where Values.Element == Int {
        var tallest = 0
        var visible = 0
        for value in values where value > tallest {
            tallest = value
            visible += 1
        }
        return visible
    }

    static func isValidSolution(size: Int, clues: SkyscrapersClues,
                                values: [Int]) -> Bool {
        guard clues.isValid(for: size), values.count == size * size else { return false }
        let expected = Set(1...size)
        for index in 0..<size {
            let row = Array(values[index * size..<(index + 1) * size])
            let column = (0..<size).map { values[$0 * size + index] }
            guard Set(row) == expected, Set(column) == expected,
                  matches(row, near: clues.left[index], far: clues.right[index]),
                  matches(column, near: clues.top[index], far: clues.bottom[index]) else {
                return false
            }
        }
        return true
    }

    static func difficultyScore(size: Int, metrics: SkyscrapersSolveMetrics) -> Int {
        size * size * 1_000 + metrics.score
    }

    private static func matches(_ values: [Int], near: Int, far: Int) -> Bool {
        (near == 0 || visibility(values) == near) &&
            (far == 0 || visibility(values.reversed()) == far)
    }

    private struct Search {
        let size: Int
        let clues: SkyscrapersClues
        let permutations: [[Int]]
        let limit: Int
        var solutionCount = 0
        var firstSolution: [Int]?
        var metrics = SkyscrapersSolveMetrics()

        mutating func search(rows initialRows: [[Int]], columns initialColumns: [[Int]],
                             depth: Int) {
            guard solutionCount < limit else { return }
            var rows = initialRows
            var columns = initialColumns
            let solutionsBefore = solutionCount
            guard propagate(rows: &rows, columns: &columns) else {
                if depth > 0 { metrics.backtracks += 1 }
                return
            }
            metrics.maxDepth = max(metrics.maxDepth, depth)

            if rows.allSatisfy({ $0.count == 1 }) {
                let solution = rows.flatMap { permutations[$0[0]] }
                guard SkyscrapersSolver.isValidSolution(size: size, clues: clues,
                                                         values: solution) else {
                    if depth > 0 { metrics.backtracks += 1 }
                    return
                }
                if firstSolution == nil { firstSolution = solution }
                solutionCount += 1
                return
            }

            let rowChoice = rows.indices.filter { rows[$0].count > 1 }
                .min(by: { rows[$0].count < rows[$1].count })
            let columnChoice = columns.indices.filter { columns[$0].count > 1 }
                .min(by: { columns[$0].count < columns[$1].count })
            let chooseRow: Bool
            if let rowChoice, let columnChoice {
                chooseRow = rows[rowChoice].count <= columns[columnChoice].count
            } else {
                chooseRow = rowChoice != nil
            }

            metrics.decisions += 1
            if chooseRow, let index = rowChoice {
                for permutation in rows[index] where solutionCount < limit {
                    var branchRows = rows
                    branchRows[index] = [permutation]
                    search(rows: branchRows, columns: columns, depth: depth + 1)
                }
            } else if let index = columnChoice {
                for permutation in columns[index] where solutionCount < limit {
                    var branchColumns = columns
                    branchColumns[index] = [permutation]
                    search(rows: rows, columns: branchColumns, depth: depth + 1)
                }
            }
            if solutionCount == solutionsBefore && depth > 0 { metrics.backtracks += 1 }
        }

        mutating func propagate(rows: inout [[Int]], columns: inout [[Int]]) -> Bool {
            var changed = true
            while changed {
                changed = false
                metrics.propagationRounds += 1
                for row in 0..<size {
                    for column in 0..<size {
                        var rowMask = 0
                        for permutation in rows[row] {
                            rowMask |= 1 << (permutations[permutation][column] - 1)
                        }
                        var columnMask = 0
                        for permutation in columns[column] {
                            columnMask |= 1 << (permutations[permutation][row] - 1)
                        }
                        let allowed = rowMask & columnMask
                        if allowed == 0 { return false }

                        let oldRowCount = rows[row].count
                        rows[row].removeAll { permutation in
                            allowed & (1 << (permutations[permutation][column] - 1)) == 0
                        }
                        let oldColumnCount = columns[column].count
                        columns[column].removeAll { permutation in
                            allowed & (1 << (permutations[permutation][row] - 1)) == 0
                        }
                        guard !rows[row].isEmpty, !columns[column].isEmpty else { return false }
                        let removed = oldRowCount - rows[row].count +
                            oldColumnCount - columns[column].count
                        if removed > 0 {
                            metrics.domainEliminations += removed
                            changed = true
                        }
                    }
                }
            }
            return true
        }
    }
}

struct SkyscrapersGenerator {
    func generate(difficulty: GameDifficulty, seed: UInt64) -> SkyscrapersPuzzle {
        let size = difficulty.rawValue + 3
        var rng = SeededGenerator(seed: seed)
        var best: SkyscrapersPuzzle?
        let desiredCandidates = difficulty == .hard ? 6 : 4
        var acceptedCandidates = 0

        // Complete visibility clues do not uniquely identify every Latin square.
        // Search for suitable solution bases first; clue removal is only attempted
        // after exact uniqueness has already been established.
        for _ in 0..<128 {
            guard let solution = makeLatinSquare(size: size, rng: &rng) else { continue }
            var clues = deriveClues(size: size, solution: solution)
            let complete = SkyscrapersSolver(size: size, clues: clues).solve()
            guard complete.solutionCount == 1, complete.firstSolution == solution else { continue }

            var order = Array(0..<(size * 4))
            order.shuffle(using: &rng)
            let desired = desiredClueCount(size: size, difficulty: difficulty)
            for clueIndex in order where clues.all.count(where: { $0 > 0 }) > desired {
                let previous = clues[compact: clueIndex]
                clues[compact: clueIndex] = 0
                let result = SkyscrapersSolver(size: size, clues: clues).solve()
                if result.solutionCount != 1 || result.firstSolution != solution {
                    clues[compact: clueIndex] = previous
                }
            }

            let result = SkyscrapersSolver(size: size, clues: clues).solve()
            guard result.solutionCount == 1, result.firstSolution == solution else { continue }
            let candidate = SkyscrapersPuzzle(
                size: size, clues: clues, solution: solution,
                score: SkyscrapersSolver.difficultyScore(size: size,
                                                         metrics: result.metrics)
            )
            if best == nil || prefers(candidate, over: best!, difficulty: difficulty) {
                best = candidate
            }
            acceptedCandidates += 1
            if acceptedCandidates >= desiredCandidates { break }
        }
        guard let best else {
            preconditionFailure("Unable to generate a unique Skyscrapers puzzle for seed \(seed)")
        }
        return best
    }

    private func desiredClueCount(size: Int, difficulty: GameDifficulty) -> Int {
        switch difficulty {
        case .easy: Int((Double(size * 4) * 0.78).rounded(.up))
        case .medium: Int((Double(size * 4) * 0.58).rounded(.up))
        case .hard: Int((Double(size * 4) * 0.42).rounded(.up))
        }
    }

    private func prefers(_ candidate: SkyscrapersPuzzle, over current: SkyscrapersPuzzle,
                         difficulty: GameDifficulty) -> Bool {
        let candidateClues = candidate.clues.all.count(where: { $0 > 0 })
        let currentClues = current.clues.all.count(where: { $0 > 0 })
        if candidateClues != currentClues {
            return difficulty == .easy ? candidateClues > currentClues : candidateClues < currentClues
        }
        return difficulty == .easy ? candidate.score < current.score : candidate.score > current.score
    }

    private func makeLatinSquare(size: Int, rng: inout SeededGenerator) -> [Int]? {
        var values = Array(repeating: 0, count: size * size)
        var rowMasks = Array(repeating: 0, count: size)
        var columnMasks = Array(repeating: 0, count: size)
        let all = (1 << size) - 1

        func fill(_ rng: inout SeededGenerator) -> Bool {
            var bestIndex: Int?
            var bestMask = 0
            var bestCount = size + 1
            for index in values.indices where values[index] == 0 {
                let row = index / size
                let column = index % size
                let mask = all & ~(rowMasks[row] | columnMasks[column])
                let count = mask.nonzeroBitCount
                if count == 0 { return false }
                if count < bestCount {
                    bestIndex = index
                    bestMask = mask
                    bestCount = count
                }
            }
            guard let index = bestIndex else { return true }
            var candidates = (1...size).filter { bestMask & (1 << ($0 - 1)) != 0 }
            candidates.shuffle(using: &rng)
            let row = index / size
            let column = index % size
            for value in candidates {
                let bit = 1 << (value - 1)
                values[index] = value
                rowMasks[row] |= bit
                columnMasks[column] |= bit
                if fill(&rng) { return true }
                values[index] = 0
                rowMasks[row] &= ~bit
                columnMasks[column] &= ~bit
            }
            return false
        }
        return fill(&rng) ? values : nil
    }

    private func deriveClues(size: Int, solution: [Int]) -> SkyscrapersClues {
        var top: [Int] = []
        var bottom: [Int] = []
        var left: [Int] = []
        var right: [Int] = []
        for index in 0..<size {
            let row = Array(solution[index * size..<(index + 1) * size])
            let column = (0..<size).map { solution[$0 * size + index] }
            left.append(SkyscrapersSolver.visibility(row))
            right.append(SkyscrapersSolver.visibility(row.reversed()))
            top.append(SkyscrapersSolver.visibility(column))
            bottom.append(SkyscrapersSolver.visibility(column.reversed()))
        }
        return SkyscrapersClues(top: top, bottom: bottom, left: left, right: right)
    }
}

private enum SkyscrapersPermutationCache {
    static let bySize: [Int: [[Int]]] = Dictionary(uniqueKeysWithValues: (4...6).map { size in
        (size, makePermutations(size: size))
    })

    private static func makePermutations(size: Int) -> [[Int]] {
        var result: [[Int]] = []
        var current: [Int] = []
        var used = Array(repeating: false, count: size + 1)
        func build() {
            if current.count == size {
                result.append(current)
                return
            }
            for value in 1...size where !used[value] {
                used[value] = true
                current.append(value)
                build()
                current.removeLast()
                used[value] = false
            }
        }
        build()
        return result
    }
}
