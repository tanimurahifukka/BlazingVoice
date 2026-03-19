import AppKit
import ApplicationServices

/// アクセシビリティ権限チェック（グローバルホットキー動作に必要）
enum AccessibilityHelper {

    static func isEnabled() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
