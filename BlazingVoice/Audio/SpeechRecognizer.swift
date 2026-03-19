import Speech
import AVFoundation

final class SpeechRecognizer {
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var autoStopTimer: Timer?
    private var completion: ((Result<String, Error>) -> Void)?
    private var bestTranscription: String = ""
    private(set) var lastRecordingURL: URL?

    enum RecognizerError: LocalizedError {
        case notAuthorized
        case notAvailable
        case audioEngineError
        case noResult

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "音声認識の権限がありません"
            case .notAvailable: return "音声認識が利用できません"
            case .audioEngineError: return "オーディオエンジンの起動に失敗しました"
            case .noResult: return "音声が認識されませんでした"
            }
        }
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    }

    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    // MARK: - Authorization

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    static func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording(maxDuration: TimeInterval = 300, completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        bestTranscription = ""

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        print("[BlazingVoice] mic: \(micStatus.rawValue), speech: \(speechStatus.rawValue)")

        guard micStatus == .authorized else {
            completion(.failure(RecognizerError.notAuthorized))
            return
        }

        guard speechStatus == .authorized else {
            completion(.failure(RecognizerError.notAuthorized))
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            completion(.failure(RecognizerError.notAvailable))
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)
        print("[BlazingVoice] input format: \(hwFormat)")
        print("[BlazingVoice] channels: \(hwFormat.channelCount), sampleRate: \(hwFormat.sampleRate)")
        print("[BlazingVoice] default mic: \(AVCaptureDevice.default(for: .audio)?.localizedName ?? "NONE")")

        // 録音ファイルの準備
        let recordingURL = SpeechRecognizer.newRecordingURL()
        lastRecordingURL = recordingURL
        let tapFormat = inputNode.outputFormat(forBus: 0)
        do {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: tapFormat.settings)
        } catch {
            print("[BlazingVoice] could not create audio file: \(error)")
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            request.append(buffer)
            try? self?.audioFile?.write(from: buffer)
        }
        print("[BlazingVoice] tap installed on new engine")

        do {
            engine.prepare()
            try engine.start()
            print("[BlazingVoice] engine started")
        } catch {
            print("[BlazingVoice] engine failed: \(error)")
            finishRecording(withError: RecognizerError.audioEngineError)
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.bestTranscription = result.bestTranscription.formattedString
                print("[BlazingVoice] recognized: \(self.bestTranscription)")
                if result.isFinal {
                    self.finishRecording(with: self.bestTranscription)
                }
            }
            if let error {
                print("[BlazingVoice] recognition error: \(error)")
                if self.audioEngine?.isRunning == true {
                    self.finishRecording(withError: error)
                }
            }
        }

        autoStopTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    func stopRecording() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil

        recognitionRequest?.endAudio()

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
    }

    private func finishRecording(with text: String) {
        cleanup()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completion?(.failure(RecognizerError.noResult))
        } else {
            completion?(.success(text))
        }
        completion = nil
    }

    private func finishRecording(withError error: Error) {
        cleanup()
        if !bestTranscription.isEmpty {
            completion?(.success(bestTranscription))
        } else {
            completion?(.failure(error))
        }
        completion = nil
    }

    private func cleanup() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        audioFile = nil
    }

    // MARK: - Recording Storage

    static let recordingsDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("BlazingVoice/Recordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func newRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let name = formatter.string(from: Date())
        return recordingsDirectory.appendingPathComponent("\(name).caf")
    }

    static func saveMetadata(for recordingURL: URL, rawText: String, soapText: String) {
        let meta: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: Date()),
            "audioFile": recordingURL.lastPathComponent,
            "rawText": rawText,
            "soapText": soapText
        ]
        let jsonURL = recordingURL.deletingPathExtension().appendingPathExtension("json")
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: .prettyPrinted) {
            try? data.write(to: jsonURL)
            print("[BlazingVoice] saved metadata: \(jsonURL.lastPathComponent)")
        }
    }
}
