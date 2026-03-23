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

            Section("不満点を投稿して進化") {
                feedbackAndEvolveView
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
            Text("\(entries.count)件のログ")
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
            evolutionMessage = nil
        }
    }

    // MARK: - Feedback + Evolve (統合ビュー)

    @ViewBuilder
    private var feedbackAndEvolveView: some View {
        if let entry = selectedEntry {
            // --- 選択中のログ内容 ---
            VStack(alignment: .leading, spacing: 6) {
                logDetailRow("音声認識(生)", entry.rawText, lines: 2)
                logDetailRow("辞書適用後", entry.correctedText, lines: 2)
                logDetailRow("SOAP出力", String(entry.soapText.prefix(300)), lines: 4)
            }

            Divider()

            // --- 不満点入力 ---
            Text("不満点:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $feedbackText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 60)
                .border(Color.secondary.opacity(0.3))

            // --- 投稿 & 進化ボタン ---
            HStack(spacing: 12) {
                Button(action: submitAndEvolve) {
                    if isEvolving {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("LLM処理中...")
                                .font(.caption)
                        }
                    } else {
                        Label("投稿して進化実行", systemImage: "sparkles")
                    }
                }
                .disabled(isEvolving || feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("選択解除") {
                    selectedEntry = nil
                    feedbackText = ""
                    evolutionMessage = nil
                }
                .disabled(isEvolving)
            }

            // --- 結果表示 ---
            if let msg = evolutionMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: evolutionMessageIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(evolutionMessageIsError ? .red : .green)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(evolutionMessageIsError ? .red : .primary)
                }
                .padding(.vertical, 4)
            }
        } else {
            Text("上のログからエントリを選択し、不満点を入力して投稿してください。\nLLMが辞書とプロンプトを自動改善します。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func logDetailRow(_ label: String, _ text: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(lines)
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(4)
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

    // MARK: - Submit & Evolve (ワンアクション)

    private func submitAndEvolve() {
        guard let entry = selectedEntry else { return }
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. フィードバック保存
        appDelegate.evolutionLog.addFeedback(entryId: entry.id, feedback: trimmed)
        if let updated = appDelegate.evolutionLog.entries.first(where: { $0.id == entry.id }) {
            selectedEntry = updated
        }

        // 2. 即座にLLM進化実行
        isEvolving = true
        evolutionMessage = nil

        let evolver = PromptEvolver(settings: settings)
        let feedbackEntries = [appDelegate.evolutionLog.entries.first(where: { $0.id == entry.id })].compactMap { $0 }
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
                    var addedCount = 0
                    for addition in result.dictionaryAdditions {
                        let alreadyExists = appDelegate.userDictionary.entries.contains {
                            $0.from == addition.from && $0.to == addition.to
                        }
                        if !alreadyExists {
                            appDelegate.userDictionary.addEntry(from: addition.from, to: addition.to)
                            addedCount += 1
                        }
                    }

                    // プロンプト更新
                    let promptUpdated = result.newPrompt != currentPrompt && !result.newPrompt.isEmpty
                    if promptUpdated {
                        settings.customPrompt = result.newPrompt
                    }

                    // 進化記録を保存
                    let record = EvolutionLog.EvolutionRecord(
                        id: UUID(),
                        date: Date(),
                        feedbackUsed: [trimmed],
                        dictionaryAdded: result.dictionaryAdditions.map { ["from": $0.from, "to": $0.to] },
                        promptBefore: currentPrompt,
                        promptAfter: result.newPrompt,
                        summary: result.summary
                    )
                    appDelegate.evolutionLog.addEvolutionRecord(record)

                    // 結果メッセージ
                    var parts: [String] = []
                    if addedCount > 0 { parts.append("辞書+\(addedCount)件") }
                    if promptUpdated { parts.append("プロンプト更新") }
                    let changes = parts.isEmpty ? "変更なし" : parts.joined(separator: " / ")
                    evolutionMessage = "進化完了 (\(changes)): \(result.summary)"
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
