import Foundation

enum DateKit {
    static let tz = TimeZone(identifier: "Asia/Kuwait") ?? .current

    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        c.firstWeekday = 7
        return c
    }()

    private static let keyFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let hijriFmt: DateFormatter = {
        let f = DateFormatter()
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = tz
        f.calendar = c
        f.timeZone = tz
        f.locale = Locale(identifier: "ar@numbers=latn")
        f.dateFormat = "d MMMM"
        return f
    }()

    private static let hijriDayFmt: DateFormatter = {
        let f = DateFormatter()
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = tz
        f.calendar = c
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d"
        return f
    }()

    static let dayNames = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    static let dayShort = ["أحد", "اثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة", "سبت"]
    static let months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]

    static func key(_ d: Date) -> String { keyFmt.string(from: d) }
    static func date(_ k: String) -> Date? { keyFmt.date(from: k) }
    static var todayKey: String { key(Date()) }

    static func add(_ days: Int, to k: String) -> String {
        guard let d = date(k), let n = cal.date(byAdding: .day, value: days, to: d) else { return k }
        return key(n)
    }

    /// b - a بالأيام
    static func diff(_ a: String, _ b: String) -> Int {
        guard let x = date(a), let y = date(b) else { return 0 }
        return cal.dateComponents([.day], from: x, to: y).day ?? 0
    }

    /// 1 = الأحد ... 7 = السبت
    static func weekday(_ k: String) -> Int {
        guard let d = date(k) else { return 1 }
        return cal.component(.weekday, from: d)
    }

    static func dayName(_ k: String) -> String { dayNames[weekday(k) - 1] }
    static func dayShortName(_ k: String) -> String { dayShort[weekday(k) - 1] }

    static func dayNum(_ k: String) -> Int {
        guard let d = date(k) else { return 0 }
        return cal.component(.day, from: d)
    }

    static func monthName(_ k: String) -> String {
        guard let d = date(k) else { return "" }
        return months[cal.component(.month, from: d) - 1]
    }

    /// أول الأسبوع = السبت
    static func weekStart(_ k: String) -> String {
        let back = weekday(k) % 7
        return add(-back, to: k)
    }

    /// أوائل الشهور حسب تقويم مكتب السيد السيستاني لعام 1448 (أفق النجف).
    /// اليوم الأول = اليوم اللي بعد ليلة الهلال.
    static let sistani: [(start: String, month: String)] = [
        ("2026-06-17", "محرم"), ("2026-07-16", "صفر"), ("2026-08-15", "ربيع الأول"),
        ("2026-09-13", "ربيع الآخر"), ("2026-10-13", "جمادى الأولى"), ("2026-11-12", "جمادى الآخرة"),
        ("2026-12-11", "رجب"), ("2027-01-10", "شعبان"), ("2027-02-09", "رمضان"),
        ("2027-03-10", "شوال"), ("2027-04-09", "ذو القعدة"), ("2027-05-08", "ذو الحجة"),
    ]

    /// (اليوم، الشهر) من جدول السيستاني، وإذا برا الجدول nil
    static func sistaniDay(_ k: String) -> (day: Int, month: String)? {
        guard let i = sistani.lastIndex(where: { $0.start <= k }) else { return nil }
        let n = diff(sistani[i].start, k) + 1
        guard n <= 30 else { return nil }
        return (n, sistani[i].month)
    }

    static func hijri(_ k: String) -> String {
        if let s = sistaniDay(k) { return "\(s.day) \(s.month)" }
        guard let d = date(k)?.addingTimeInterval(12 * 3600) else { return "" }
        return hijriFmt.string(from: d)
    }

    static func hijriDay(_ k: String) -> String {
        if let s = sistaniDay(k) { return "\(s.day)" }
        guard let d = date(k)?.addingTimeInterval(12 * 3600) else { return "" }
        return hijriDayFmt.string(from: d)
    }

    static func long(_ k: String) -> String {
        "\(dayName(k)) \(dayNum(k)) \(monthName(k))"
    }

    static func fire(day: String, time: String) -> Date? {
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count >= 2, let d = date(day) else { return nil }
        return cal.date(byAdding: .minute, value: p[0] * 60 + p[1], to: d)
    }

    static func timeLabel(_ time: String?) -> String? {
        guard let time else { return nil }
        let p = time.split(separator: ":").compactMap { Int($0) }
        guard p.count >= 2 else { return nil }
        let h = p[0], m = p[1]
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d", h12, m) + (h < 12 ? " ص" : " م")
    }

    static func countdown(from today: String, to day: String) -> String {
        let n = diff(today, day)
        switch n {
        case 0: return "اليوم"
        case 1: return "باجر"
        case 2: return "بعد يومين"
        case 3...10: return "بعد \(n) أيام"
        default: return "بعد \(n) يوم"
        }
    }
}
