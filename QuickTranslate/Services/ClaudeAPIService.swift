import Foundation

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case networkError(String)
    case invalidResponse
    case apiError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not set. Go to menu bar → Settings to enter your API key."
        case .invalidURL:
            return "Invalid API URL."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        case .apiError(let message):
            return "API error: \(message)"
        case .timeout:
            return "Request timed out (30s)."
        }
    }
}

actor ClaudeAPIService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        config.timeoutIntervalForResource = Constants.requestTimeout
        self.session = URLSession(configuration: config)
    }

    func translate(text: String, from sourceLang: String, to targetLang: String, model: String) async throws -> String {
        guard let apiKey = KeychainManager.load(), !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        guard let url = URL(string: Constants.apiURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let systemPrompt = "You are a translator. Translate the following text from \(sourceLang) to \(targetLang). Return only the translated text, nothing else."

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClaudeAPIError.timeout
        } catch {
            throw ClaudeAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorInfo = errorBody["error"] as? [String: Any],
               let message = errorInfo["message"] as? String {
                throw ClaudeAPIError.apiError(message)
            }
            throw ClaudeAPIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let translatedText = firstBlock["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        return translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testConnection(apiKey: String) async throws -> Bool {
        guard let url = URL(string: Constants.apiURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Constants.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Constants.defaultModel,
            "max_tokens": 16,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        return httpResponse.statusCode == 200
    }
}
