import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    @State private var selectedModel: String = Constants.defaultModel

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
                    Text(Constants.Hotkey.displayString)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("단축키")
            } footer: {
                Text("텍스트를 선택한 후 \(Constants.Hotkey.displayString)를 눌러 번역합니다.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
        .onAppear {
            if let savedKey = KeychainManager.load() {
                apiKey = savedKey
            }
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
