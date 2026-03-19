import AppKit
import AVFoundation
import Combine
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let settings = AppSettings()
    private(set) var statusBarController: StatusBarController!
    private(set) var hotkeyManager: HotkeyManager!
    private(set) var speechRecognizer: SpeechRecognizer!
    private(set) var userDictionary: UserDictionary!
    private(set) var llmClient: LLMClient!
    private(set) var sessionHistory: SessionHistory!

    private var cancellables = Set<AnyCancellable>()
    private let overlay = OverlayPanel()

    enum PipelineState {
        case idle, recording, processing, done, error
    }
    @Published var pipelineState: PipelineState = .idle

    func applicationDidFinishLaunching(_ notification: Notification) {
        userDictionary = UserDictionary()
        llmClient = settings.createLLMClient()
        sessionHistory = SessionHistory()
        speechRecognizer = SpeechRecognizer()

        statusBarController = StatusBarController(appDelegate: self)
        hotkeyManager = HotkeyManager(settings: settings) { [weak self] in
            self?.handleHotkeyPress()
        }

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }

        if !settings.setupCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openSetupWizard()
            }
        }
    }

    /// バックエンド変更時にクライアントを再生成
    func refreshLLMClient() {
        llmClient = settings.createLLMClient()
        print("[BlazingVoice] switched to \(settings.llmBackend.displayName)")
    }

    func openSetupWizard() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title == "セットアップ" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Pipeline

    func handleHotkeyPress() {
        switch pipelineState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break
        }
    }

    func startRecording() {
        pipelineState = .recording
        statusBarController.updateState(.recording)

        speechRecognizer.startRecording { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    self?.processRecognizedText(text)
                case .failure(let error):
                    self?.handleError(error.localizedDescription)
                }
            }
        }
    }

    func stopRecording() {
        speechRecognizer.stopRecording()
    }

    private func processRecognizedText(_ rawText: String) {
        print("[BlazingVoice] processRecognizedText: \(rawText)")
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError("音声が認識されませんでした")
            return
        }

        pipelineState = .processing
        statusBarController.updateState(.processing)

        let correctedText = userDictionary.applyReplacements(to: rawText)
        print("[BlazingVoice] sending to \(settings.llmBackend.displayName): \(correctedText)")

        Task {
            do {
                let soapText = try await llmClient.generateSOAP(from: correctedText)
                print("[BlazingVoice] SOAP result: \(soapText.prefix(100))")
                if let url = self.speechRecognizer.lastRecordingURL {
                    SpeechRecognizer.saveMetadata(for: url, rawText: rawText, soapText: soapText)
                }
                await MainActor.run {
                    copyToClipboard(soapText, rawText: rawText)
                }
            } catch {
                print("[BlazingVoice] SOAP error: \(error)")
                await MainActor.run {
                    handleError("SOAP生成エラー: \(error.localizedDescription)")
                }
            }
        }
    }

    private func copyToClipboard(_ text: String, rawText: String) {
        sessionHistory.addSession(rawText: rawText, soapText: text)
        statusBarController.refreshMenu()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        pipelineState = .done
        statusBarController.updateState(.done)
        overlay.show("⌘V でペーストできます", symbol: "doc.on.clipboard.fill", duration: 3.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.pipelineState == .done {
                self?.pipelineState = .idle
                self?.statusBarController.updateState(.idle)
            }
        }
    }

    private func handleError(_ message: String) {
        pipelineState = .error
        statusBarController.updateState(.error)
        statusBarController.showError(message)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.pipelineState == .error {
                self?.pipelineState = .idle
                self?.statusBarController.updateState(.idle)
            }
        }
    }
}
