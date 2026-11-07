import Foundation

struct Track: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let short: String
    let grp: String
    let color: String
    let inGrid: Bool
    let sort: Int
}

struct Item: Codable, Identifiable, Hashable {
    let id: String
    let day: String
    let trackId: String?
    let kind: String          // appt / routine / special
    var title: String
    let label: String?
    let num: Int?
    let topic: String?
    let details: String?
    let atTime: String?
    let remindMin: Int
    var status: String        // planned / done / skipped
    var note: String?
    let sort: Int

    var isDone: Bool { status == "done" }
    var gridLabel: String {
        if let l = label, !l.isEmpty { return l }
        if let n = num { return String(n) }
        return "•"
    }
}

struct FlexTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let trackId: String?
    let everyDays: Int
    let effort: String
    var lastDone: String?
    let note: String?
    let sort: Int

    func since(_ today: String) -> Int? {
        guard let l = lastDone else { return nil }
        return DateKit.diff(l, today)
    }

    func score(_ today: String) -> Double {
        guard let s = since(today) else { return 99 }
        return Double(s) / Double(max(everyDays, 1))
    }

    func isDone(_ today: String) -> Bool { lastDone == today }

    func why(_ today: String) -> String {
        var s = "كل \(everyDays) " + (everyDays == 1 ? "يوم" : "أيام")
        if let d = since(today) {
            if d == 0 { s += " · خلصتها اليوم" }
            else if d > everyDays { s += " · متأخرة \(d - everyDays)" }
            else if d == everyDays { s += " · وقتها اليوم" }
            else { s += " · باقي \(everyDays - d)" }
        } else {
            s += " · ما بدأت"
        }
        return s
    }

    func lastLabel(_ today: String) -> String {
        guard let d = since(today) else { return "—" }
        switch d {
        case 0: return "اليوم"
        case 1: return "أمس"
        case 2: return "قبل يومين"
        default: return "قبل \(d) أيام"
        }
    }
}

struct DayInfo: Codable, Hashable {
    let day: String
    let title: String?
    let claudeNote: String?
    var myNote: String?
    var finished: Bool
}

struct WeekInfo: Codable, Hashable {
    let weekStart: String
    let summary: String?
}

struct FlexLog: Codable, Hashable {
    let taskId: String
    let day: String
}

struct Feed: Codable {
    let today: String
    var tracks: [Track]
    var items: [Item]
    var flex: [FlexTask]
    var flexLog: [FlexLog]
    var days: [DayInfo]
    var weeks: [WeekInfo]
    var lastDone: [String: String]

    func items(on day: String, kinds: Set<String>) -> [Item] {
        items.filter { $0.day == day && kinds.contains($0.kind) }
            .sorted { a, b in
                switch (a.atTime, b.atTime) {
                case let (x?, y?): return x == y ? a.sort < b.sort : x < y
                case (nil, _?): return false
                case (_?, nil): return true
                default: return a.sort < b.sort
                }
            }
    }

    func track(_ id: String?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    func day(_ d: String) -> DayInfo? { days.first { $0.day == d } }

    /// أقرب موعد جاي اليوم (له وقت ولسه ما خلص)، وإذا ما في وقت يرجع أول موعد ما خلص.
    func nextUp(now: Date = Date()) -> Item? {
        let today = DateKit.key(now)
        let list = items(on: today, kinds: ["appt", "special"]).filter { !$0.isDone }
        let timed = list.filter { it in
            guard let t = it.atTime, let d = DateKit.fire(day: today, time: t) else { return false }
            return d.addingTimeInterval(30 * 60) > now
        }
        return timed.first ?? list.first { $0.atTime == nil }
    }

    func sortedFlex(_ today: String) -> [FlexTask] {
        flex.sorted { a, b in
            let ad = a.isDone(today), bd = b.isDone(today)
            if ad != bd { return !ad }
            let sa = a.score(today), sb = b.score(today)
            return sa == sb ? a.sort < b.sort : sa > sb
        }
    }
}
