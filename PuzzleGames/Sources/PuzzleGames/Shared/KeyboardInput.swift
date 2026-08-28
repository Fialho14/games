import AppKit
import SwiftUI

enum GameKeyAction: Equatable {
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case erase
    case number(Int)
    case toggleNotes
}

enum KeyboardEventMapper {
    static func action(for event: NSEvent) -> GameKeyAction? {
        let unsupportedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(unsupportedModifiers).isEmpty else {
            return nil
        }

        switch event.keyCode {
        case 123: return .moveLeft
        case 124: return .moveRight
        case 125: return .moveDown
        case 126: return .moveUp
        case 51, 117: return .erase // Backspace and Forward Delete
        default:
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if let number = Int(characters), (1...9).contains(number) {
                return .number(number)
            }
            return characters == "n" ? .toggleNotes : nil
        }
    }
}

struct AppKeyboardMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onAction: (GameKeyAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onAction: onAction)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.hostView = view
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onAction = onAction
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        var isEnabled: Bool
        var onAction: (GameKeyAction) -> Void
        weak var hostView: NSView?
        private var eventMonitor: Any?
        private var isMenuTracking = false

        init(isEnabled: Bool, onAction: @escaping (GameKeyAction) -> Void) {
            self.isEnabled = isEnabled
            self.onAction = onAction
            super.init()
        }

        func start() {
            guard eventMonitor == nil else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(menuDidBeginTracking(_:)),
                name: NSMenu.didBeginTrackingNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(menuDidEndTracking(_:)),
                name: NSMenu.didEndTrackingNotification,
                object: nil
            )
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled, !self.isMenuTracking,
                      let windowNumber = self.hostView?.window?.windowNumber,
                      event.windowNumber == windowNumber else {
                    return event
                }
                guard let action = KeyboardEventMapper.action(for: event) else {
                    return event
                }
                self.onAction(action)
                return nil
            }
        }

        func stop() {
            NotificationCenter.default.removeObserver(self)
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
            isMenuTracking = false
            hostView = nil
        }

        @objc private func menuDidBeginTracking(_ notification: Notification) {
            isMenuTracking = true
        }

        @objc private func menuDidEndTracking(_ notification: Notification) {
            isMenuTracking = false
        }
    }
}
