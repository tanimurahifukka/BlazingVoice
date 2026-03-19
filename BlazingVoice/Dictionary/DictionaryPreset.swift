import Foundation

enum DictionaryPreset {
    static func loadDefaults() -> [UserDictionary.Entry] {
        guard let url = Bundle.main.url(forResource: "DictionaryPreset", withExtension: "csv") else {
            return builtinDefaults()
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return parseCSV(content)
        } catch {
            return builtinDefaults()
        }
    }

    static func parseCSV(_ content: String) -> [UserDictionary.Entry] {
        let lines = content.components(separatedBy: .newlines)
        var entries: [UserDictionary.Entry] = []

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
            entries.append(UserDictionary.Entry(from: from, to: to))
        }
        return entries
    }

    static func builtinDefaults() -> [UserDictionary.Entry] {
        [
            .init(from: "ひふか", to: "皮膚科"),
            .init(from: "アトピーせいひふえん", to: "アトピー性皮膚炎"),
            .init(from: "じんましん", to: "蕁麻疹"),
            .init(from: "しっしん", to: "湿疹"),
            .init(from: "せっしょくせいひふえん", to: "接触性皮膚炎"),
            .init(from: "たいじょうほうしん", to: "帯状疱疹"),
            .init(from: "にきび", to: "尋常性痤瘡"),
            .init(from: "みずむし", to: "足白癬"),
            .init(from: "いんきんたむし", to: "股部白癬"),
            .init(from: "ヘルペス", to: "単純疱疹"),
            .init(from: "かんせん", to: "乾癬"),
            .init(from: "しろうせいひふえん", to: "脂漏性皮膚炎"),
            .init(from: "えんけいだつもうしょう", to: "円形脱毛症"),
            .init(from: "そうようしょう", to: "掻痒症"),
            .init(from: "ステロイド", to: "ステロイド外用薬"),
            .init(from: "ヒルドイド", to: "ヘパリン類似物質"),
            .init(from: "プロトピック", to: "タクロリムス軟膏"),
            .init(from: "デルモベート", to: "クロベタゾールプロピオン酸エステル"),
            .init(from: "リンデロン", to: "ベタメタゾン"),
            .init(from: "アンテベート", to: "酪酸プロピオン酸ベタメタゾン"),
        ]
    }
}
