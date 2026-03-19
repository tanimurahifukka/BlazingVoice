import SwiftUI
import AppKit
import Combine

final class AppSettings: ObservableObject {
    // MARK: - General
    @AppStorage("setupCompleted") var setupCompleted: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    // MARK: - Hotkey
    @AppStorage("hotkeyModifierFlags") var hotkeyModifierFlags: Int = Int(NSEvent.ModifierFlags.option.rawValue)
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 49 // Space

    // MARK: - Audio
    @AppStorage("maxRecordingDuration") var maxRecordingDuration: Double = 300 // 5 minutes
    @AppStorage("useOnDeviceRecognition") var useOnDeviceRecognition: Bool = true

    // MARK: - LLM
    @AppStorage("llmBackend") var llmBackendRaw: String = LLMBackend.hayabusa.rawValue

    var llmBackend: LLMBackend {
        get { LLMBackend(rawValue: llmBackendRaw) ?? .hayabusa }
        set { llmBackendRaw = newValue.rawValue }
    }

    // Ollama
    @AppStorage("ollamaEndpoint") var ollamaEndpoint: String = "http://127.0.0.1:11434"
    @AppStorage("ollamaModel") var ollamaModel: String = "qwen3.5:4b"
    @AppStorage("ollamaTimeout") var ollamaTimeout: Double = 120

    // Hayabusa
    @AppStorage("hayabusaEndpoint") var hayabusaEndpoint: String = "http://127.0.0.1:8080"
    @AppStorage("hayabusaModel") var hayabusaModel: String = "default"
    @AppStorage("hayabusaTimeout") var hayabusaTimeout: Double = 120

    @AppStorage("customPrompt") var customPrompt: String = ""
    @AppStorage("llmMaxOutputTokens") var llmMaxOutputTokens: Int = 512
    @AppStorage("llmTemperature") var llmTemperature: Double = 0.1

    var effectivePrompt: String {
        customPrompt.isEmpty ? PromptTemplate.defaultSOAPPrompt : customPrompt
    }

    func createLLMClient() -> LLMClient {
        switch llmBackend {
        case .ollama: return OllamaClient(settings: self)
        case .hayabusa: return HayabusaClient(settings: self)
        }
    }

    // MARK: - Security
    @AppStorage("secureMode") var secureMode: Bool = true
}
