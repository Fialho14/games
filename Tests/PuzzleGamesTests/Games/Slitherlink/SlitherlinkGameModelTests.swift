import AppKit
import XCTest
@testable import PuzzleGames

@MainActor
final class SlitherlinkGameModelTests: XCTestCase {
    func testInputUndoRestartCompletionAndPersistence() {
        let suite = "SlitherlinkGameModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = SlitherlinkGameModel(defaults: defaults, seed: 77)
        model.startNewGame(difficulty: .easy)
        XCTAssertEqual(model.size, 4)
        XCTAssertFalse(model.completed)

        model.select(1)
        model.input(1)
        XCTAssertEqual(model.values[1], 1)
        model.undo()
        XCTAssertEqual(model.values[1], 0)
        model.notesMode = true
        model.mark(2)
        XCTAssertEqual(model.values[2], 2)

        let restored = SlitherlinkGameModel(defaults: defaults, seed: 99)
        XCTAssertEqual(restored.clues, model.clues)
        XCTAssertEqual(restored.solution, model.solution)
        XCTAssertEqual(restored.values, model.values)
        XCTAssertEqual(restored.selectedIndex, model.selectedIndex)

        restored.restart()
        XCTAssertTrue(restored.values.allSatisfy { $0 == 0 })
        for edge in restored.solution.indices where restored.solution[edge] == 1 {
            restored.select(edge)
            restored.input(1)
        }
        XCTAssertTrue(restored.completed)
        XCTAssertTrue(restored.presentsCompletion)
    }

    func testCheckReportsWrongMarkedEdgesButIgnoresUnknowns() {
        let suite = "SlitherlinkCheckTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SlitherlinkGameModel(defaults: defaults, seed: 1234)

        let excluded = model.solution.firstIndex(of: 2)!
        model.select(excluded)
        model.input(1)
        XCTAssertEqual(model.incorrectPlayerEntryIndexes(), [excluded])
        model.erase()
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)
    }

    func testRotateSelectionSwitchesOrientationWithoutChangingMarks() {
        let suite = "SlitherlinkRotationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SlitherlinkGameModel(defaults: defaults, seed: 4321)
        model.startNewGame(difficulty: .easy)

        let horizontalCount = model.size * (model.size + 1)
        let horizontal = model.size + 1
        let vertical = horizontalCount + (model.size + 1) + 1
        let marks = model.values

        model.select(horizontal)
        model.rotateSelection()
        XCTAssertEqual(model.selectedIndex, vertical)
        XCTAssertEqual(model.values, marks)

        model.rotateSelection()
        XCTAssertEqual(model.selectedIndex, horizontal)

        let bottomHorizontal = model.size * model.size + model.size - 1
        model.select(bottomHorizontal)
        model.rotateSelection()
        XCTAssertEqual(
            model.selectedIndex,
            horizontalCount + (model.size - 1) * (model.size + 1) + model.size - 1
        )

        let rightVertical = horizontalCount + (model.size - 1) * (model.size + 1) + model.size
        model.select(rightVertical)
        model.rotateSelection()
        XCTAssertEqual(model.selectedIndex, (model.size - 1) * model.size + model.size - 1)
    }

    func testShiftKeyDownMapsToOneRotationAction() throws {
        let shiftDown = try XCTUnwrap(shiftEvent(modifierFlags: .shift))
        XCTAssertEqual(KeyboardEventMapper.action(for: shiftDown), .rotateSelection)
        let rightShiftDown = try XCTUnwrap(
            shiftEvent(modifierFlags: .shift, keyCode: 60)
        )
        XCTAssertEqual(KeyboardEventMapper.action(for: rightShiftDown), .rotateSelection)

        let shiftUp = try XCTUnwrap(shiftEvent(modifierFlags: []))
        XCTAssertNil(KeyboardEventMapper.action(for: shiftUp))

        let commandShift = try XCTUnwrap(
            shiftEvent(modifierFlags: [.command, .shift])
        )
        XCTAssertNil(KeyboardEventMapper.action(for: commandShift))
    }

    private func shiftEvent(
        modifierFlags: NSEvent.ModifierFlags,
        keyCode: UInt16 = 56
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
