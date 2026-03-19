import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var connectionStatus: ConnectionStatus = .unknown

    enum ConnectionStatus {
        case unknown, checking, connected, disconnected
    }

    var body: some View {
        Form {
            Section("推論バックエンド") {
                Picker("バックエンド:", selection: Binding(
                    get: { settings.llmBackend },
                    set: { newValue in
                        settings.llmBackend = newValue
                        appDelegate.refreshLLMClient()
                        connectionStatus = .unknown
                        availableModels = []
                        checkConnection()
                    }
                )) {
                    ForEach(LLMBackend.allCases) { backend in
                        Text(backend.displayName).tag(backend)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    if settings.llmBackend == .hayabusa {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.orange)
                        Text("Hayabusa — ローカル高速推論サーバー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "server.rack")
                            .foregroundColor(.blue)
                        Text("Ollama — 汎用LLMランタイム")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("接続") {
                if settings.llmBackend == .hayabusa {
                    hayabusaConnectionSection
                } else {
                    ollamaConnectionSection
                }

                HStack {
                    statusIndicator
                    Spacer()
                    Button("接続テスト") {
                        checkConnection()
                    }
                    .disabled(connectionStatus == .checking)
                }
            }

            Section("モデル") {
                HStack {
                    if settings.llmBackend == .hayabusa {
                        Picker("モデル:", selection: $settings.hayabusaModel) {
                            if availableModels.isEmpty {
                                Text(settings.hayabusaModel).tag(settings.hayabusaModel)
                            }
                            ForEach(availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    } else {
                        Picker("モデル:", selection: $settings.ollamaModel) {
                            if availableModels.isEmpty {
                                Text(settings.ollamaModel).tag(settings.ollamaModel)
                            }
                            ForEach(availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                    Button("更新") {
                        loadModels()
                    }
                    .disabled(isLoadingModels)
                }

                if settings.llmBackend == .ollama {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("おすすめ Qwen3.5 モデル:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            ForEach(Self.qwen35Presets, id: \.tag) { preset in
                                Button {
                                    settings.ollamaModel = preset.tag
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(preset.label)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(preset.size)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(settings.ollamaModel == preset.tag
                                                  ? Color.accentColor.opacity(0.2)
                                                  : Color.secondary.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(settings.ollamaModel == preset.tag
                                                    ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Text("タイムアウト:")
                    Spacer()
                    Picker("", selection: settings.llmBackend == .hayabusa
                           ? $settings.hayabusaTimeout : $settings.ollamaTimeout) {
                        Text("15秒").tag(15.0)
                        Text("30秒").tag(30.0)
                        Text("60秒").tag(60.0)
                        Text("120秒").tag(120.0)
                    }
                    .frame(width: 100)
                }
            }

            Section("プロンプト") {
                Toggle("カスタムプロンプトを使用", isOn: Binding(
                    get: { !settings.customPrompt.isEmpty },
                    set: { newValue in
                        if !newValue {
                            settings.customPrompt = ""
                        } else if settings.customPrompt.isEmpty {
                            settings.customPrompt = PromptTemplate.defaultSOAPPrompt
                        }
                    }
                ))

                if !settings.customPrompt.isEmpty {
                    TextEditor(text: $settings.customPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 150)
                        .border(Color.secondary.opacity(0.3))

                    Button("デフォルトに戻す") {
                        settings.customPrompt = PromptTemplate.defaultSOAPPrompt
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkConnection()
        }
    }

    // MARK: - Qwen3.5 Presets

    private struct ModelPreset {
        let label: String
        let tag: String
        let size: String
    }

    private static let qwen35Presets: [ModelPreset] = [
        ModelPreset(label: "0.8B", tag: "qwen3.5:0.8b", size: "1.0 GB"),
        ModelPreset(label: "2B",   tag: "qwen3.5:2b",   size: "2.7 GB"),
        ModelPreset(label: "4B",   tag: "qwen3.5:4b",   size: "3.4 GB"),
        ModelPreset(label: "9B",   tag: "qwen3.5:9b",   size: "6.6 GB"),
        ModelPreset(label: "27B",  tag: "qwen3.5:27b",  size: "17 GB"),
    ]

    // MARK: - Connection Sections

    private var hayabusaConnectionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("エンドポイント:", text: $settings.hayabusaEndpoint)
                .textFieldStyle(.roundedBorder)
            Text("デフォルト: http://127.0.0.1:8080")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var ollamaConnectionSection: some View {
        TextField("エンドポイント:", text: $settings.ollamaEndpoint)
            .textFieldStyle(.roundedBorder)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch connectionStatus {
        case .unknown: return .gray
        case .checking: return .yellow
        case .connected: return .green
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch connectionStatus {
        case .unknown: return "未確認"
        case .checking: return "確認中..."
        case .connected: return "接続済み (\(settings.llmBackend.displayName))"
        case .disconnected: return "未接続"
        }
    }

    // MARK: - Actions

    private func checkConnection() {
        connectionStatus = .checking
        let client = settings.createLLMClient()
        Task {
            let ok = await client.checkConnection()
            await MainActor.run {
                connectionStatus = ok ? .connected : .disconnected
                if ok { loadModels() }
            }
        }
    }

    private func loadModels() {
        isLoadingModels = true
        let client = settings.createLLMClient()
        Task {
            do {
                let models = try await client.fetchModels()
                await MainActor.run {
                    availableModels = models
                    isLoadingModels = false
                }
            } catch {
                await MainActor.run {
                    isLoadingModels = false
                }
            }
        }
    }
}
