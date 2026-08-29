import SwiftUI

struct NurikabeBoardView: View {
    @ObservedObject var model: NurikabeGameModel
    @Environment(\.checkMistakeIndexes) private var checkMistakeIndexes

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: model.size)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<model.cellCount, id: \.self) { index in
                cell(at: index).aspectRatio(1, contentMode: .fit)
            }
        }
        .background(PuzzleTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(PuzzleTheme.block, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nurikabe board")
    }

    private func cell(at index: Int) -> some View {
        Button { model.mark(index) } label: {
            ZStack {
                cellBackground(at: index)
                Rectangle().stroke(PuzzleTheme.grid.opacity(0.75), lineWidth: 0.65)

                if model.clues[index] > 0 {
                    Text(String(model.clues[index]))
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(PuzzleTheme.ink)
                } else if model.values[index] == 2 {
                    Circle()
                        .stroke(PuzzleTheme.accent.opacity(0.55), lineWidth: 1.8)
                        .frame(width: 10, height: 10)
                }

                if index == model.selectedIndex {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(selectionColor(at: index), lineWidth: 2.2)
                        .padding(2)
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
        switch model.values[index] {
        case 1: return PuzzleTheme.accent.opacity(0.86)
        case 2: return PuzzleTheme.surface
        default: return PuzzleTheme.paper
        }
    }

    private func selectionColor(at index: Int) -> Color {
        model.values[index] == 1 ? Color.white.opacity(0.85) : PuzzleTheme.accent
    }

    private func accessibilityLabel(at index: Int) -> String {
        let state: String
        if model.clues[index] > 0 {
            state = "island clue \(model.clues[index])"
        } else {
            state = switch model.values[index] {
            case 1: "sea"
            case 2: "island"
            default: "unknown"
            }
        }
        return "Row \(index / model.size + 1), column \(index % model.size + 1), \(state)"
    }
}
