import Foundation

/// اللي تقراه الويدجت: نسخة صغيرة من اليوم يكتبها التطبيق بالمجلد المشترك.
struct WidgetSnap: Codable, Equatable {
    struct Row: Codable, Equatable {
        var id: String
        var time: Int?          // دقايق من نص الليل
        var timeText: String?
        var title: String
        var sub: String?
        var done: Bool
    }
    struct Pray: Codable, Equatable {
        var id: String
        var name: String
        var min: Int
    }

    var day: String
    var rows: [Row]
    var prayers: [Pray]
    var prayersTomorrow: [Pray]
    var prayed: [String]

    var doneCount: Int { rows.filter(\.done).count }

    /// الجاي: اللي له وقت وما خلص (لين ساعة بعد وقته)، وبعدها اللي بأي وقت
    func upcoming(_ now: Int) -> [Row] {
        let timed = rows.filter { !$0.done && $0.time != nil && ($0.time ?? 0) + 60 > now }
        let any = rows.filter { !$0.done && $0.time == nil }
        return timed + any
    }

    /// الصلاة الجاية: اللي ما دخل وقتها، أو اللي دخلت وما صليتها وللحين بوقتها
    func nextPrayer(_ now: Int) -> (Pray, tomorrow: Bool)? {
        if let p = prayers.first(where: { $0.min > now }) { return (p, false) }
        if let p = prayersTomorrow.first { return (p, true) }
        return nil
    }

    // MARK: - المجلد المشترك بين التطبيق والويدجت

    static let fallbackGroup = "group.com.ana.app"

    /// اسم المجموعة من ملف التوقيع (Sideloadly ممكن يغيره)، وإلا الاسم الأصلي
    static var group: String {
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url),
           let start = data.range(of: Data("<?xml".utf8)),
           let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) {
            let plist = data.subdata(in: start.lowerBound..<end.upperBound)
            if let o = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
               let ent = o["Entitlements"] as? [String: Any],
               let groups = ent["com.apple.security.application-groups"] as? [String],
               let g = groups.first(where: { $0.contains("ana") }) ?? groups.first {
                return g
            }
        }
        return fallbackGroup
    }

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("widget-today.json")
    }

    static func load() -> WidgetSnap? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnap.self, from: data)
    }

    /// يرجع true إذا تغير شي وانكتب
    @discardableResult
    static func save(_ s: WidgetSnap) -> Bool {
        guard let url else { return false }
        if load() == s { return false }
        guard let data = try? JSONEncoder().encode(s) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func clock(_ m: Int, suffix: Bool = false) -> String {
        let v = ((m % 1440) + 1440) % 1440
        let h = v / 60, h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d", h12, v % 60) + (suffix ? (h < 12 ? " ص" : " م") : "")
    }
}
