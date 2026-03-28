import Foundation
import NaturalLanguage

enum LanguageDetectionError: LocalizedError {
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage(let lang):
            return "Unsupported language detected: \(lang). Only Korean and English are supported."
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

        switch dominant {
        case .korean:
            return DetectionResult(
                sourceLanguage: "Korean",
                targetLanguage: "English",
                sourceDisplayName: "Korean",
                targetDisplayName: "English"
            )
        case .english:
            return DetectionResult(
                sourceLanguage: "English",
                targetLanguage: "Korean",
                sourceDisplayName: "English",
                targetDisplayName: "Korean"
            )
        default:
            let langName = Locale.current.localizedString(forIdentifier: dominant.rawValue) ?? dominant.rawValue
            throw LanguageDetectionError.unsupportedLanguage(langName)
        }
    }
}
