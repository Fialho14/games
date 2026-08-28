import AppKit
import SwiftUI

private struct CheckMistakeIndexesKey: EnvironmentKey {
    static let defaultValue: Set<Int> = []
}

extension EnvironmentValues {
    var checkMistakeIndexes: Set<Int> {
        get { self[CheckMistakeIndexesKey.self] }
        set { self[CheckMistakeIndexesKey.self] = newValue }
    }
}

struct CheckButton: View {
    let isSuccessful: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isSuccessful ? PuzzleTheme.checkSuccess : Color.secondary)
                .frame(width: 34, height: 34)
                .background(
                    isHovering ? Color.black.opacity(0.045) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay { PointingHandCursor().allowsHitTesting(false) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Check for mistakes")
        .accessibilityLabel("Check for mistakes")
        .animation(.easeInOut(duration: 0.18), value: isSuccessful)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

private struct PointingHandCursor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        CursorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}
