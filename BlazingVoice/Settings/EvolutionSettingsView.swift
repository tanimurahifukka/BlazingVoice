import SwiftUI

struct EvolutionSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var appDelegate: AppDelegate

    @State private var selectedEntry: EvolutionLog.LogEntry?
    @State private var feedbackText = ""
    @State private var isEvolving = false
    @State private var evolutionMessage: String?
    @State private var evolutionMessageIsError = false

    var body: some View {
        Form {
            Section("パイプラインログ") {
                logListView
            }

            Section("フィードバック入力") {
                feedbackInputView
            }

            Section("進化実行") {
                evolutionActionView
            }

            Section("進化履歴") {
                evolutionHistoryView
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Log List

    @ViewBuilder
    private var logListView: some View {
        let entries = appDelegate.evolutionLog.entries
        if entries.isEmpty {
            Text("まだログがありません。音声認識を実行するとここに記録されます。")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("\(entries.count)件のログ（フィードバック付き: \(appDelegate.evolutionLog.entriesWithFeedback.count)件）")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(entries.suffix(20).reversed()) { entry in
                        logEntryRow(entry)
                    }
                }
            }
            .frame(maxHeight: 120)
        }
    }

    private func logEntryRow(_ entry: EvolutionLog.LogEntry) -> some View {
        let isSelected = selectedEntry?.id == entry.id
        let hasFeedback = entry.feedback != nil && !(entry.feedback?.isEmpty ?? true)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(entry.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(entry.rawText.prefix(50)))
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer()
            if hasFeedback {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
            feedbackText = entry.feedback ?? ""
        }
    }

    // MARK: - Feedback Input

    @ViewBuilder
    private var feedbackInputView: some View {
        if let entry = selectedEntry {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text("音声認識(生):").font(.caption).foregroundColor(.secondary)
                    Text(entry.rawText).font(.caption).lineLimit(2)

                    Text("辞書適用後:").font(.caption).foregroundColor(.secondary)
                    Text(entry.correctedText).font(.caption).lineLimit(2)

                    Text("SOAP出力:").font(.caption).foregroundColor(.secondary)
                    Text(String(entry.soapText.prefix(200))).font(.caption).lineLimit(4)
                }

                Divider()

                Text("不満点を入力してください:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $feedbackText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))

                HStack {
                    Button("フィードバック保存") {
                        appDelegate.evolutionLog.addFeedback(entryId: entry.id, feedback: feedbackText)
                        // refresh selection
                        if let updated = appDelegate.evolutionLog.entries.first(where: { $0.id == entry.id }) {
                            selectedEntry = updated
                        }
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    if entry.feedback != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("保存済み")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            Text("上のログからエントリを選択してフィードバックを入力してください。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Evolution Action

    @ViewBuilder
    private var evolutionActionView: some View {
        let lastDate = appDelegate.evolutionLog.evolutionHistory.last?.date
        let unresolvedCount = appDelegate.evolutionLog.unresolvedFeedback(since: lastDate).count

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("未処理フィードバック: \(unresolvedCount)件")
                    .font(.caption)
                if let last = lastDate {
                    Text("前回の進化: \(formatDate(last))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: runEvolution) {
                if isEvolving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("進化実行", systemImage: "sparkles")
                }
            }
            .disabled(isEvolving || unresolvedCount == 0)
        }

        if let msg = evolutionMessage {
            Text(msg)
                .font(.caption)
                .foregroundColor(evolutionMessageIsError ? .red : .green)
                .lineLimit(5)
        }
    }

    // MARK: - Evolution History

    @ViewBuilder
    private var evolutionHistoryView: some View {
        let records = appDelegate.evolutionLog.evolutionHistory
        if records.isEmpty {
            Text("まだ進化履歴がありません。")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            ForEach(records.reversed()) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(formatDate(record.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("辞書+\(record.dictionaryAdded.count)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text(record.summary)
                        .font(.caption)
                        .lineLimit(3)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Evolution Logic

    private func runEvolution() {
        isEvolving = true
        evolutionMessage = nil

        let evolver = PromptEvolver(settings: settings)
        let lastDate = appDelegate.evolutionLog.evolutionHistory.last?.date
        let feedbackEntries = appDelegate.evolutionLog.unresolvedFeedback(since: lastDate)
        let currentPrompt = settings.effectivePrompt
        let currentDict = appDelegate.userDictionary.entries
            .filter { $0.isEnabled }
            .map { (from: $0.from, to: $0.to) }

        Task {
            do {
                let result = try await evolver.evolve(
                    feedbackEntries: feedbackEntries,
                    currentPrompt: currentPrompt,
                    currentDictionary: currentDict
                )

                await MainActor.run {
                    // 辞書に追加
                    for addition in result.dictionaryAdditions {
                        let alreadyExists = appDelegate.userDictionary.entries.contains {
                            $0.from == addition.from && $0.to == addition.to
                        }
                        if !alreadyExists {
                            appDelegate.userDictionary.addEntry(from: addition.from, to: addition.to)
                        }
                    }

                    // プロンプト更新
                    if result.newPrompt != currentPrompt && !result.newPrompt.isEmpty {
                        settings.customPrompt = result.newPrompt
                    }

                    // 進化記録を保存
                    let record = EvolutionLog.EvolutionRecord(
                        id: UUID(),
                        date: Date(),
                        feedbackUsed: feedbackEntries.compactMap { $0.feedback },
                        dictionaryAdded: result.dictionaryAdditions.map { ["from": $0.from, "to": $0.to] },
                        promptBefore: currentPrompt,
                        promptAfter: result.newPrompt,
                        summary: result.summary
                    )
                    appDelegate.evolutionLog.addEvolutionRecord(record)

                    evolutionMessage = "進化完了: \(result.summary)"
                    evolutionMessageIsError = false
                    isEvolving = false
                }
            } catch {
                await MainActor.run {
                    evolutionMessage = "エラー: \(error.localizedDescription)"
                    evolutionMessageIsError = true
                    isEvolving = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
