import SwiftUI
import Speech
import AVFoundation

struct SetupWizardView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var currentStep = 0
    @State private var micPermission = false
    @State private var speechPermission = false
    @State private var ollamaConnected = false
    @State private var isCheckingOllama = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("BlazingVoice セットアップ")
                    .font(.title2.bold())
            }
            .padding(.top, 24)

            // Progress
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Spacer()

            // Step content
            Group {
                switch currentStep {
                case 0: microphoneStep
                case 1: speechRecognitionStep
                case 2: ollamaStep
                case 3: completionStep
                default: EmptyView()
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Navigation
            HStack {
                if currentStep > 0 && currentStep < totalSteps - 1 {
                    Button("戻る") {
                        currentStep -= 1
                    }
                }
                Spacer()
                if currentStep < totalSteps - 1 {
                    Button("次へ") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("完了") {
                        settings.setupCompleted = true
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Steps

    private var microphoneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("マイクのアクセス許可")
                .font(.title3.bold())
            Text("BlazingVoiceが音声を録音するためにマイクへのアクセスが必要です。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            statusBadge(granted: micPermission)

            Button(micPermission ? "許可済み" : "マイクを許可する") {
                SpeechRecognizer.requestMicrophoneAccess { granted in
                    micPermission = granted
                }
            }
            .disabled(micPermission)
        }
        .onAppear {
            micPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    private var speechRecognitionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "ear.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            Text("音声認識の許可")
                .font(.title3.bold())
            Text("音声をテキストに変換するためにAppleの音声認識機能を使用します。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            statusBadge(granted: speechPermission)

            Button(speechPermission ? "許可済み" : "音声認識を許可する") {
                SpeechRecognizer.requestAuthorization { granted in
                    speechPermission = granted
                }
            }
            .disabled(speechPermission)
        }
        .onAppear {
            speechPermission = SFSpeechRecognizer.authorizationStatus() == .authorized
        }
    }

    private var ollamaStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundColor(.cyan)
            Text("Ollama接続確認")
                .font(.title3.bold())
            Text("SOAP整形にローカルLLM（Ollama）を使用します。\nOllamaがインストールされ、起動していることを確認してください。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            statusBadge(granted: ollamaConnected)

            TextField("Ollamaエンドポイント:", text: $settings.ollamaEndpoint)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Button(isCheckingOllama ? "確認中..." : "接続テスト") {
                checkOllama()
            }
            .disabled(isCheckingOllama)

            if !ollamaConnected {
                Text("Ollamaが未起動でも後から設定できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            checkOllama()
        }
    }

    private var completionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("セットアップ完了!")
                .font(.title3.bold())
            Text("BlazingVoiceの準備が整いました。\n\n⌥ Space（Option + Space）で録音を開始できます。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                permissionRow("マイク", granted: micPermission)
                permissionRow("音声認識", granted: speechPermission)
                permissionRow("Ollama", granted: ollamaConnected)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusBadge(granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(granted ? .green : .orange)
            Text(granted ? "許可済み" : "未許可")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func permissionRow(_ label: String, granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundColor(granted ? .green : .orange)
            Text(label)
        }
    }

    private func checkOllama() {
        isCheckingOllama = true
        let client = OllamaClient(settings: settings)
        Task {
            let ok = await client.checkConnection()
            await MainActor.run {
                ollamaConnected = ok
                isCheckingOllama = false
            }
        }
    }
}
