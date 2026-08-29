import XCTest
@testable import PuzzleGames

@MainActor
final class SkyscrapersGameModelTests: XCTestCase {
    func testDifficultyInputNotesUndoConflictsRestartPersistenceAndCompletion() {
        let suite = "SkyscrapersModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SkyscrapersGameModel(defaults: defaults, seed: 8080)

        model.startNewGame(difficulty: .easy)
        XCTAssertEqual(model.size, 4)
        model.select(0)
        model.notesMode = true
        model.input(2)
        XCTAssertTrue(model.noteIsSet(2, at: 0))
        model.notesMode = false
        model.input(model.solution[0])
        XCTAssertEqual(model.values[0], model.solution[0])
        XCTAssertEqual(model.notes[0], 0)
        model.undo()
        XCTAssertEqual(model.values[0], 0)
        XCTAssertTrue(model.noteIsSet(2, at: 0))

        model.input(1)
        model.select(1)
        model.input(1)
        XCTAssertTrue(model.isConflict(at: 0))
        XCTAssertTrue(model.isConflict(at: 1))

        let restored = SkyscrapersGameModel(defaults: defaults, seed: 99)
        XCTAssertEqual(restored.clues, model.clues)
        XCTAssertEqual(restored.solution, model.solution)
        XCTAssertEqual(restored.values, model.values)

        restored.restart()
        XCTAssertTrue(restored.values.allSatisfy { $0 == 0 })
        for index in restored.solution.indices {
            restored.select(index)
            restored.input(restored.solution[index])
        }
        XCTAssertTrue(restored.completed)
        XCTAssertTrue(restored.presentsCompletion)
    }

    func testCheckReportsWrongValuesAndIgnoresNotesAndEmptyCells() {
        let suite = "SkyscrapersCheckTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SkyscrapersGameModel(defaults: defaults, seed: 44)
        let wrong = model.solution[0] == 1 ? 2 : 1
        model.input(wrong)
        XCTAssertEqual(model.incorrectPlayerEntryIndexes(), [0])
        model.erase()
        model.notesMode = true
        model.input(wrong)
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)
    }
}
