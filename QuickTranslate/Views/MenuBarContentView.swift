import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    let onCheckAccessibility: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button("Settings...") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Check Accessibility") {
                onCheckAccessibility()
            }

            Divider()

            Button("Quit QuickTranslate") {
                onQuit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
