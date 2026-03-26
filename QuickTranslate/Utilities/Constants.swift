import Foundation
import AppKit

enum APIProvider: String, CaseIterable, Identifiable {
    case claude = "Claude API"
    case openRouter = "OpenRouter"

    var id: String { rawValue }

    var apiURL: String {
        switch self {
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .openRouter: return "https://openrouter.ai/api/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-5"
        case .openRouter: return "anthropic/claude-3.5-sonnet"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claude:
            return ["claude-sonnet-4-5", "claude-haiku-4-5"]
        case .openRouter:
            return [
                "anthropic/claude-3.5-sonnet",
                "anthropic/claude-3.5-haiku",
                "openai/gpt-4o",
                "openai/gpt-4o-mini",
                "google/gemini-2.0-flash-001",
                "meta-llama/llama-4-maverick"
            ]
        }
    }

    var keychainAccount: String {
        switch self {
        case .claude: return "claude-api-key"
        case .openRouter: return "openrouter-api-key"
        }
    }

    static func current() -> APIProvider {
        let raw = UserDefaults.standard.string(forKey: "apiProvider") ?? "Claude API"
        return APIProvider(rawValue: raw) ?? .claude
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "apiProvider")
    }
}

enum Constants {
    static let anthropicVersion = "2023-06-01"
    static let maxTextLength = 5000
    static let requestTimeout: TimeInterval = 30
    static let keychainService = "com.quicktranslate.app"

    static var defaultModel: String {
        APIProvider.current().defaultModel
    }

    enum Hotkey {
        static var displayString: String {
            HotkeyConfig.load().displayString
        }
    }

    enum Panel {
        static let width: CGFloat = 320
        static let minHeight: CGFloat = 200
        static let maxHeight: CGFloat = 500
        static let animationDuration: CGFloat = 0.25
        static let topPadding: CGFloat = 28
    }
}
