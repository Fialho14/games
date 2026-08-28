import SwiftUI

struct CalcudokuBoardView: View {
    @ObservedObject var model: CalcudokuGameModel
    @Environment(\.checkMistakeIndexes) private var checkMistakeIndexes

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: model.size)
    }

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<model.cellCount, id: \.self) { index in
                    cell(at: index).aspectRatio(1, contentMode: .fit)
                }
            }
            cageLines.allowsHitTesting(false)
        }
        .background(PuzzleTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(PuzzleTheme.block, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calcudoku board")
    }

    private func cell(at index: Int) -> some View {
        Button { model.select(index) } label: {
            ZStack(alignment: .topLeading) {
                cellBackground(at: index)
                Rectangle().stroke(PuzzleTheme.grid.opacity(0.7), lineWidth: 0.5)

                if let clue = model.clue(at: index) {
                    Text(clue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PuzzleTheme.ink.opacity(0.84))
                        .padding(.leading, 5)
                        .padding(.top, 4)
                }

                if model.values[index] != 0 {
                    Text(String(model.values[index]))
                        .font(.system(size: 25, weight: .medium, design: .rounded))
                        .foregroundStyle(numberColor(at: index))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.notes[index] != 0 {
                    notes(at: index)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        return model.isConflict(at: index) ? PuzzleTheme.conflictInk : PuzzleTheme.accent
    }

    private func notes(at index: Int) -> some View {
        let noteColumnCount = model.size <= 4 ? 2 : 3
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0),
                           count: noteColumnCount),
            spacing: 0
        ) {
            ForEach(model.validNumbers, id: \.self) { number in
                Text(model.noteIsSet(number, at: index) ? String(number) : " ")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(PuzzleTheme.accent.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(model.size <= 4 ? 10 : 7)
    }

    private var cageLines: some View {
        GeometryReader { geometry in
            Path { path in
                let cellSide = geometry.size.width / CGFloat(model.size)
                for index in 0..<model.cellCount {
                    let row = index / model.size
                    let column = index % model.size
                    let minX = CGFloat(column) * cellSide
                    let minY = CGFloat(row) * cellSide
                    let maxX = minX + cellSide
                    let maxY = minY + cellSide

                    if row == 0 || !model.isSameCage(index, index - model.size) {
                        path.move(to: CGPoint(x: minX, y: minY))
                        path.addLine(to: CGPoint(x: maxX, y: minY))
                    }
                    if column == 0 || !model.isSameCage(index, index - 1) {
                        path.move(to: CGPoint(x: minX, y: minY))
                        path.addLine(to: CGPoint(x: minX, y: maxY))
                    }
                    if row == model.size - 1 {
                        path.move(to: CGPoint(x: minX, y: maxY))
                        path.addLine(to: CGPoint(x: maxX, y: maxY))
                    }
                    if column == model.size - 1 {
                        path.move(to: CGPoint(x: maxX, y: minY))
                        path.addLine(to: CGPoint(x: maxX, y: maxY))
                    }
                }
            }
            .stroke(
                PuzzleTheme.block,
                style: StrokeStyle(lineWidth: 1.6, lineCap: .square, lineJoin: .round)
            )
        }
    }

    private func accessibilityLabel(at index: Int) -> String {
        let value = model.values[index] == 0 ? "empty" : String(model.values[index])
        let clue = model.clue(at: index).map { ", clue \($0)" } ?? ""
        return "Row \(index / model.size + 1), column \(index % model.size + 1), " +
            "\(value)\(clue)"
    }
}
