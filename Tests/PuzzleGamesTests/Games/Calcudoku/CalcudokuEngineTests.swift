import CalcudokuEngine
import XCTest

private struct ReferenceCage {
    let members: [Int]
    let target: Int
    let operation: Int
    let tuples: [[Int]]
}

private struct CalcudokuSnapshot {
    let size: Int
    let solution: [Int]
    let cageIDs: [Int]
    let cageTargets: [Int]
    let cageOperations: [Int]

    init(game: UnsafeMutableRawPointer) {
        size = Int(calcudoku_size(game))
        let count = size * size
        solution = (0..<count).map { Int(calcudoku_solution_value(game, Int32($0))) }
        cageIDs = (0..<count).map { Int(calcudoku_cage_id(game, Int32($0))) }
        cageTargets = (0..<count).map { Int(calcudoku_cage_target(game, Int32($0))) }
        cageOperations = (0..<count).map { Int(calcudoku_cage_operation(game, Int32($0))) }
    }
}

private struct IndependentCalcudokuSolver {
    let size: Int
    let cages: [ReferenceCage]
    let cellCage: [Int]

    init(snapshot: CalcudokuSnapshot) {
        size = snapshot.size
        let uniqueIDs = Array(Set(snapshot.cageIDs)).sorted()
        var cageIndexByID: [Int: Int] = [:]
        var builtCages: [ReferenceCage] = []

        for id in uniqueIDs {
            let members = snapshot.cageIDs.indices.filter { snapshot.cageIDs[$0] == id }
            let target = snapshot.cageTargets[members[0]]
            let operation = snapshot.cageOperations[members[0]]
            let tuples = Self.makeTuples(size: size, count: members.count,
                                         target: target, operation: operation)
            cageIndexByID[id] = builtCages.count
            builtCages.append(ReferenceCage(members: members, target: target,
                                            operation: operation, tuples: tuples))
        }
        cages = builtCages
        cellCage = snapshot.cageIDs.map { cageIndexByID[$0]! }
    }

    func solutionCount(limit: Int = 2) -> Int {
        var values = Array(repeating: 0, count: size * size)
        var rowMasks = Array(repeating: 0, count: size)
        var columnMasks = Array(repeating: 0, count: size)
        var count = 0

        func cageAllows(cell: Int, value: Int) -> Bool {
            let cage = cages[cellCage[cell]]
            return cage.tuples.contains { tuple in
                for (position, member) in cage.members.enumerated() {
                    let assigned = member == cell ? value : values[member]
                    if assigned != 0 && tuple[position] != assigned { return false }
                }
                return true
            }
        }

        func recurse() {
            guard count < limit else { return }
            var bestCell = -1
            var bestCandidates: [Int] = []

            for cell in values.indices where values[cell] == 0 {
                let row = cell / size
                let column = cell % size
                let used = rowMasks[row] | columnMasks[column]
                let candidates = (1...size).filter { value in
                    used & (1 << (value - 1)) == 0 && cageAllows(cell: cell, value: value)
                }
                if candidates.isEmpty { return }
                if bestCell < 0 || candidates.count < bestCandidates.count {
                    bestCell = cell
                    bestCandidates = candidates
                    if candidates.count == 1 { break }
                }
            }

            if bestCell < 0 {
                count += 1
                return
            }
            let row = bestCell / size
            let column = bestCell % size
            for value in bestCandidates where count < limit {
                let bit = 1 << (value - 1)
                values[bestCell] = value
                rowMasks[row] |= bit
                columnMasks[column] |= bit
                recurse()
                rowMasks[row] &= ~bit
                columnMasks[column] &= ~bit
                values[bestCell] = 0
            }
        }

        recurse()
        return count
    }

    private static func makeTuples(size: Int, count: Int, target: Int,
                                   operation: Int) -> [[Int]] {
        var result: [[Int]] = []
        var tuple = Array(repeating: 0, count: count)

        func recurse(_ index: Int) {
            if index == count {
                if operationHolds(operation: operation, target: target, values: tuple) {
                    result.append(tuple)
                }
                return
            }
            for value in 1...size {
                tuple[index] = value
                recurse(index + 1)
            }
        }
        recurse(0)
        return result
    }
}

private func operationHolds(operation: Int, target: Int, values: [Int]) -> Bool {
    if values.count == 1 {
        return operation == Int(CALCUDOKU_OPERATION_NONE) && values[0] == target
    }
    switch operation {
    case Int(CALCUDOKU_OPERATION_SUM):
        return values.reduce(0, +) == target
    case Int(CALCUDOKU_OPERATION_DIFFERENCE):
        return values.count == 2 && abs(values[0] - values[1]) == target
    case Int(CALCUDOKU_OPERATION_PRODUCT):
        return values.reduce(1, *) == target
    case Int(CALCUDOKU_OPERATION_RATIO):
        guard values.count == 2 else { return false }
        let high = max(values[0], values[1])
        let low = min(values[0], values[1])
        return low > 0 && high.isMultiple(of: low) && high / low == target
    default:
        return false
    }
}

final class CalcudokuEngineTests: XCTestCase {
    func testNinetyAdditionalPuzzlesWithIndependentExactSolver() throws {
        let game = try XCTUnwrap(calcudoku_create())
        defer { calcudoku_destroy(game) }
        var generated = 0

        for difficulty in 1...3 {
            for iteration in 0..<30 {
                calcudoku_seed(game, UInt64(1_000_000 + difficulty * 10_000 + iteration))
                XCTAssertNotEqual(calcudoku_new_game(game, Int32(difficulty)), 0)
                let snapshot = CalcudokuSnapshot(game: game)

                XCTAssertEqual(snapshot.size, difficulty + 3)
                XCTAssertEqual(calcudoku_solution_count(game, 2), 1)
                validate(snapshot: snapshot, game: game)
                XCTAssertEqual(IndependentCalcudokuSolver(snapshot: snapshot).solutionCount(), 1)
                generated += 1
            }
        }
        XCTAssertEqual(generated, 90)
    }

