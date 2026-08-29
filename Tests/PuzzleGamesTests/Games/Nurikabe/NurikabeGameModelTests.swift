import XCTest
@testable import PuzzleGames

@MainActor
final class NurikabeGameModelTests: XCTestCase {
    func testInputUndoRestartPersistenceAndCompletion() {
        let suite = "NurikabeModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = NurikabeGameModel(defaults: defaults, seed: 991)
        model.startNewGame(difficulty: .easy)
        XCTAssertEqual(model.size, 5)
        XCTAssertTrue(model.clues.indices.filter { model.clues[$0] > 0 }
            .allSatisfy { model.values[$0] == 2 })

        let editable = model.clues.firstIndex(of: 0)!
        model.select(editable)
        model.input(1)
        XCTAssertEqual(model.values[editable], 1)
        model.undo()
        XCTAssertEqual(model.values[editable], 0)
        model.notesMode = true
        model.mark(editable)
        XCTAssertEqual(model.values[editable], 2)

        let clue = model.clues.firstIndex(where: { $0 > 0 })!
        model.mark(clue)
        XCTAssertEqual(model.values[clue], 2)

        let restored = NurikabeGameModel(defaults: defaults, seed: 7)
        XCTAssertEqual(restored.clues, model.clues)
        XCTAssertEqual(restored.solution, model.solution)
        XCTAssertEqual(restored.values, model.values)

        restored.restart()
        XCTAssertTrue(restored.values.indices.allSatisfy {
            restored.values[$0] == (restored.clues[$0] > 0 ? 2 : 0)
        })
        for index in restored.solution.indices where restored.clues[index] == 0 {
            restored.select(index)
            restored.input(restored.solution[index])
        }
        XCTAssertTrue(restored.completed)
        XCTAssertTrue(restored.presentsCompletion)
    }

    func testCheckReportsWrongMarksAndIgnoresUnknownsAndClues() {
        let suite = "NurikabeCheckTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = NurikabeGameModel(defaults: defaults, seed: 123)
        let editable = model.clues.firstIndex(of: 0)!
        let wrong = model.solution[editable] == 1 ? 2 : 1
        model.select(editable)
        model.input(wrong)
        XCTAssertEqual(model.incorrectPlayerEntryIndexes(), [editable])
        model.erase()
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)
    }
}
