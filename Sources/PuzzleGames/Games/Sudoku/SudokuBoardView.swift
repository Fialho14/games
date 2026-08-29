import SwiftUI

struct SudokuBoardView: View {
    @ObservedObject var model: SudokuGameModel
    @Environment(\.checkMistakeIndexes) private var checkMistakeIndexes
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<81, id: \.self) { index in
                    cell(at: index).aspectRatio(1, contentMode: .fit)
                }
            }
            blockLines.allowsHitTesting(false)
        }
        .background(PuzzleTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(PuzzleTheme.block, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku board")
    }

    private func cell(at index: Int) -> some View {
        Button { model.select(index) } label: {
            ZStack {
                cellBackground(at: index)
                Rectangle().stroke(PuzzleTheme.grid.opacity(0.7), lineWidth: 0.5)
                if model.values[index] != 0 {
                    Text(String(model.values[index]))
                        .font(.system(size: 25, weight: model.givens[index] ? .semibold : .medium,
                                      design: .rounded))
                        .foregroundStyle(numberColor(at: index))
                } else if model.notes[index] != 0 {
                    notes(at: index)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(at: index))
    }

    private func cellBackground(at index: Int) -> Color {
        if checkMistakeIndexes.contains(index) { return PuzzleTheme.checkMistake }
        if model.isConflict(at: index) { return PuzzleTheme.conflict }
        if index == model.selectedIndex { return PuzzleTheme.accent.opacity(0.18) }
        if model.selectedValue != 0 && model.values[index] == model.selectedValue {
            return PuzzleTheme.accent.opacity(0.105)
        }
        if model.isPeer(index) { return PuzzleTheme.peer }
        return PuzzleTheme.paper
    }

    private func numberColor(at index: Int) -> Color {
        if checkMistakeIndexes.contains(index) { return PuzzleTheme.checkMistakeInk }
        if model.isConflict(at: index) { return PuzzleTheme.conflictInk }
        return model.givens[index] ? PuzzleTheme.ink : PuzzleTheme.accent
    }

    private func notes(at index: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 0) {
            ForEach(1...9, id: \.self) { number in
                Text(model.noteIsSet(number, at: index) ? String(number) : " ")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(PuzzleTheme.accent.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(4)
    }

    private var blockLines: some View {
        GeometryReader { geometry in
            Path { path in
                let side = geometry.size.width
                for position in [side / 3, side * 2 / 3] {
                    path.move(to: CGPoint(x: position, y: 0))
                    path.addLine(to: CGPoint(x: position, y: side))
                    path.move(to: CGPoint(x: 0, y: position))
                    path.addLine(to: CGPoint(x: side, y: position))
                }
            }
            .stroke(PuzzleTheme.block, lineWidth: 1.5)
        }
    }

    private func accessibilityLabel(at index: Int) -> String {
        let value = model.values[index] == 0 ? "empty" : String(model.values[index])
        return "Row \(index / 9 + 1), column \(index % 9 + 1), \(value)"
    }
}
