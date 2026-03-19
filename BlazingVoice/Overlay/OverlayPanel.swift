import AppKit
import SwiftUI

/// 画面中央に半透明のHUD通知を表示するパネル
final class OverlayPanel {
    private var window: NSPanel?
    private var hideTask: DispatchWorkItem?

    /// 画面中央にメッセージを表示し、一定時間後に自動で消える
    func show(_ message: String, symbol: String = "doc.on.clipboard.fill", duration: TimeInterval = 2.5) {
        hideTask?.cancel()
        dismiss()

        let hosting = NSHostingView(rootView: OverlayContent(message: message, symbol: symbol))
        hosting.frame = NSRect(x: 0, y: 0, width: 260, height: 140)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.contentView = hosting

        // メインスクリーン中央に配置
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - hosting.frame.width / 2
            let y = screenFrame.midY - hosting.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // フェードイン
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }

        self.window = panel

        // 自動非表示
        let task = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    func dismiss() {
        guard let panel = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.window = nil
        })
    }
}

// MARK: - SwiftUI View

private struct OverlayContent: View {
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(24)
        .frame(width: 260, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
