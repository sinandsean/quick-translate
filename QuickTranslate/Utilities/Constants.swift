import Foundation
import AppKit

enum Constants {
    static let apiURL = "https://api.anthropic.com/v1/messages"
    static let defaultModel = "claude-sonnet-4-5"
    static let anthropicVersion = "2023-06-01"
    static let maxTextLength = 5000
    static let requestTimeout: TimeInterval = 30
    static let keychainService = "com.quicktranslate.app"
    static let keychainAccount = "claude-api-key"

    enum Hotkey {
        static let displayString = "⌃T"
    }

    enum Panel {
        static let width: CGFloat = 320
        static let minHeight: CGFloat = 200
        static let maxHeight: CGFloat = 500
        static let animationDuration: CGFloat = 0.25
        static let topPadding: CGFloat = 28
    }
}
