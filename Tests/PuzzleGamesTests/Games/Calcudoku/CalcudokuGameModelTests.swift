import AppKit
import SwiftUI
import XCTest
@testable import PuzzleGames

@MainActor
final class CalcudokuGameModelTests: XCTestCase {
    nonisolated private static let suiteName = "CalcudokuGameModelTests"
    private var testDefaults: UserDefaults { UserDefaults(suiteName: Self.suiteName)! }

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        defaults.removePersistentDomain(forName: Self.suiteName)
        UserDefaults.standard.removeObject(forKey: "sudoku.mac.saved-game.v1")
        UserDefaults.standard.removeObject(forKey: "puzzle-games.selected-game.v1")
    }

    func testDifficultyNewGameInputEraseUndoRestartAndCompletion() {
        let model = CalcudokuGameModel(defaults: testDefaults, seed: 100)
        for (difficulty, expectedSize) in [
            (GameDifficulty.easy, 4), (.medium, 5), (.hard, 6)
        ] {
            model.startNewGame(difficulty: difficulty)
            XCTAssertEqual(model.size, expectedSize)
            XCTAssertEqual(model.validNumbers, Array(1...expectedSize))
            XCTAssertEqual(model.values, Array(repeating: 0, count: expectedSize * expectedSize))
        }

        let firstSolution = model.solution
        let firstCages = model.cageIDs
        model.startNewGame()
        XCTAssertTrue(model.solution != firstSolution || model.cageIDs != firstCages)

        model.select(0)
        let answer = model.solution[0]
        model.input(answer)
        XCTAssertEqual(model.values[0], answer)
        model.erase()
        XCTAssertEqual(model.values[0], 0)
        model.undo()
        XCTAssertEqual(model.values[0], answer)
        let restartedSolution = model.solution
        let restartedCages = model.cageIDs
        model.restart()
        XCTAssertTrue(model.values.allSatisfy { $0 == 0 })
        XCTAssertEqual(model.solution, restartedSolution)
        XCTAssertEqual(model.cageIDs, restartedCages)

        for index in model.values.indices {
            model.select(index)
            model.input(model.solution[index])
        }
        XCTAssertTrue(model.completed)
        XCTAssertTrue(model.presentsCompletion)
    }

    func testNotesUndoNavigationConflictsAndCompletedNumber() {
        let model = CalcudokuGameModel(defaults: testDefaults, seed: 200)
        model.startNewGame(difficulty: .medium)
        model.select(0)
        model.notesMode = true
        model.input(3)
        XCTAssertTrue(model.noteIsSet(3, at: 0))
        model.undo()
        XCTAssertFalse(model.noteIsSet(3, at: 0))

        model.select(12)
        model.moveSelection(dx: 1, dy: -1)
        XCTAssertEqual(model.selectedIndex, 8)
        model.select(0)
        model.moveSelection(dx: -1, dy: -1)
        XCTAssertEqual(model.selectedIndex, 0)

        model.notesMode = false
        model.select(0)
        model.input(1)
        model.select(1)
        model.input(1)
        XCTAssertTrue(model.isLineConflict(at: 0))
        XCTAssertTrue(model.isLineConflict(at: 1))
        model.undo()
        XCTAssertFalse(model.isLineConflict(at: 0))

        model.restart()
        let cageID = model.cageIDs[0]
        let cageMembers = model.cageIDs.indices.filter { model.cageIDs[$0] == cageID }
        var foundArithmeticConflict = false
        for candidate in 1...model.size where !foundArithmeticConflict {
            model.restart()
            for member in cageMembers {
                model.select(member)
                model.input(candidate)
            }
            foundArithmeticConflict = model.isCageConflict(at: cageMembers[0])
        }
        XCTAssertTrue(foundArithmeticConflict)

        model.restart()
        let number = 2
        for index in model.solution.indices where model.solution[index] == number {
            model.select(index)
            model.input(number)
        }
        XCTAssertTrue(model.isNumberComplete(number))
    }

    func testCheckFindsIncorrectValuesAndIgnoresNotesAndEmptyCells() {
        let model = CalcudokuGameModel(defaults: testDefaults, seed: 250)
        model.startNewGame(difficulty: .medium)
        let correctValue = model.solution[0]
        let wrongValue = correctValue == model.size ? correctValue - 1 : correctValue + 1

        model.select(0)
        model.notesMode = true
        model.input(wrongValue)
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)

        model.notesMode = false
        model.input(wrongValue)
        XCTAssertEqual(model.incorrectPlayerEntryIndexes(), [0])

        model.input(correctValue)
        XCTAssertTrue(model.incorrectPlayerEntryIndexes().isEmpty)
    }

    func testAutosaveRestoreAndIndependentGameStates() {
        let calcudoku = CalcudokuGameModel(defaults: testDefaults, seed: 300)
        calcudoku.startNewGame(difficulty: .hard)
        calcudoku.select(5)
        calcudoku.input(calcudoku.solution[5])
        let savedCages = calcudoku.cageIDs

        let restored = CalcudokuGameModel(defaults: testDefaults, seed: 301)
        XCTAssertEqual(restored.difficulty, .hard)
        XCTAssertEqual(restored.size, 6)
        XCTAssertEqual(restored.selectedIndex, 5)
        XCTAssertEqual(restored.values[5], calcudoku.solution[5])
        XCTAssertEqual(restored.cageIDs, savedCages)

        let sudoku = SudokuGameModel()
        sudoku.startNewGame(difficulty: .easy)
        let sudokuCell = sudoku.givens.firstIndex(of: false)!
        sudoku.select(sudokuCell)
        sudoku.input(sudoku.solution[sudokuCell])
        let sudokuValues = sudoku.values
        let calcudokuValues = calcudoku.values
        let app = AppModel(sudokuModel: sudoku, calcudokuModel: calcudoku,
                           defaults: testDefaults, selectedGame: .sudoku)
        app.selectedGame = .calcudoku
        let restoredSelection = AppModel(sudokuModel: sudoku, calcudokuModel: calcudoku,
                                         defaults: testDefaults)
        XCTAssertEqual(restoredSelection.selectedGame, .calcudoku)
        app.selectedGame = .sudoku
        XCTAssertEqual(sudoku.values, sudokuValues)
        XCTAssertEqual(calcudoku.values, calcudokuValues)
        XCTAssertEqual(sudoku.difficulty, .easy)
        XCTAssertEqual(calcudoku.difficulty, .hard)
    }

    func testRealWindowKeyboardNumbersDeleteBackspaceNotesAndArrows() {
        let model = CalcudokuGameModel(defaults: testDefaults, seed: 400)
        model.startNewGame(difficulty: .easy)
        let appModel = AppModel(calcudokuModel: model, defaults: testDefaults,
                                selectedGame: .calcudoku)
        let window = makeWindow(appModel: appModel)
        defer { window.close() }

        model.select(5)
        postKey(code: 123, to: window)
        XCTAssertEqual(model.selectedIndex, 4)
        postKey(code: 126, to: window)
        XCTAssertEqual(model.selectedIndex, 0)
        postKey(code: 124, to: window)
        XCTAssertEqual(model.selectedIndex, 1)
        postKey(code: 125, to: window)
        XCTAssertEqual(model.selectedIndex, 5)

        let answer = model.solution[5]
        postKey(code: 18, characters: String(answer), to: window)
        XCTAssertEqual(model.values[5], answer)
        postKey(code: 51, characters: "\u{8}", to: window)
        XCTAssertEqual(model.values[5], 0)
        postKey(code: 18, characters: String(answer), to: window)
        postKey(code: 117, characters: "\u{7f}", to: window)
        XCTAssertEqual(model.values[5], 0)

        postKey(code: 45, characters: "n", to: window)
        XCTAssertTrue(model.notesMode)
        postKey(code: 20, characters: "3", to: window)
        XCTAssertTrue(model.noteIsSet(3, at: 5))
        postKey(code: 51, characters: "\u{8}", to: window)
        XCTAssertFalse(model.noteIsSet(3, at: 5))
    }

    private func makeWindow(appModel: AppModel) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 844, height: 690),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.contentView = NSHostingView(rootView: ContentView(appModel: appModel))
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        return window
    }

    private func postKey(code: UInt16, characters: String = "", to window: NSWindow) {
        let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: code
        )!
        NSApplication.shared.sendEvent(event)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
