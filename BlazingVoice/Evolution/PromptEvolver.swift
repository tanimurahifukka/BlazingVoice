import Foundation

/// フィードバックを元にLocal LLMで辞書・プロンプトを自動進化させる
final class PromptEvolver {
    private let settings: AppSettings

    enum EvolverError: LocalizedError {
        case noFeedback
        case llmFailed(String)
        case parseFailed

        var errorDescription: String? {
            switch self {
            case .noFeedback: return "進化に使えるフィードバックがありません"
            case .llmFailed(let msg): return "LLM呼び出しエラー: \(msg)"
            case .parseFailed: return "LLMの応答をパースできませんでした"
            }
        }
    }

    struct EvolutionResult {
        let dictionaryAdditions: [(from: String, to: String)]
        let newPrompt: String
        let summary: String
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// フィードバック付きログを分析してプロンプト＆辞書の改善案を生成
    func evolve(
        feedbackEntries: [EvolutionLog.LogEntry],
        currentPrompt: String,
        currentDictionary: [(from: String, to: String)]
    ) async throws -> EvolutionResult {
        guard !feedbackEntries.isEmpty else {
            throw EvolverError.noFeedback
        }

        let analysisPrompt = buildAnalysisPrompt(
            feedbackEntries: feedbackEntries,
            currentPrompt: currentPrompt,
            currentDictionary: currentDictionary
        )

        let response = try await callOllama(systemPrompt: analysisPrompt, userInput: "上記のフィードバックを分析し、改善案をJSON形式で出力してください。")

        return try parseEvolutionResponse(response, currentPrompt: currentPrompt)
    }

    // MARK: - Prompt Construction

    private func buildAnalysisPrompt(
        feedbackEntries: [EvolutionLog.LogEntry],
        currentPrompt: String,
        currentDictionary: [(from: String, to: String)]
    ) -> String {
        var prompt = """
        あなたは医療音声認識システムの改善アシスタントです。
        ユーザーのフィードバック（不満点）を分析し、以下の2つを改善してください：

        1. **辞書エントリ**: 音声認識の誤変換を修正するための置換ルール
        2. **システムプロンプト**: SOAP記録生成の品質を向上させるための指示文

        ## 現在のシステムプロンプト
        ```
        \(currentPrompt)
        ```

        ## 現在の辞書エントリ
        """

        for entry in currentDictionary {
            prompt += "\n- 「\(entry.from)」→「\(entry.to)」"
        }

        prompt += "\n\n## フィードバック付きの実行ログ\n"

        for (i, entry) in feedbackEntries.enumerated() {
            prompt += """

            ### ケース\(i + 1)
            - 音声認識(生): \(entry.rawText)
            - 辞書適用後: \(entry.correctedText)
            - LLM出力: \(entry.soapText.prefix(500))
            - **不満点**: \(entry.feedback ?? "なし")

            """
        }

        prompt += """

        ## 出力形式（厳密にこのJSONフォーマットで出力）
        ```json
        {
          "dictionary_additions": [
            {"from": "誤変換テキスト", "to": "正しいテキスト"}
          ],
          "prompt_improvements": "改善されたシステムプロンプト全文",
          "summary": "変更内容の要約（日本語）"
        }
        ```

        重要なルール：
        - 既存の辞書エントリと重複する追加は不要
        - プロンプトの基本構造（SOAP形式）は維持する
        - フィードバックに基づく具体的な改善のみ行う
        - JSON以外のテキストは出力しない
        """

        return prompt
    }

    // MARK: - LLM Call (Ollama直接呼び出し)

    private func callOllama(systemPrompt: String, userInput: String) async throws -> String {
        // 進化用は常にOllamaを使う（大きめモデルが望ましい）
        let endpoint = settings.ollamaEndpoint.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(endpoint)/api/chat") else {
            throw EvolverError.llmFailed("Ollamaの接続先URLが不正です")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userInput]
        ]

        let body: [String: Any] = [
            "model": settings.ollamaModel,
            "messages": messages,
            "stream": false,
            "options": ["num_predict": 2048, "temperature": 0.3],
            "think": false
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 180 // 進化処理は時間がかかる

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EvolverError.llmFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EvolverError.llmFailed("HTTPエラー")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw EvolverError.llmFailed("応答パースエラー")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Parse Response

    private func parseEvolutionResponse(_ response: String, currentPrompt: String) throws -> EvolutionResult {
        // JSONブロックを抽出（```json ... ``` 内、またはそのまま）
        let jsonString: String
        if let start = response.range(of: "```json"),
           let end = response.range(of: "```", range: start.upperBound..<response.endIndex) {
            jsonString = String(response[start.upperBound..<end.lowerBound])
        } else if let start = response.range(of: "{"),
                  let end = response.range(of: "}", options: .backwards) {
            jsonString = String(response[start.lowerBound...end.upperBound])
        } else {
            throw EvolverError.parseFailed
        }

        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EvolverError.parseFailed
        }

        // 辞書追加
        var additions: [(from: String, to: String)] = []
        if let dictArray = parsed["dictionary_additions"] as? [[String: String]] {
            for item in dictArray {
                if let from = item["from"], let to = item["to"], !from.isEmpty {
                    additions.append((from: from, to: to))
                }
            }
        }

        // プロンプト改善
        let newPrompt = (parsed["prompt_improvements"] as? String) ?? currentPrompt

        // サマリ
        let summary = (parsed["summary"] as? String) ?? "変更内容の詳細は不明です"

        return EvolutionResult(
            dictionaryAdditions: additions,
            newPrompt: newPrompt,
            summary: summary
        )
    }
}
