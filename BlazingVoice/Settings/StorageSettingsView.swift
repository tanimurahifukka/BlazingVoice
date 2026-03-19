import SwiftUI

struct StorageSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("データ保存") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("セキュアモード: 有効")
                            .font(.headline)
                    }

                    Text("BlazingVoiceはすべてのデータをメモリ内に保持し、ディスクに医療データを保存しません。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Label("音声データ: メモリ内のみ（録音後自動削除）", systemImage: "waveform")
                        Label("SOAP記録: メモリ内のみ（直近10件）", systemImage: "doc.text")
                        Label("辞書データ: UserDefaults（個人情報なし）", systemImage: "book")
                        Label("設定データ: UserDefaults", systemImage: "gear")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Section("セッション履歴") {
                Text("アプリ終了時にすべてのセッション履歴が自動的に削除されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
