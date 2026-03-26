import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    private let apiService = ClaudeAPIService()
    private var floatingPanel: FloatingPanel?
    let appState = AppState()
    private var isProcessing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState.hasAPIKey = KeychainManager.load() != nil

        hotkeyManager.register { [weak self] in
            self?.handleHotkey()
        }

        if !TextCaptureService.isAccessibilityGranted {
            TextCaptureService.requestAccessibility()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyChanged(_:)),
            name: .hotkeyChanged,
            object: nil
        )

        NSLog("[QuickTranslate] App launched, hotkey registered, accessibility: \(TextCaptureService.isAccessibilityGranted)")
    }

    @objc private func hotkeyChanged(_ notification: Notification) {
        guard let config = notification.userInfo?["config"] as? HotkeyConfig else { return }
        hotkeyManager.updateHotkey(config: config)
        NSLog("[QuickTranslate] Hotkey changed to: \(config.displayString)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    private func handleHotkey() {
        NSLog("[QuickTranslate] Hotkey triggered!")
        guard !isProcessing else {
            NSLog("[QuickTranslate] Already processing, ignoring")
            return
        }

        guard KeychainManager.load() != nil else {
            DispatchQueue.main.async {
                self.appState.failTranslating(error: "API key not set. Go to menu bar → Settings to enter your API key.")
                self.showPanel()
            }
            return
        }

        let captureResult = TextCaptureService.captureSelectedText()

        switch captureResult {
        case .failure(let error):
            DispatchQueue.main.async {
                self.appState.failTranslating(error: error.errorDescription ?? "Unknown error")
                self.showPanel()
            }
        case .success(let text):
            let trimmed = String(text.prefix(Constants.maxTextLength))
            DispatchQueue.main.async {
                self.performTranslation(text: trimmed)
            }
        }
    }

    private func performTranslation(text: String) {
        isProcessing = true
        appState.startTranslating()
        showPanel()

        let detection = LanguageDetector.detect(text: text)
        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? Constants.defaultModel

        Task {
            do {
                let translated = try await apiService.translate(
                    text: text,
                    from: detection.sourceLanguage,
                    to: detection.targetLanguage,
                    model: model
                )

                let result = TranslationResult(
                    originalText: text,
                    translatedText: translated,
                    sourceLanguage: detection.sourceDisplayName,
                    targetLanguage: detection.targetDisplayName
                )

                await MainActor.run {
                    self.appState.finishTranslating(result: result)
                    self.floatingPanel?.updateContent(with: self.appState)
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.appState.failTranslating(error: error.localizedDescription)
                    self.floatingPanel?.updateContent(with: self.appState)
                    self.isProcessing = false
                }
            }
        }
    }

    private func showPanel() {
        if floatingPanel == nil {
            floatingPanel = FloatingPanel()
        }
        floatingPanel?.showPanel(with: appState)
    }

    func dismissPanel() {
        floatingPanel?.dismissPanel()
    }
}
