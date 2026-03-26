import Foundation
import NaturalLanguage

enum LanguageDetector {
    struct DetectionResult {
        let sourceLanguage: String
        let targetLanguage: String
        let sourceDisplayName: String
        let targetDisplayName: String
    }

    static func detect(text: String) -> DetectionResult {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let dominant = recognizer.dominantLanguage

        if dominant == .korean {
            return DetectionResult(
                sourceLanguage: "Korean",
                targetLanguage: "English",
                sourceDisplayName: "한국어",
                targetDisplayName: "영어"
            )
        } else {
            return DetectionResult(
                sourceLanguage: "English",
                targetLanguage: "Korean",
                sourceDisplayName: "English",
                targetDisplayName: "한국어"
            )
        }
    }
}
