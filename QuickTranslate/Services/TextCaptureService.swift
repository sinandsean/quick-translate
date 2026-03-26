import Foundation
import AppKit
import ApplicationServices

enum TextCaptureError: LocalizedError {
    case accessibilityNotGranted
    case noTextSelected
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission required. Go to System Settings > Privacy & Security > Accessibility and enable QuickTranslate."
        case .noTextSelected:
            return "No text selected. Select text to translate and try again."
        case .captureFailed:
            return "Failed to capture text."
        }
    }
}

enum TextCaptureService {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func captureSelectedText() -> Result<String, TextCaptureError> {
        guard isAccessibilityGranted else {
            return .failure(.accessibilityNotGranted)
        }

        if let text = getSelectedTextViaAccessibility(), !text.isEmpty {
            return .success(text)
        }

        if let text = getSelectedTextViaPasteboard(), !text.isEmpty {
            return .success(text)
        }

        return .failure(.noTextSelected)
    }

    private static func getSelectedTextViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success else { return nil }

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success, let text = selectedText as? String else {
            return nil
        }

        return text
    }

    private static func getSelectedTextViaPasteboard() -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        cmdCDown?.flags = .maskCommand
        cmdCUp?.flags = .maskCommand

        cmdCDown?.post(tap: .cghidEventTap)
        cmdCUp?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.1)

        guard pasteboard.changeCount != previousChangeCount else {
            return nil
        }

        let copiedText = pasteboard.string(forType: .string)

        if let prev = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(prev, forType: .string)
        }

        return copiedText
    }
}
