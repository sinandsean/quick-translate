import SwiftUI
import Carbon

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    @State private var selectedModel: String = Constants.defaultModel
    @State private var hotkeyDisplay: String = HotkeyConfig.load().displayString
    @State private var isRecording = false

    private let apiService = ClaudeAPIService()
    private let availableModels = [
        "claude-sonnet-4-5",
        "claude-haiku-4-5"
    ]

    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                SecureField("API 키를 입력하세요", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("저장") {
                        if KeychainManager.save(apiKey: apiKey) {
                            testStatus = .success
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    Button("연결 테스트") {
                        testConnection()
                    }
                    .disabled(apiKey.isEmpty)

                    Spacer()

                    switch testStatus {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                            .scaleEffect(0.6)
                    case .success:
                        Label("연결 성공", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Claude API 키")
            }

            Section {
                Picker("모델", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            } header: {
                Text("번역 설정")
            }

            Section {
                HStack {
                    Text("단축키")
                    Spacer()

                    KeyRecorderButton(
                        displayString: $hotkeyDisplay,
                        isRecording: $isRecording
                    )
                }
            } header: {
                Text("단축키")
            } footer: {
                Text("클릭 후 수정자 키(⌃⌥⇧⌘) + 일반 키 조합을 함께 누르세요. 예: ⌃T, ⌥D. Esc로 취소.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 340)
        .onAppear {
            if let savedKey = KeychainManager.load() {
                apiKey = savedKey
            }
            hotkeyDisplay = HotkeyConfig.load().displayString
        }
        .onChange(of: selectedModel) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedModel")
        }
    }

    private func testConnection() {
        testStatus = .testing
        Task {
            do {
                let success = try await apiService.testConnection(apiKey: apiKey)
                await MainActor.run {
                    testStatus = success ? .success : .failure("연결 실패")
                }
            } catch {
                await MainActor.run {
                    testStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}

struct KeyRecorderButton: NSViewRepresentable {
    @Binding var displayString: String
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> KeyRecorderNSButton {
        let button = KeyRecorderNSButton()
        button.title = displayString
        button.bezelStyle = .recessed
        button.setButtonType(.pushOnPushOff)
        button.isBordered = true
        button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        button.onKeyRecorded = { config in
            context.coordinator.keyRecorded(config: config)
        }
        button.onCancelled = {
            context.coordinator.cancelled()
        }
        return button
    }

    func updateNSView(_ nsView: KeyRecorderNSButton, context: Context) {
        if !isRecording {
            nsView.title = displayString
            nsView.state = .off
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: KeyRecorderButton

        init(_ parent: KeyRecorderButton) {
            self.parent = parent
        }

        @objc func buttonClicked(_ sender: KeyRecorderNSButton) {
            if sender.state == .on {
                parent.isRecording = true
                sender.title = "수정자 키 + 일반 키를 누르세요"
                sender.window?.makeFirstResponder(sender)
            } else {
                parent.isRecording = false
                sender.title = parent.displayString
            }
        }

        func keyRecorded(config: HotkeyConfig) {
            parent.displayString = config.displayString
            parent.isRecording = false

            NotificationCenter.default.post(
                name: .hotkeyChanged,
                object: nil,
                userInfo: ["config": config]
            )
        }

        func cancelled() {
            parent.isRecording = false
        }
    }
}

class KeyRecorderNSButton: NSButton {
    var onKeyRecorded: ((HotkeyConfig) -> Void)?
    var onCancelled: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard state == .on else {
            super.keyDown(with: event)
            return
        }

        // Esc to cancel
        if event.keyCode == UInt16(kVK_Escape) {
            state = .off
            onCancelled?()
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        // Must have at least one modifier (Ctrl, Option, Cmd, Shift)
        guard !modifiers.isEmpty else { return }
        // Don't accept modifier-only presses
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modifierKeyCodes.contains(event.keyCode) else { return }

        let config = HotkeyConfig(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: HotkeyConfig.nsModifiersToCarbonModifiers(modifiers),
            nsModifiers: modifiers,
            displayString: HotkeyConfig.displayString(keyCode: event.keyCode, modifiers: modifiers)
        )

        title = config.displayString
        state = .off
        onKeyRecorded?(config)
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore modifier-only events
    }
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}
