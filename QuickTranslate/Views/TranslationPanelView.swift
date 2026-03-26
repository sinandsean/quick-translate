import SwiftUI
import AppKit

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        backgroundColor = .windowBackgroundColor
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        minSize = NSSize(width: Constants.Panel.width, height: Constants.Panel.minHeight)
        maxSize = NSSize(width: 600, height: 2000)
    }

    func showPanel(with appState: AppState) {
        let hostingView = NSHostingView(rootView: TranslationContentView(appState: appState, onClose: { [weak self] in
            self?.dismissPanel()
        }))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView = hostingView

        let panelWidth = Constants.Panel.width
        let panelHeight = calculateHeight(for: appState)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let xPos = screenFrame.maxX - panelWidth - 12
        let yPos = screenFrame.maxY - panelHeight - 12

        let targetFrame = NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight)

        setFrame(NSRect(x: xPos + panelWidth, y: yPos, width: panelWidth, height: panelHeight), display: false)
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.Panel.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 1.0
        }
    }

    func dismissPanel() {
        let currentFrame = frame
        let targetFrame = NSRect(
            x: currentFrame.origin.x + currentFrame.width,
            y: currentFrame.origin.y,
            width: currentFrame.width,
            height: currentFrame.height
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.Panel.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
        })
    }

    func updateContent(with appState: AppState) {
        let hostingView = NSHostingView(rootView: TranslationContentView(appState: appState, onClose: { [weak self] in
            self?.dismissPanel()
        }))
        contentView = hostingView

        let newHeight = calculateHeight(for: appState)
        var currentFrame = frame
        let oldHeight = currentFrame.height
        currentFrame.size.height = newHeight
        currentFrame.origin.y += (oldHeight - newHeight)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        if currentFrame.origin.y < screenFrame.minY {
            currentFrame.origin.y = screenFrame.minY
        }

        setFrame(currentFrame, display: true, animate: true)
    }

    private func calculateHeight(for appState: AppState) -> CGFloat {
        guard let screen = NSScreen.main else { return Constants.Panel.minHeight }
        let maxScreenHeight = screen.visibleFrame.height - 24

        if appState.isTranslating {
            return Constants.Panel.minHeight
        }
        if appState.errorMessage != nil {
            return 220
        }
        if let result = appState.currentResult {
            let originalLines = CGFloat(result.originalText.components(separatedBy: .newlines).count)
            let translatedLines = CGFloat(result.translatedText.components(separatedBy: .newlines).count)
            let originalCharHeight = ceil(CGFloat(result.originalText.count) / 40) * 20
            let translatedCharHeight = ceil(CGFloat(result.translatedText.count) / 40) * 20
            let textHeight = max(originalLines * 20, originalCharHeight) + max(translatedLines * 20, translatedCharHeight)
            let estimated = textHeight + 140 // header, divider, buttons, padding
            return min(maxScreenHeight, max(Constants.Panel.minHeight, estimated))
        }
        return Constants.Panel.minHeight
    }
}

struct TranslationContentView: View {
    let appState: AppState
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "translate")
                    .foregroundColor(.accentColor)
                Text("QuickTranslate")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if appState.isTranslating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Translating...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = appState.errorMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Error")
                                .font(.subheadline.bold())
                        }
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                }
            } else if let result = appState.currentResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Original text
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.sourceLanguage)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(result.originalText)
                                .font(.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()

                        // Translated text
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(result.targetLanguage)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(result.translatedText, forType: .string)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text(result.translatedText)
                                .font(.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: Constants.Panel.width, minHeight: Constants.Panel.minHeight)
    }
}
