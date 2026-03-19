import SwiftUI

@main
struct BlazingVoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate)
        }
        Window("セットアップ", id: "setup-wizard") {
            SetupWizardView()
                .environmentObject(appDelegate.settings)
                .frame(width: 520, height: 480)
        }
        .windowResizability(.contentSize)
    }
}
