import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("ホットキー") {
                HStack {
                    Text("録音開始/停止:")
                    Spacer()
                    Text("⌥ Space")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
                }
                Text("Option + Space で録音を開始/停止します")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("録音") {
                HStack {
                    Text("最大録音時間:")
                    Spacer()
                    Picker("", selection: $settings.maxRecordingDuration) {
                        Text("1分").tag(60.0)
                        Text("3分").tag(180.0)
                        Text("5分").tag(300.0)
                        Text("10分").tag(600.0)
                    }
                    .frame(width: 100)
                }

                Toggle("オンデバイス音声認識を優先", isOn: $settings.useOnDeviceRecognition)
                Text("オンデバイスではネットワーク不要ですが、精度がやや低下する場合があります")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("起動") {
                Toggle("ログイン時に自動起動", isOn: $settings.launchAtLogin)
            }

        }
        .formStyle(.grouped)
        .padding()
    }
}
