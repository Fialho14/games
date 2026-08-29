import SwiftUI

struct SlitherlinkBoardView: View {
    @ObservedObject var model: SlitherlinkGameModel
    @Environment(\.checkMistakeIndexes) private var checkMistakeIndexes

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 22
            let side = geometry.size.width - inset * 2
            let cellSide = side / CGFloat(model.size)

            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(PuzzleTheme.paper)
                grid(inset: inset, cellSide: cellSide)
                clues(inset: inset, cellSide: cellSide)
                edges(inset: inset, cellSide: cellSide)
                vertices(inset: inset, cellSide: cellSide)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(PuzzleTheme.block.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slitherlink board")
    }

    private func grid(inset: CGFloat, cellSide: CGFloat) -> some View {
        Path { path in
            for position in 0...model.size {
                let offset = inset + CGFloat(position) * cellSide
                path.move(to: CGPoint(x: inset, y: offset))
                path.addLine(to: CGPoint(x: inset + cellSide * CGFloat(model.size), y: offset))
                path.move(to: CGPoint(x: offset, y: inset))
                path.addLine(to: CGPoint(x: offset, y: inset + cellSide * CGFloat(model.size)))
            }
        }
        .stroke(PuzzleTheme.grid.opacity(0.55), lineWidth: 1)
    }

    private func clues(inset: CGFloat, cellSide: CGFloat) -> some View {
        ForEach(model.clues.indices, id: \.self) { cell in
            if model.clues[cell] >= 0 {
                Text(String(model.clues[cell]))
                    .font(.system(size: min(27, cellSide * 0.34), weight: .medium,
                                  design: .rounded))
                    .foregroundStyle(PuzzleTheme.ink.opacity(0.86))
                    .position(x: inset + (CGFloat(cell % model.size) + 0.5) * cellSide,
                              y: inset + (CGFloat(cell / model.size) + 0.5) * cellSide)
            }
        }
    }

    private func edges(inset: CGFloat, cellSide: CGFloat) -> some View {
        ForEach(model.values.indices, id: \.self) { edge in
            let placement = edgePlacement(edge, inset: inset, cellSide: cellSide)
            Button { model.mark(edge) } label: {
                ZStack {
                    if edge == model.selectedIndex {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(PuzzleTheme.accent.opacity(0.11))
                    }
                    edgeMark(edge, horizontal: placement.horizontal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: placement.width, height: placement.height)
            .position(x: placement.x, y: placement.y)
            .accessibilityLabel(edgeAccessibilityLabel(edge))
        }
    }

    @ViewBuilder
    private func edgeMark(_ edge: Int, horizontal: Bool) -> some View {
        let isMistake = checkMistakeIndexes.contains(edge)
        let color = isMistake || model.isConflict(at: edge)
            ? PuzzleTheme.conflictInk : PuzzleTheme.accent
        switch model.values[edge] {
        case 1:
            Capsule()
                .fill(color)
                .frame(width: horizontal ? nil : 4, height: horizontal ? 4 : nil)
                .padding(horizontal ? .horizontal : .vertical, 5)
        case 2:
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isMistake ? PuzzleTheme.checkMistakeInk : Color.secondary)
        default:
            Color.clear
        }
    }

    private func vertices(inset: CGFloat, cellSide: CGFloat) -> some View {
        ForEach(0..<((model.size + 1) * (model.size + 1)), id: \.self) { vertex in
            Circle()
                .fill(PuzzleTheme.block)
                .frame(width: 4.5, height: 4.5)
                .position(x: inset + CGFloat(vertex % (model.size + 1)) * cellSide,
                          y: inset + CGFloat(vertex / (model.size + 1)) * cellSide)
        }
    }

    private func edgePlacement(_ edge: Int, inset: CGFloat, cellSide: CGFloat)
        -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, horizontal: Bool) {
        let horizontalCount = model.size * (model.size + 1)
        if edge < horizontalCount {
            let row = edge / model.size
            let column = edge % model.size
            return (inset + (CGFloat(column) + 0.5) * cellSide,
                    inset + CGFloat(row) * cellSide,
                    cellSide * 0.88, 22, true)
        }
        let compact = edge - horizontalCount
        let row = compact / (model.size + 1)
        let column = compact % (model.size + 1)
        return (inset + CGFloat(column) * cellSide,
                inset + (CGFloat(row) + 0.5) * cellSide,
                22, cellSide * 0.88, false)
    }

    private func edgeAccessibilityLabel(_ edge: Int) -> String {
        let horizontalCount = model.size * (model.size + 1)
        let state = switch model.values[edge] {
        case 1: "line"
        case 2: "excluded"
        default: "unknown"
        }
        if edge < horizontalCount {
            return "Horizontal edge, row \(edge / model.size + 1), column \(edge % model.size + 1), \(state)"
        }
        let compact = edge - horizontalCount
        return "Vertical edge, row \(compact / (model.size + 1) + 1), column \(compact % (model.size + 1) + 1), \(state)"
    }
}