    func testLoadRoundTripBoundsRestartAndConflicts() throws {
        let source = try XCTUnwrap(calcudoku_create())
        let restored = try XCTUnwrap(calcudoku_create())
        defer {
            calcudoku_destroy(source)
            calcudoku_destroy(restored)
        }
        calcudoku_seed(source, 42)
        XCTAssertNotEqual(calcudoku_new_game(source, 2), 0)
        let snapshot = CalcudokuSnapshot(game: source)
        let count = snapshot.size * snapshot.size
        var values = Array(repeating: Int32(0), count: count)
        values[0] = Int32(snapshot.solution[0])
        var solution = snapshot.solution.map(Int32.init)
        var ids = snapshot.cageIDs.map(Int32.init)
        var targets = snapshot.cageTargets.map(Int32.init)
        var operations = snapshot.cageOperations.map(Int32.init)

        let loaded = values.withUnsafeMutableBufferPointer { valuesBuffer in
            solution.withUnsafeMutableBufferPointer { solutionBuffer in
                ids.withUnsafeMutableBufferPointer { idsBuffer in
                    targets.withUnsafeMutableBufferPointer { targetsBuffer in
                        operations.withUnsafeMutableBufferPointer { operationsBuffer in
                            calcudoku_load_game(
                                restored, Int32(snapshot.size), valuesBuffer.baseAddress,
                                solutionBuffer.baseAddress, idsBuffer.baseAddress,
                                targetsBuffer.baseAddress, operationsBuffer.baseAddress
                            )
                        }
                    }
                }
            }
        }
        XCTAssertNotEqual(loaded, 0)
        XCTAssertEqual(calcudoku_value(restored, 0), values[0])
        XCTAssertEqual(calcudoku_solution_count(restored, 2), 1)
        XCTAssertEqual(CalcudokuSnapshot(game: restored).cageIDs, snapshot.cageIDs)

        XCTAssertEqual(calcudoku_apply_value(restored, -1, 1), 0)
        XCTAssertEqual(calcudoku_apply_value(restored, Int32(count), 1), 0)
        XCTAssertEqual(calcudoku_apply_value(restored, 0, Int32(snapshot.size + 1)), 0)

        calcudoku_restart(restored)
        XCTAssertTrue((0..<count).allSatisfy { calcudoku_value(restored, Int32($0)) == 0 })
        XCTAssertNotEqual(calcudoku_apply_value(restored, 0, 1), 0)
        XCTAssertNotEqual(calcudoku_apply_value(restored, 1, 1), 0)
        XCTAssertNotEqual(calcudoku_has_row_conflict(restored, 0), 0)
        XCTAssertNotEqual(calcudoku_has_row_conflict(restored, 1), 0)
    }

    private func validate(snapshot: CalcudokuSnapshot, game: UnsafeMutableRawPointer,
                          file: StaticString = #filePath, line: UInt = #line) {
        let expected = Set(1...snapshot.size)
        for row in 0..<snapshot.size {
            XCTAssertEqual(Set((0..<snapshot.size).map {
                snapshot.solution[row * snapshot.size + $0]
            }), expected, file: file, line: line)
            XCTAssertEqual(Set((0..<snapshot.size).map {
                snapshot.solution[$0 * snapshot.size + row]
            }), expected, file: file, line: line)
        }

        for cageID in Set(snapshot.cageIDs) {
            let members = snapshot.cageIDs.indices.filter { snapshot.cageIDs[$0] == cageID }
            let target = snapshot.cageTargets[members[0]]
            let operation = snapshot.cageOperations[members[0]]
            XCTAssertTrue((1...4).contains(members.count), file: file, line: line)
            XCTAssertTrue(members.allSatisfy {
                snapshot.cageTargets[$0] == target &&
                    snapshot.cageOperations[$0] == operation
            }, file: file, line: line)
            XCTAssertTrue(operationHolds(operation: operation, target: target,
                                         values: members.map { snapshot.solution[$0] }),
                          file: file, line: line)
            if members.count == 1 {
                XCTAssertEqual(operation, Int(CALCUDOKU_OPERATION_NONE),
                               file: file, line: line)
            }
            if operation == Int(CALCUDOKU_OPERATION_DIFFERENCE) ||
                operation == Int(CALCUDOKU_OPERATION_RATIO) {
                XCTAssertEqual(members.count, 2, file: file, line: line)
            }
            XCTAssertEqual(members.filter {
                calcudoku_cage_anchor(game, Int32($0)) != 0
            }.count, 1, file: file, line: line)
            XCTAssertTrue(isContiguous(members: members, size: snapshot.size),
                          file: file, line: line)
        }
    }

    private func isContiguous(members: [Int], size: Int) -> Bool {
        let memberSet = Set(members)
        var seen: Set<Int> = [members[0]]
        var queue = [members[0]]
        while !queue.isEmpty {
            let cell = queue.removeFirst()
            let row = cell / size
            let column = cell % size
            let candidates = [
                row > 0 ? cell - size : -1,
                row + 1 < size ? cell + size : -1,
                column > 0 ? cell - 1 : -1,
                column + 1 < size ? cell + 1 : -1
            ]
            for neighbour in candidates where memberSet.contains(neighbour) &&
                !seen.contains(neighbour) {
                seen.insert(neighbour)
                queue.append(neighbour)
            }
        }
        return seen == memberSet
    }
}
