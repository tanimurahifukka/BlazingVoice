import AppKit
import Combine

final class StatusBarController {
    enum IconState: String {
        case idle, recording, processing, done, error
    }

    private let statusItem: NSStatusItem
    private let menuController: StatusBarMenu
    private weak var appDelegate: AppDelegate?
    private var animationTimer: Timer?
    private var animationFrame: Int = 0

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menuController = StatusBarMenu(appDelegate: appDelegate)

        if let button = statusItem.button {
            button.image = Self.iconImage(for: .idle)
            button.image?.isTemplate = true
        }
        statusItem.menu = menuController.menu
    }

    func updateState(_ state: IconState) {
        stopAnimation()
        if let button = statusItem.button {
            button.image = Self.iconImage(for: state)
            button.image?.isTemplate = (state == .idle)
        }
        switch state {
        case .recording:
            startAnimation(frames: Self.recordingFrames)
        case .processing:
            startAnimation(frames: Self.processingFrames)
        default:
            break
        }
        refreshMenu()
    }

    func showError(_ message: String) {
        menuController.setErrorMessage(message)
    }

    func refreshMenu() {
        menuController.rebuildMenu()
    }

    // MARK: - Animation

    private func startAnimation(frames: [NSImage]) {
        animationFrame = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.animationFrame = (self.animationFrame + 1) % frames.count
            self.statusItem.button?.image = frames[self.animationFrame]
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Icon Generation

    private static func tintedSymbol(_ symbolName: String, color: NSColor, description: String) -> NSImage {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
        let config = sizeConfig.applying(colorConfig)
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: description)?
            .withSymbolConfiguration(config) ?? NSImage()
    }

    static func iconImage(for state: IconState) -> NSImage {
        switch state {
        case .idle:
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "idle")?
                .withSymbolConfiguration(config) ?? NSImage()
            img.isTemplate = true
            return img
        case .recording:
            return tintedSymbol("record.circle.fill", color: .systemRed, description: "recording")
        case .processing:
            return tintedSymbol("brain", color: .systemBlue, description: "processing")
        case .done:
            return tintedSymbol("checkmark.circle.fill", color: .systemGreen, description: "done")
        case .error:
            return tintedSymbol("exclamationmark.triangle.fill", color: .systemRed, description: "error")
        }
    }

    static var recordingFrames: [NSImage] {
        ["record.circle", "record.circle.fill"].map {
            tintedSymbol($0, color: .systemRed, description: "recording")
        }
    }

    static var processingFrames: [NSImage] {
        ["brain", "brain.head.profile"].map {
            tintedSymbol($0, color: .systemBlue, description: "processing")
        }
    }
}
