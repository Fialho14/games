import SwiftUI

struct PuzzleShellView<Session: PuzzleSession, Board: View>: View {
    let game: GameKind
    @ObservedObject private var session: Session
    @Binding private var selectedGame: GameKind
    private let board: Board

    @State private var confirmsRestart = false
    @State private var presentsGameMenu = false
    @State private var checkMistakeIndexes: Set<Int> = []
    @State private var checkIsSuccessful = false
    @State private var checkFeedbackTask: Task<Void, Never>?

    init(
        game: GameKind,
        session: Session,
        selectedGame: Binding<GameKind>,
        @ViewBuilder board: () -> Board
    ) {
        self.game = game
        _session = ObservedObject(wrappedValue: session)
        _selectedGame = selectedGame
        self.board = board()
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            HStack(alignment: .top, spacing: PuzzleTheme.Layout.boardControlsSpacing) {
                board.frame(
                    width: PuzzleTheme.Layout.boardSide,
                    height: PuzzleTheme.Layout.boardSide
                )
                .environment(\.checkMistakeIndexes, checkMistakeIndexes)
                controls.frame(width: PuzzleTheme.Layout.controlsWidth)
            }
            footer
        }
        .padding(.horizontal, PuzzleTheme.Layout.horizontalPadding)
        .padding(.vertical, PuzzleTheme.Layout.verticalPadding)
        .frame(
            width: PuzzleTheme.Layout.windowWidth,
            height: PuzzleTheme.Layout.windowHeight
        )
        .background(PuzzleTheme.appBackground)
        .foregroundStyle(PuzzleTheme.ink)
        .background {
            AppKeyboardMonitor(
                isEnabled: !confirmsRestart && !session.presentsCompletion &&
                    !presentsGameMenu,
                onAction: handleKeyboardAction
            )
            .frame(width: 0, height: 0)
        }
        .confirmationDialog(
            "Restart this puzzle?",
            isPresented: $confirmsRestart,
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) {
                resetCheckFeedback()
                session.restart()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your entries and notes will be cleared.")
        }
        .sheet(isPresented: $session.presentsCompletion) {
            completionView
        }
        .onDisappear { resetCheckFeedback() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            gameMenu
            Spacer()
            Label(session.difficulty.title, systemImage: game.difficultySystemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(session.formattedTime)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(PuzzleTheme.ink.opacity(0.82))
                .frame(width: 54, alignment: .trailing)
        }
    }

