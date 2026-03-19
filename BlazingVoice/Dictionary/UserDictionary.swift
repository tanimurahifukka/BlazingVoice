import Foundation
import SwiftUI

final class UserDictionary: ObservableObject {
    struct Entry: Identifiable, Codable, Equatable {
        var id: UUID
        var from: String
        var to: String
        var isEnabled: Bool

        init(id: UUID = UUID(), from: String, to: String, isEnabled: Bool = true) {
            self.id = id
            self.from = from
            self.to = to
            self.isEnabled = isEnabled
        }
    }

    @Published var entries: [Entry] = []

    private let storageKey = "userDictionaryEntries"

    init() {
        loadEntries()
        if entries.isEmpty {
            loadPreset()
        }
    }

    // MARK: - Text Replacement

    func applyReplacements(to text: String) -> String {
        var result = text
        for entry in entries where entry.isEnabled && !entry.from.isEmpty {
            result = result.replacingOccurrences(of: entry.from, with: entry.to)
        }
        return result
    }

    // MARK: - CRUD

    func addEntry(from: String, to: String) {
        let entry = Entry(from: from, to: to)
        entries.append(entry)
        saveEntries()
    }

    func removeEntry(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        saveEntries()
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    func updateEntry(_ entry: Entry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }

    // MARK: - Preset

    func loadPreset() {
        let presetEntries = DictionaryPreset.loadDefaults()
        entries.append(contentsOf: presetEntries)
        saveEntries()
    }

    // MARK: - CSV Import/Export

    func importCSV(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var newEntries: [Entry] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let columns = trimmed.components(separatedBy: ",")
            guard columns.count >= 2 else { continue }
            let from = columns[0].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let to = columns[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !from.isEmpty else { continue }
            newEntries.append(Entry(from: from, to: to))
        }

        entries.append(contentsOf: newEntries)
        saveEntries()
    }

    func exportCSV(to url: URL) throws {
        var csv = "# BlazingVoice Dictionary Export\n"
        csv += "# from,to\n"
        for entry in entries {
            let from = entry.from.replacingOccurrences(of: ",", with: "，")
            let to = entry.to.replacingOccurrences(of: ",", with: "，")
            csv += "\(from),\(to)\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Persistence

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }
}
