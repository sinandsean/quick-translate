import Foundation
import SwiftUI

@Observable
final class AppState {
    var isTranslating = false
    var currentResult: TranslationResult?
    var errorMessage: String?
    var showPanel = false
    var selectedModel: String = Constants.defaultModel
    var hasAPIKey: Bool = false

    func reset() {
        isTranslating = false
        currentResult = nil
        errorMessage = nil
    }

    func startTranslating() {
        isTranslating = true
        errorMessage = nil
        currentResult = nil
        showPanel = true
    }

    func finishTranslating(result: TranslationResult) {
        isTranslating = false
        currentResult = result
    }

    func failTranslating(error: String) {
        isTranslating = false
        errorMessage = error
    }
}
