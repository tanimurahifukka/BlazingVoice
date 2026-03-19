import Foundation

/// Hayabusa LLM推論サーバー用クライアント (OpenAI互換API)
final class HayabusaClient: LLMClient {
    private let settings: AppSettings
    private let session: URLSession

    enum HayabusaError: LocalizedError {
        case invalidURL
        case connectionFailed(String)
        case invalidResponse
        case emptyResponse
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Hayabusaの接続先URLが不正です"
            case .connectionFailed(let msg): return "Hayabusaに接続できません: \(msg)"
            case .invalidResponse: return "Hayabusaからの応答が不正です"
            case .emptyResponse: return "Hayabusaからの応答が空です"
            case .httpError(let code, let msg): return "Hayabusa HTTPエラー \(code): \(msg)"
            }
        }
    }

    init(settings: AppSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = settings.hayabusaTimeout
        config.timeoutIntervalForResource = settings.hayabusaTimeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - SOAP Generation

    func generateSOAP(from text: String) async throws -> String {
        let endpoint = settings.hayabusaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/v1/chat/completions") else {
            throw HayabusaError.invalidURL
        }

        let messages = PromptTemplate.buildMessages(
            systemPrompt: settings.effectivePrompt,
            userInput: text
        )

        let body: [String: Any] = [
            "model": settings.hayabusaModel,
            "messages": messages,
            "max_tokens": settings.llmMaxOutputTokens,
            "temperature": settings.llmTemperature,
            "stream": false
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("high", forHTTPHeaderField: "X-Priority")
        request.httpBody = jsonData
        request.timeoutInterval = settings.hayabusaTimeout

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HayabusaError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HayabusaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw HayabusaError.httpError(httpResponse.statusCode, body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw HayabusaError.invalidResponse
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HayabusaError.emptyResponse
        }

        return trimmed
    }

    // MARK: - Model List

    func fetchModels() async throws -> [String] {
        let endpoint = settings.hayabusaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/v1/models") else {
            throw HayabusaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HayabusaError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw HayabusaError.invalidResponse
        }

        // OpenAI format: {"data": [{"id": "model-name", ...}]}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["data"] as? [[String: Any]] {
            return models.compactMap { $0["id"] as? String }
        }

        // Hayabusa may return simple format
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            return models.compactMap { $0["name"] as? String ?? $0["id"] as? String }
        }

        return [settings.hayabusaModel]
    }

    // MARK: - Health Check

    func checkConnection() async -> Bool {
        let endpoint = settings.hayabusaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/health") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func warmUp() async {
        let endpoint = settings.hayabusaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/v1/chat/completions") else { return }

        let body: [String: Any] = [
            "model": settings.hayabusaModel,
            "messages": [
                ["role": "system", "content": "簡潔に応答してください。"],
                ["role": "user", "content": "ok"]
            ],
            "max_tokens": 8,
            "temperature": 0,
            "stream": false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = min(settings.hayabusaTimeout, 15)

        _ = try? await session.data(for: request)
    }
}
