import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
            LLMSettingsView()
                .tabItem {
                    Label("LLM", systemImage: "brain")
                }
            DictionarySettingsView()
                .tabItem {
                    Label("辞書", systemImage: "book")
                }
            StorageSettingsView()
                .tabItem {
                    Label("セキュリティ", systemImage: "lock.shield")
                }
        }
        .frame(width: 520, height: 460)
    }
}
