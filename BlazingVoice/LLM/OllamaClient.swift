import Foundation

final class OllamaClient: LLMClient {
    private let settings: AppSettings

    enum OllamaError: LocalizedError {
        case invalidURL
        case connectionFailed(String)
        case invalidResponse
        case emptyResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Ollamaの接続先URLが不正です"
            case .connectionFailed(let msg): return "Ollamaに接続できません: \(msg)"
            case .invalidResponse: return "Ollamaからの応答が不正です"
            case .emptyResponse: return "Ollamaからの応答が空です"
            case .httpError(let code): return "OllamaがHTTPエラーを返しました: \(code)"
            }
        }
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - SOAP Generation

    func generateSOAP(from text: String) async throws -> String {
        let endpoint = settings.ollamaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/api/chat") else {
            throw OllamaError.invalidURL
        }

        let messages = PromptTemplate.buildMessages(
            systemPrompt: settings.effectivePrompt,
            userInput: text
        )

        let body: [String: Any] = [
            "model": settings.ollamaModel,
            "messages": messages,
            "stream": false,
            "options": ["num_predict": 2048],
            "think": false
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = settings.ollamaTimeout

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OllamaError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OllamaError.invalidResponse
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OllamaError.emptyResponse
        }

        return trimmed
    }

    // MARK: - Model List

    func fetchModels() async throws -> [String] {
        let endpoint = settings.ollamaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            throw OllamaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OllamaError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OllamaError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw OllamaError.invalidResponse
        }

        return models.compactMap { $0["name"] as? String }
    }

    // MARK: - Health Check

    func checkConnection() async -> Bool {
        let endpoint = settings.ollamaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/api/tags") else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
