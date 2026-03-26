import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    let onCheckAccessibility: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button("설정...") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("접근성 권한 확인") {
                onCheckAccessibility()
            }

            Divider()

            Button("QuickTranslate 종료") {
                onQuit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
