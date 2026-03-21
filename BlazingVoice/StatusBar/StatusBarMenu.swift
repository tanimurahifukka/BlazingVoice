import AppKit

final class StatusBarMenu {
    let menu = NSMenu()
    private weak var appDelegate: AppDelegate?
    private var errorMessage: String?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        rebuildMenu()
    }

    func setErrorMessage(_ message: String?) {
        errorMessage = message
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()

        // Status header
        let stateText: String
        switch appDelegate?.pipelineState {
        case .idle: stateText = "待機中"
        case .recording: stateText = "録音中..."
        case .processing: stateText = "SOAP生成中..."
        case .done: stateText = "クリップボードにコピー済み"
        case .error: stateText = "エラー"
        case .none: stateText = "不明"
        }
        let statusItem = NSMenuItem(title: "状態: \(stateText)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Error message
        if let error = errorMessage {
            let errorItem = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemRed, .font: NSFont.systemFont(ofSize: 11)]
            errorItem.attributedTitle = NSAttributedString(string: error, attributes: attrs)
            menu.addItem(errorItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Record toggle
        let isRecording = appDelegate?.pipelineState == .recording
        let recordTitle = isRecording ? "録音終了 (⌥Space)" : "録音開始 (⌥Space)"
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(toggleRecording), keyEquivalent: "")
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // History
        let historyHeader = NSMenuItem(title: "履歴", action: nil, keyEquivalent: "")
        historyHeader.isEnabled = false
        menu.addItem(historyHeader)

        if let sessions = appDelegate?.sessionHistory.sessions, !sessions.isEmpty {
            for session in sessions.suffix(10).reversed() {
                let preview = String(session.rawText.prefix(40))
                let statusEmoji = session.status == .completed ? "✓" : "⏳"

                // コピー用メニュー項目
                let item = NSMenuItem(title: "\(statusEmoji) \(preview)", action: #selector(copySessionSOAP(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = session.soapText

                // サブメニュー: コピー＆フィードバック
                let submenu = NSMenu()
                let copyItem = NSMenuItem(title: "SOAPをコピー", action: #selector(copySessionSOAP(_:)), keyEquivalent: "")
                copyItem.target = self
                copyItem.representedObject = session.soapText
                submenu.addItem(copyItem)

                let feedbackItem = NSMenuItem(title: "不満点を記録...", action: #selector(openFeedbackForSession(_:)), keyEquivalent: "")
                feedbackItem.target = self
                feedbackItem.representedObject = session.rawText
                submenu.addItem(feedbackItem)

                item.submenu = submenu
                menu.addItem(item)
            }
        } else {
            let noHistory = NSMenuItem(title: "履歴なし", action: nil, keyEquivalent: "")
            noHistory.isEnabled = false
            menu.addItem(noHistory)
        }

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleRecording() {
        appDelegate?.handleHotkeyPress()
    }

    @objc private func copySessionSOAP(_ sender: NSMenuItem) {
        guard let soapText = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(soapText, forType: .string)
    }

    @objc private func openFeedbackForSession(_ sender: NSMenuItem) {
        // 設定画面の進化タブを開く
        appDelegate?.openSettings()
    }

    @objc private func openSettings() {
        appDelegate?.openSettings()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
