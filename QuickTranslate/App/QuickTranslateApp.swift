import SwiftUI
import AppKit

@main
struct QuickTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                onCheckAccessibility: {
                    if TextCaptureService.isAccessibilityGranted {
                        let alert = NSAlert()
                        alert.messageText = "접근성 권한"
                        alert.informativeText = "접근성 권한이 허용되어 있습니다."
                        alert.alertStyle = .informational
                        alert.runModal()
                    } else {
                        TextCaptureService.requestAccessibility()
                    }
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        } label: {
            Image(systemName: "arrow.left.arrow.right")
        }

        Settings {
            SettingsView()
        }
    }
}

enum MenuBarIcon {
    static func create() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let lineWidth: CGFloat = 1.5

            // 한 (left side, small)
            let hanFont = NSFont.systemFont(ofSize: 7, weight: .bold)
            let hanStr = NSAttributedString(string: "한", attributes: [
                .font: hanFont,
                .foregroundColor: NSColor.black
            ])
            hanStr.draw(at: NSPoint(x: 0.5, y: 4.5))

            // A (right side, small)
            let aFont = NSFont.systemFont(ofSize: 7.5, weight: .bold)
            let aStr = NSAttributedString(string: "A", attributes: [
                .font: aFont,
                .foregroundColor: NSColor.black
            ])
            aStr.draw(at: NSPoint(x: 12.5, y: 4.5))

            // Top arrow: → (left to right)
            let topArrow = NSBezierPath()
            topArrow.lineWidth = lineWidth
            topArrow.lineCapStyle = .round
            topArrow.move(to: NSPoint(x: 5, y: 14.5))
            topArrow.line(to: NSPoint(x: 13, y: 14.5))
            // Arrowhead
            topArrow.move(to: NSPoint(x: 10.5, y: 17))
            topArrow.line(to: NSPoint(x: 13, y: 14.5))
            topArrow.line(to: NSPoint(x: 10.5, y: 12))
            topArrow.stroke()

            // Bottom arrow: ← (right to left)
            let bottomArrow = NSBezierPath()
            bottomArrow.lineWidth = lineWidth
            bottomArrow.lineCapStyle = .round
            bottomArrow.move(to: NSPoint(x: 13, y: 3.5))
            bottomArrow.line(to: NSPoint(x: 5, y: 3.5))
            // Arrowhead
            bottomArrow.move(to: NSPoint(x: 7.5, y: 6))
            bottomArrow.line(to: NSPoint(x: 5, y: 3.5))
            bottomArrow.line(to: NSPoint(x: 7.5, y: 1))
            bottomArrow.stroke()

            return true
        }

        image.isTemplate = true // dark/light mode 자동 대응
        return image
    }
}