    private var gameMenu: some View {
        Button { presentsGameMenu.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(game.title)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(PuzzleTheme.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $presentsGameMenu, arrowEdge: .top) {
            VStack(spacing: 2) {
                ForEach(GameKind.allCases) { candidate in
                    Button {
                        resetCheckFeedback()
                        selectedGame = candidate
                        presentsGameMenu = false
                    } label: {
                        HStack(spacing: 10) {
                            Text(candidate.title)
                            Spacer()
                            if candidate == selectedGame {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PuzzleTheme.accent)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PuzzleTheme.ink)
                        .padding(.horizontal, 9)
                        .frame(width: 142, height: 30, alignment: .leading)
                        .background(
                            candidate == selectedGame
                                ? PuzzleTheme.accent.opacity(0.09) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .accessibilityLabel("Choose game")
        .accessibilityValue(game.title)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DIFFICULTY").controlLabelStyle()
            Picker("Difficulty", selection: $session.difficulty) {
                ForEach(GameDifficulty.allCases) { difficulty in
                    Text(difficulty.title).tag(difficulty)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Button {
                resetCheckFeedback()
                session.startNewGame()
            } label: {
                Label("New Game", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(accent: PuzzleTheme.accent))
            .keyboardShortcut("n", modifiers: .command)

            Divider().padding(.vertical, 2)
            HStack(spacing: 8) {
                Text("TOOLS").controlLabelStyle()
                Spacer()
                CheckButton(isSuccessful: checkIsSuccessful) {
                    checkProgress()
                }
            }
            .frame(height: 34)
            sessionTools
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text(helpTitle)
                    .font(.system(size: 13, weight: .semibold))
                Text(helpText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PuzzleTheme.surface,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .frame(height: PuzzleTheme.Layout.boardSide)
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(session.notesMode ? PuzzleTheme.accent : Color.secondary.opacity(0.35))
                .frame(width: 6, height: 6)
            Text(footerModeText)
            Spacer()
            Text("Progress saves automatically")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private var numberStrip: some View {
        HStack(spacing: 3) {
            ForEach(session.validNumbers, id: \.self) { number in
                let isComplete = session.isNumberComplete(number)
                Button { session.input(number) } label: {
                    Text(String(number))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(PuzzleTheme.ink.opacity(isComplete ? 0.24 : 0.76))
                .background(
                    isComplete ? Color.black.opacity(0.025) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .accessibilityLabel(isComplete ? "\(number), complete" : String(number))
            }
        }
    }

    @ViewBuilder
    private var sessionTools: some View {
        switch session.inputStyle {
        case .numbers:
            numberStrip
            HStack(spacing: 10) {
                ToolButton(
                    title: "Notes",
                    systemImage: "pencil",
                    isActive: session.notesMode
                ) { session.notesMode.toggle() }
                undoButton
            }
            HStack(spacing: 10) {
                eraseButton
                restartButton
            }

        case let .twoState(style):
            HStack(spacing: 10) {
                ToolButton(title: style.primary.title,
                           systemImage: style.primary.systemImage,
                           isActive: !session.notesMode) {
                    session.notesMode = false
                }
                ToolButton(title: style.secondary.title,
                           systemImage: style.secondary.systemImage,
                           isActive: session.notesMode) {
                    session.notesMode = true
                }
            }
            HStack(spacing: 10) {
                undoButton
                eraseButton
            }
            restartButton

        }
    }

    private var undoButton: some View {
        ToolButton(
            title: "Undo",
            systemImage: "arrow.uturn.backward",
            disabled: !session.canUndo
        ) { session.undo() }
        .keyboardShortcut("z", modifiers: .command)
    }

    private var eraseButton: some View {
        ToolButton(title: "Erase", systemImage: "eraser") { session.erase() }
    }

    private var restartButton: some View {
        ToolButton(title: "Restart", systemImage: "arrow.counterclockwise") {
            confirmsRestart = true
        }
    }

    private var helpTitle: String {
        switch session.inputStyle {
        case .numbers: session.notesMode ? "Pencil mode is on" : "Keyboard"
        case let .twoState(style):
            session.notesMode ? style.secondary.helpTitle : style.primary.helpTitle
        }
    }

    private var helpText: String {
        switch session.inputStyle {
        case .numbers:
            session.notesMode
                ? "Numbers add small notes. Press N to switch back."
                : "Use \(validNumbersDescription), arrow keys and Delete. Press N for notes."
        case let .twoState(style): style.helpText
        }
    }

    private var footerModeText: String {
        switch session.inputStyle {
        case .numbers: session.notesMode ? "Notes on" : "Notes off"
        case let .twoState(style):
            session.notesMode ? style.secondary.footerText : style.primary.footerText
        }
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(PuzzleTheme.accent)
            VStack(spacing: 7) {
                Text("Puzzle complete")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                Text("\(game.title) · \(session.difficulty.title) · \(session.formattedTime)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Button("Start a New Puzzle") {
                resetCheckFeedback()
                session.startNewGame()
            }
                .buttonStyle(PrimaryButtonStyle(accent: PuzzleTheme.accent))
                .frame(width: 190)
            Button("View completed board") { session.presentsCompletion = false }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(34)
        .frame(width: 330)
        .background(PuzzleTheme.completionBackground)
    }

    private var validNumbersDescription: String {
        guard let first = session.validNumbers.first,
              let last = session.validNumbers.last else {
            return "number keys"
        }
        return first == last ? String(first) : "\(first)–\(last)"
    }

    private func handleKeyboardAction(_ action: GameKeyAction) {
        switch action {
        case .moveLeft: session.moveSelection(dx: -1, dy: 0)
        case .moveRight: session.moveSelection(dx: 1, dy: 0)
        case .moveUp: session.moveSelection(dx: 0, dy: -1)
        case .moveDown: session.moveSelection(dx: 0, dy: 1)
        case .erase: session.erase()
        case let .number(number):
            guard session.validNumbers.contains(number) else { return }
            session.input(number)
        case .toggleNotes: session.notesMode.toggle()
        case .rotateSelection:
            withAnimation(.easeInOut(duration: 0.12)) {
                session.rotateSelection()
            }
        }
    }

    private func checkProgress() {
        resetCheckFeedback()
        let mistakes = session.incorrectPlayerEntryIndexes()

        withAnimation(.easeInOut(duration: 0.18)) {
            checkMistakeIndexes = mistakes
            checkIsSuccessful = mistakes.isEmpty
        }

        let delay: Duration = mistakes.isEmpty ? .milliseconds(2500) : .seconds(5)
        checkFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                checkMistakeIndexes = []
                checkIsSuccessful = false
            }
        }
    }

    private func resetCheckFeedback() {
        checkFeedbackTask?.cancel()
        checkFeedbackTask = nil
        checkMistakeIndexes = []
        checkIsSuccessful = false
    }
}
