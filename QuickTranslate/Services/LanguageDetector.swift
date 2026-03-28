import Foundation
import NaturalLanguage

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case korean = "Korean"
    case english = "English"
    case japanese = "Japanese"
    case chineseSimplified = "Chinese (Simplified)"
    case chineseTraditional = "Chinese (Traditional)"
    case spanish = "Spanish"
    case french = "French"
    case german = "German"
    case portuguese = "Portuguese"
    case russian = "Russian"
    case vietnamese = "Vietnamese"
    case thai = "Thai"
    case indonesian = "Indonesian"
    case italian = "Italian"
    case dutch = "Dutch"
    case arabic = "Arabic"
    case hindi = "Hindi"
    case turkish = "Turkish"

    var id: String { rawValue }

    var nlLanguage: NLLanguage {
        switch self {
        case .korean: return .korean
        case .english: return .english
        case .japanese: return .japanese
        case .chineseSimplified: return .simplifiedChinese
        case .chineseTraditional: return .traditionalChinese
        case .spanish: return .spanish
        case .french: return .french
        case .german: return .german
        case .portuguese: return .portuguese
        case .russian: return .russian
        case .vietnamese: return .vietnamese
        case .thai: return .thai
        case .indonesian: return .indonesian
        case .italian: return .italian
        case .dutch: return .dutch
        case .arabic: return .arabic
        case .hindi: return .hindi
        case .turkish: return .turkish
        }
    }

    static func from(nlLanguage: NLLanguage) -> SupportedLanguage? {
        allCases.first { $0.nlLanguage == nlLanguage }
    }
}

struct LanguagePair {
    let languageA: SupportedLanguage
    let languageB: SupportedLanguage

    static func load() -> LanguagePair {
        let defaults = UserDefaults.standard
        let a = defaults.string(forKey: "languageA").flatMap { SupportedLanguage(rawValue: $0) } ?? .korean
        let b = defaults.string(forKey: "languageB").flatMap { SupportedLanguage(rawValue: $0) } ?? .english
        return LanguagePair(languageA: a, languageB: b)
    }

    func save() {
        UserDefaults.standard.set(languageA.rawValue, forKey: "languageA")
        UserDefaults.standard.set(languageB.rawValue, forKey: "languageB")
    }
}

enum LanguageDetectionError: LocalizedError {
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let lang):
            return "Unsupported language detected: \(lang). Configure your language pair in Settings."
        }
    }
}

enum LanguageDetector {
    struct DetectionResult {
        let sourceLanguage: String
        let targetLanguage: String
        let sourceDisplayName: String
        let targetDisplayName: String
    }

    static func detect(text: String) throws -> DetectionResult {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominant = recognizer.dominantLanguage else {
            throw LanguageDetectionError.unsupportedLanguage("Unknown")
        }

        let pair = LanguagePair.load()

        if dominant == pair.languageA.nlLanguage {
            return DetectionResult(
                sourceLanguage: pair.languageA.rawValue,
                targetLanguage: pair.languageB.rawValue,
                sourceDisplayName: pair.languageA.rawValue,
                targetDisplayName: pair.languageB.rawValue
            )
        } else if dominant == pair.languageB.nlLanguage {
            return DetectionResult(
                sourceLanguage: pair.languageB.rawValue,
                targetLanguage: pair.languageA.rawValue,
                sourceDisplayName: pair.languageB.rawValue,
                targetDisplayName: pair.languageA.rawValue
            )
        } else {
            let langName = SupportedLanguage.from(nlLanguage: dominant)?.rawValue
                ?? Locale.current.localizedString(forIdentifier: dominant.rawValue)
                ?? dominant.rawValue
            throw LanguageDetectionError.unsupportedLanguage(langName)
        }
    }
}
