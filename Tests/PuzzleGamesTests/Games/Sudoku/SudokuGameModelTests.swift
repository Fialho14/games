import AppKit
import SwiftUI
import XCTest
@testable import PuzzleGames

@MainActor
final class SudokuGameModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "sudoku.mac.saved-game.v1")
    }

    func testDifficultyInputEraseUndoAndRestart() {
        let model = SudokuGameModel()
        for (difficulty, emptyCount) in [(GameDifficulty.easy, 20), (.medium, 35), (.hard, 50)] {
            model.startNewGame(difficulty: difficulty)
            XCTAssertEqual(model.values.filter { $0 == 0 }.count, emptyCount)
        }

        guard let editable = model.givens.firstIndex(of: false) else {
            return XCTFail("Expected an editable cell")
        }
        model.select(editable)
        let answer = model.solution[editable]
        model.input(answer)
        XCTAssertEqual(model.values[editable], answer)
        model.erase()
        XCTAssertEqual(model.values[editable], 0)
        model.undo()
        XCTAssertEqual(model.values[editable], answer)
        model.restart()
        XCTAssertEqual(model.values[editable], 0)
    }

    func testNotesAndUndo() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .medium)
        let editable = model.givens.firstIndex(of: false)!
        model.select(editable)
        model.notesMode = true
        model.input(4)
        XCTAssertTrue(model.noteIsSet(4, at: editable))
        XCTAssertEqual(model.values[editable], 0)
        model.undo()
        XCTAssertFalse(model.noteIsSet(4, at: editable))
    }

    func testCheckFindsOnlyIncorrectPlayerValuesAndIgnoresNotesAndGivens() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .medium)
        let editable = model.givens.firstIndex(of: false)!
        let correctValue = model.solution[editable]
        let wrongValue = correctValue == 9 ? 8 : correctValue + 1

        model.select(editable)
        model.notesMode = true
        model.input(wrongValue)
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)

        model.notesMode = false
        model.input(wrongValue)
        XCTAssertEqual(model.incorrectPlayerEntryIndexes(), [editable])

        model.input(correctValue)
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)
        XCTAssertTrue(model.givens.indices.filter { model.givens[$0] }.allSatisfy {
            !model.incorrectPlayerEntryIndexes().contains($0)
        })
    }

    func testCompletedNumberRequiresNineCorrectValues() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .hard)
        let number = 7
        for index in 0..<81 where model.solution[index] == number && !model.givens[index] {
            model.select(index)
            model.input(number)
        }
        XCTAssertTrue(model.isNumberComplete(number))

        let incorrectCell = (0..<81).first {
            !model.givens[$0] && model.values[$0] == 0 && model.solution[$0] != number
        }!
        model.select(incorrectCell)
        model.input(number)
        XCTAssertFalse(model.isNumberComplete(number), "An erroneous tenth value must invalidate completion")
    }

    func testConflictAndCompletion() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .hard)

        var conflictCell: Int?
        var duplicateValue: Int?
        for row in 0..<9 where conflictCell == nil {
            let rowRange = row * 9..<(row + 1) * 9
            if let editable = rowRange.first(where: { !model.givens[$0] }),
               let given = rowRange.first(where: { model.givens[$0] }) {
                conflictCell = editable
                duplicateValue = model.values[given]
            }
        }
        XCTAssertNotNil(conflictCell)
        model.select(conflictCell!)
        model.input(duplicateValue!)
        XCTAssertTrue(model.isConflict(at: conflictCell!))
        model.undo()
        XCTAssertFalse(model.isConflict(at: conflictCell!))

        for index in 0..<81 where !model.givens[index] {
            model.select(index)
            model.input(model.solution[index])
        }
        XCTAssertTrue(model.completed)
        XCTAssertTrue(model.presentsCompletion)
    }

    func testSelectionNavigationAndAutosaveRestore() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .easy)
        model.select(40)
        model.moveSelection(dx: 1, dy: -1)
        XCTAssertEqual(model.selectedIndex, 32)

        let editable = model.givens.firstIndex(of: false)!
        model.select(editable)
        model.input(model.solution[editable])

        let restored = SudokuGameModel()
        XCTAssertEqual(restored.difficulty, .easy)
        XCTAssertEqual(restored.selectedIndex, editable)
        XCTAssertEqual(restored.values[editable], model.solution[editable])
    }

    func testRealWindowKeyboardNavigationDeleteBackspaceAndNotes() {
        let model = SudokuGameModel()
        model.startNewGame(difficulty: .medium)
        let window = makeWindow(model: model)
        defer { window.close() }

        model.select(40)
        postKey(code: 123, to: window) // Left
        XCTAssertEqual(model.selectedIndex, 39)
        postKey(code: 124, to: window) // Right
        XCTAssertEqual(model.selectedIndex, 40)
        postKey(code: 126, to: window) // Up
        XCTAssertEqual(model.selectedIndex, 31)
        postKey(code: 125, to: window) // Down
        XCTAssertEqual(model.selectedIndex, 40)

        model.select(0)
        postKey(code: 123, to: window)
        postKey(code: 126, to: window)
        XCTAssertEqual(model.selectedIndex, 0, "Arrow keys must not leave the board")

        let editable = model.givens.firstIndex(of: false)!
        model.select(editable)
        postKey(code: 18, characters: String(model.solution[editable]), to: window)
        XCTAssertEqual(model.values[editable], model.solution[editable])
        postKey(code: 51, characters: "\u{8}", to: window) // Backspace
        XCTAssertEqual(model.values[editable], 0)

        postKey(code: 18, characters: String(model.solution[editable]), to: window)
        postKey(code: 117, characters: "\u{7f}", to: window) // Forward Delete
        XCTAssertEqual(model.values[editable], 0)

        let clue = model.givens.firstIndex(of: true)!
        let clueValue = model.values[clue]
        model.select(clue)
        postKey(code: 51, characters: "\u{8}", to: window)
        XCTAssertEqual(model.values[clue], clueValue, "Initial clues must never be erased")

        model.select(editable)
        postKey(code: 45, characters: "n", to: window)
        XCTAssertTrue(model.notesMode)
        postKey(code: 21, characters: "4", to: window)
        XCTAssertTrue(model.noteIsSet(4, at: editable))
        postKey(code: 51, characters: "\u{8}", to: window)
        XCTAssertFalse(model.noteIsSet(4, at: editable))
    }

    private func makeWindow(model: SudokuGameModel) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 844, height: 690),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: ContentView(model: model))
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        return window
    }

    private func postKey(code: UInt16, characters: String = "", to window: NSWindow) {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: code
        )!
        NSApplication.shared.sendEvent(event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
