import SwiftUI

struct SkyscrapersBoardView: View {
    @ObservedObject var model: SkyscrapersGameModel
    @Environment(\.checkMistakeIndexes) private var checkMistakeIndexes

    var body: some View {
        GeometryReader { geometry in
            let margin: CGFloat = 42
            let gridSide = geometry.size.width - margin * 2
            let cellSide = gridSide / CGFloat(model.size)

            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(PuzzleTheme.paper)
                outsideClues(margin: margin, gridSide: gridSide, cellSide: cellSide)
                cells(margin: margin, cellSide: cellSide)
                grid(margin: margin, gridSide: gridSide, cellSide: cellSide)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(PuzzleTheme.block.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Skyscrapers board")
    }

    private func cells(margin: CGFloat, cellSide: CGFloat) -> some View {
        ForEach(0..<model.cellCount, id: \.self) { index in
            Button { model.select(index) } label: {
                ZStack {
                    cellBackground(at: index)
                    if model.values[index] != 0 {
                        Text(String(model.values[index]))
                            .font(.system(size: min(28, cellSide * 0.42), weight: .medium,
                                          design: .rounded))
                            .foregroundStyle(numberColor(at: index))
                    } else if model.notes[index] != 0 {
                        notes(at: index)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: cellSide, height: cellSide)
            .position(x: margin + (CGFloat(index % model.size) + 0.5) * cellSide,
                      y: margin + (CGFloat(index / model.size) + 0.5) * cellSide)
            .accessibilityLabel(accessibilityLabel(at: index))
        }
    }

    private func outsideClues(margin: CGFloat, gridSide: CGFloat,
                              cellSide: CGFloat) -> some View {
        ForEach(0..<model.size, id: \.self) { index in
            clue(model.clues.top[index])
                .position(x: margin + (CGFloat(index) + 0.5) * cellSide, y: margin * 0.48)
            clue(model.clues.bottom[index])
                .position(x: margin + (CGFloat(index) + 0.5) * cellSide,
                          y: margin + gridSide + margin * 0.52)
            clue(model.clues.left[index])
                .position(x: margin * 0.48,
                          y: margin + (CGFloat(index) + 0.5) * cellSide)
            clue(model.clues.right[index])
                .position(x: margin + gridSide + margin * 0.52,
                          y: margin + (CGFloat(index) + 0.5) * cellSide)
        }
    }

    private func clue(_ value: Int) -> some View {
        Text(value == 0 ? "" : String(value))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(PuzzleTheme.ink.opacity(0.72))
            .frame(width: 25, height: 25)
    }

    private func grid(margin: CGFloat, gridSide: CGFloat, cellSide: CGFloat) -> some View {
        Path { path in
            let max = margin + gridSide
            for position in 0...model.size {
                let offset = margin + CGFloat(position) * cellSide
                path.move(to: CGPoint(x: margin, y: offset))
                path.addLine(to: CGPoint(x: max, y: offset))
                path.move(to: CGPoint(x: offset, y: margin))
                path.addLine(to: CGPoint(x: offset, y: max))
            }
        }
        .stroke(PuzzleTheme.grid, lineWidth: 0.8)
        .overlay {
            Path { path in
                path.addRect(CGRect(x: margin, y: margin, width: gridSide, height: gridSide))
            }
            .stroke(PuzzleTheme.block, lineWidth: 1.6)
        }
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
        let columnCount = model.size <= 4 ? 2 : 3
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columnCount),
            spacing: 0
        ) {
            ForEach(model.validNumbers, id: \.self) { number in
                Text(model.noteIsSet(number, at: index) ? String(number) : " ")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(PuzzleTheme.accent.opacity(0.82))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(model.size <= 4 ? 9 : 6)
    }

    private func accessibilityLabel(at index: Int) -> String {
        let value = model.values[index] == 0 ? "empty" : String(model.values[index])
        return "Row \(index / model.size + 1), column \(index % model.size + 1), \(value)"
    }
}
