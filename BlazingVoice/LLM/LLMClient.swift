import Foundation

/// LLMバックエンド共通プロトコル
protocol LLMClient {
    func generateSOAP(from text: String) async throws -> String
    func fetchModels() async throws -> [String]
    func checkConnection() async -> Bool
}

enum LLMBackend: String, CaseIterable, Identifiable {
    case ollama = "ollama"
    case hayabusa = "hayabusa"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .hayabusa: return "Hayabusa (高速)"
        }
    }
}
