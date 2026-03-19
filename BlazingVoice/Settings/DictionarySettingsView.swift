import SwiftUI

struct DictionarySettingsView: View {
    @StateObject private var dictionary = UserDictionary()
    @State private var newFrom = ""
    @State private var newTo = ""
    @State private var showImporter = false
    @State private var showExporter = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("ユーザー辞書 (\(dictionary.entries.count)件)")
                    .font(.headline)
                Spacer()
                Button(action: { showImporter = true }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("CSVインポート")
                Button(action: { showExporter = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("CSVエクスポート")
            }
            .padding()

            Divider()

            // Add new entry
            HStack {
                TextField("変換前", text: $newFrom)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                TextField("変換後", text: $newTo)
                    .textFieldStyle(.roundedBorder)
                Button("追加") {
                    guard !newFrom.isEmpty else { return }
                    dictionary.addEntry(from: newFrom, to: newTo)
                    newFrom = ""
                    newTo = ""
                }
                .disabled(newFrom.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Entry list
            List {
                ForEach(dictionary.entries) { entry in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { newValue in
                                var updated = entry
                                updated.isEnabled = newValue
                                dictionary.updateEntry(updated)
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        Text(entry.from)
                            .frame(minWidth: 100, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(entry.to)
                            .frame(minWidth: 100, alignment: .leading)
                        Spacer()
                        Button(action: {
                            dictionary.removeEntry(id: entry.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(minHeight: 350)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText]) { result in
            if case .success(let url) = result {
                try? dictionary.importCSV(from: url)
            }
        }
        .fileExporter(isPresented: $showExporter, document: CSVDocument(entries: dictionary.entries), contentType: .commaSeparatedText, defaultFilename: "BlazingVoice_Dictionary.csv") { _ in }
    }
}

// MARK: - CSV Document for Export

import UniformTypeIdentifiers

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let entries: [UserDictionary.Entry]

    init(entries: [UserDictionary.Entry]) {
        self.entries = entries
    }

    init(configuration: ReadConfiguration) throws {
        entries = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var csv = "# BlazingVoice Dictionary Export\n# from,to\n"
        for entry in entries {
            let from = entry.from.replacingOccurrences(of: ",", with: "，")
            let to = entry.to.replacingOccurrences(of: ",", with: "，")
            csv += "\(from),\(to)\n"
        }
        return FileWrapper(regularFileWithContents: csv.data(using: .utf8) ?? Data())
    }
}
