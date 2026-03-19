import AppKit

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private let settings: AppSettings
    private let action: () -> Void
    private var rightCmdWasDown = false

    // Right Command key code
    private static let rightCommandKeyCode: UInt16 = 54

    init(settings: AppSettings, action: @escaping () -> Void) {
        self.settings = settings
        self.action = action
        setupMonitors()
    }

    deinit {
        removeMonitors()
    }

    private func setupMonitors() {
        removeMonitors()

        // Monitor flagsChanged for right Command key
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        // Also keep keyDown monitors for regular hotkey combinations
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event) == true {
                self?.action()
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        for monitor in [globalMonitor, localMonitor, globalFlagsMonitor, localFlagsMonitor] {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
        globalMonitor = nil
        localMonitor = nil
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == HotkeyManager.rightCommandKeyCode else { return }

        let isDown = event.modifierFlags.contains(.command)

        if isDown && !rightCmdWasDown {
            rightCmdWasDown = true
        } else if !isDown && rightCmdWasDown {
            rightCmdWasDown = false
            action()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if matchesHotkey(event) {
            action()
        }
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let expectedModifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifierFlags))
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == UInt16(settings.hotkeyKeyCode) && relevantFlags == expectedModifiers
    }
}
