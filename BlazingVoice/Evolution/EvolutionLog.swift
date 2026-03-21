import Foundation

/// パイプライン実行ログ（前後保存）＋フィードバック管理
final class EvolutionLog: ObservableObject {
    struct LogEntry: Identifiable, Codable {
        let id: UUID
        let date: Date
        let rawText: String        // 音声認識そのまま
        let correctedText: String  // 辞書適用後（LLMに渡す前）
        let soapText: String       // LLM出力（AIから返ってきた後）
        let promptUsed: String     // 使用したプロンプト
        var feedback: String?      // ユーザーの不満点
        var feedbackDate: Date?

        init(rawText: String, correctedText: String, soapText: String, promptUsed: String) {
            self.id = UUID()
            self.date = Date()
            self.rawText = rawText
            self.correctedText = correctedText
            self.soapText = soapText
            self.promptUsed = promptUsed
        }
    }

    struct EvolutionRecord: Identifiable, Codable {
        let id: UUID
        let date: Date
        let feedbackUsed: [String]       // 反映したフィードバック一覧
        let dictionaryAdded: [[String: String]]  // 追加された辞書エントリ [["from":"x","to":"y"]]
        let promptBefore: String
        let promptAfter: String
        let summary: String              // LLMによる変更サマリ
    }

    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var evolutionHistory: [EvolutionRecord] = []

    private let maxEntries = 100
    private let entriesFileURL: URL
    private let evolutionFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BlazingVoice/Evolution", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        entriesFileURL = dir.appendingPathComponent("pipeline_log.json")
        evolutionFileURL = dir.appendingPathComponent("evolution_history.json")

        loadEntries()
        loadEvolutionHistory()
    }

    // MARK: - Log Pipeline Execution

    @discardableResult
    func logPipeline(rawText: String, correctedText: String, soapText: String, promptUsed: String) -> LogEntry {
        let entry = LogEntry(rawText: rawText, correctedText: correctedText, soapText: soapText, promptUsed: promptUsed)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        saveEntries()
        return entry
    }

    // MARK: - Feedback

    func addFeedback(entryId: UUID, feedback: String) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        entries[index].feedback = feedback
        entries[index].feedbackDate = Date()
        saveEntries()
    }

    /// フィードバック付きエントリを返す
    var entriesWithFeedback: [LogEntry] {
        entries.filter { $0.feedback != nil && !($0.feedback?.isEmpty ?? true) }
    }

    /// まだ進化処理に使われていないフィードバック付きエントリ
    func unresolvedFeedback(since lastEvolutionDate: Date?) -> [LogEntry] {
        entriesWithFeedback.filter { entry in
            guard let fbDate = entry.feedbackDate else { return false }
            if let last = lastEvolutionDate {
                return fbDate > last
            }
            return true
        }
    }

    // MARK: - Evolution History

    func addEvolutionRecord(_ record: EvolutionRecord) {
        evolutionHistory.append(record)
        saveEvolutionHistory()
    }

    // MARK: - Persistence

    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: entriesFileURL, options: .atomic)
    }

    private func loadEntries() {
        guard let data = try? Data(contentsOf: entriesFileURL),
              let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) else { return }
        entries = decoded
    }

    private func saveEvolutionHistory() {
        guard let data = try? JSONEncoder().encode(evolutionHistory) else { return }
        try? data.write(to: evolutionFileURL, options: .atomic)
    }

    private func loadEvolutionHistory() {
        guard let data = try? Data(contentsOf: evolutionFileURL),
              let decoded = try? JSONDecoder().decode([EvolutionRecord].self, from: data) else { return }
        evolutionHistory = decoded
    }

    func clearAll() {
        entries.removeAll()
        saveEntries()
    }
}
