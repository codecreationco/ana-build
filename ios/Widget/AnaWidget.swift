import WidgetKit
import SwiftUI

// الويدجت تقرا نسخة اليوم اللي يكتبها التطبيق بالمجلد المشترك (WidgetSnap).

struct DayEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnap?
}

private func minutes(_ d: Date) -> Int {
    let c = DateKit.cal.dateComponents([.hour, .minute], from: d)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date(), snap: Self.sample) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date(), snap: WidgetSnap.load() ?? Self.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSnap.load()
        var entries = [DayEntry(date: now, snap: snap)]
        if let s = snap, let start = DateKit.date(s.day) {
            // نحدث العرض بعد كل موعد بساعة (يطلع من «الجاي»)، وعند كل صلاة
            var marks = Set<Int>()
            for r in s.rows { if let t = r.time { marks.insert(t + 60) } }
            for p in s.prayers { marks.insert(p.min + 1) }
            for m in marks.sorted() {
                let at = start.addingTimeInterval(TimeInterval(m * 60))
                if at > now { entries.append(DayEntry(date: at, snap: s)) }
            }
            let midnight = start.addingTimeInterval(24 * 3600 + 60)
            if midnight > now { entries.append(DayEntry(date: midnight, snap: s)) }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3 * 3600))))
    }

    static let sample = WidgetSnap(
        day: DateKit.todayKey,
        rows: [
            .init(id: "a", time: 1065, timeText: "5:45 م", title: "حضور درس الأصول", sub: "درس 74", done: false),
            .init(id: "b", time: nil, title: "تقرير المتاجر", sub: "درس 141", done: false),
            .init(id: "c", time: nil, title: "قراءة نظرية المعرفة", done: false),
            .init(id: "d", time: 400, timeText: "قبل الطلعة", title: "قبل لا أطلع", done: true),
        ],
        prayers: [.init(id: "maghrib", name: "المغرب", min: 1009)],
        prayersTomorrow: [.init(id: "fajr", name: "الفجر", min: 290)],
        prayed: [])
}

// MARK: - مشترك

private extension WidgetSnap.Row {
    /// الوقت القصير اللي يطلع جنب العنوان
    var label: String {
        if let t = timeText, !t.contains(":") { return t }
        if let m = time { return WidgetSnap.clock(m) }
        return "أي وقت"
    }
}

struct AnaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        Group {
            if let s = entry.snap {
                // بعد نص الليل وقبل لا ينفتح التطبيق: نسخة أمس، ما نعرض مهامها
                let fresh = s.day == DateKit.key(entry.date)
                let now = minutes(entry.date)
                switch family {
                case .accessoryRectangular: RectView(snap: s, now: now, fresh: fresh)
                case .accessoryCircular: ProgressCircle(snap: s, fresh: fresh)
                case .accessoryInline: InlineView(snap: s, now: now, fresh: fresh)
                case .systemSmall: SmallView(snap: s, now: now, fresh: fresh)
                default: ListView(snap: s, now: now, fresh: fresh, limit: family == .systemLarge ? 9 : 4)
                }
            } else {
                Text("افتح التطبيق مرة")
                    .font(T.f(13))
                    .foregroundStyle(family.isAccessory ? Color.primary : T.muted)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ana://today"))
        .containerBackground(for: .widget) { family.isAccessory ? Color.clear : T.bg }
    }
}

private extension WidgetFamily {
    var isAccessory: Bool { self == .accessoryRectangular || self == .accessoryCircular || self == .accessoryInline }
}

// MARK: - شاشة القفل

struct RectView: View {
    let snap: WidgetSnap
    let now: Int
    let fresh: Bool

    var body: some View {
        let up = fresh ? Array(snap.upcoming(now).prefix(3)) : []
        VStack(alignment: .leading, spacing: 1) {
            if !fresh {
                Text("يوم جديد").font(T.f(14, .bold))
                Text("افتح التطبيق عشان يتحدث").font(T.f(12)).opacity(0.7)
            } else if up.isEmpty {
                Text("خلصت اليوم").font(T.f(15, .bold))
                Text(verbatim: "\(snap.doneCount) من \(snap.rows.count)").font(T.f(12)).opacity(0.7)
            } else {
                ForEach(Array(up.enumerated()), id: \.element.id) { i, r in
                    HStack(spacing: 6) {
                        Text(verbatim: r.label)
                            .font(T.f(11, .medium))
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: 46, alignment: .leading)
                            .opacity(0.65)
                        Text(verbatim: r.title)
                            .font(T.f(i == 0 ? 14 : 13, i == 0 ? .bold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .widgetAccentable(i == 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ProgressCircle: View {
    let snap: WidgetSnap
    let fresh: Bool

    var body: some View {
        let total = max(snap.rows.count, 1)
        let done = fresh ? snap.doneCount : 0
        Gauge(value: Double(done), in: 0...Double(total)) {
            Text("اليوم")
        } currentValueLabel: {
            Text(verbatim: fresh ? "\(done)/\(snap.rows.count)" : "—")
                .font(T.f(13, .bold))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct InlineView: View {
    let snap: WidgetSnap
    let now: Int
    let fresh: Bool

    var body: some View {
        if fresh, let n = snap.upcoming(now).first {
            Text(verbatim: n.time != nil ? "\(n.title) · \(n.label)" : n.title)
        } else {
            Text(fresh ? "خلصت اليوم" : "افتح التطبيق")
        }
    }
}

// الصلاة الجاية بدائرة
struct PrayerCircle: View {
    let entry: DayEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let s = entry.snap, let p = s.nextPrayer(minutes(entry.date))?.0 {
                VStack(spacing: 0) {
                    Text(verbatim: p.name).font(T.f(10, .medium)).opacity(0.75)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(verbatim: WidgetSnap.clock(p.min)).font(T.f(15, .bold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .widgetAccentable()
                }
                .padding(.horizontal, 4)
            } else {
                Image(systemName: "moon")
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ana://today"))
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - الشاشة الرئيسية

struct SmallView: View {
    let snap: WidgetSnap
    let now: Int
    let fresh: Bool

    var body: some View {
        let n = fresh ? snap.upcoming(now).first : nil
        VStack(alignment: .leading, spacing: 4) {
            Text("الجاي").font(T.f(11, .semibold)).foregroundStyle(T.accent)
            if let n {
                Text(verbatim: n.title).font(T.f(15, .bold)).lineLimit(2).minimumScaleFactor(0.8)
                Text(verbatim: n.label).font(T.f(12, .medium)).foregroundStyle(T.muted)
                if let s = n.sub { Text(verbatim: s).font(T.f(11)).foregroundStyle(T.muted).lineLimit(2) }
            } else {
                Text(fresh ? "خلصت اليوم" : "افتح التطبيق").font(T.f(14, .bold))
            }
            Spacer(minLength: 0)
            if fresh {
                Text(verbatim: "خلصت \(snap.doneCount) من \(snap.rows.count)")
                    .font(T.f(11)).foregroundStyle(T.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(T.ink)
    }
}

struct ListView: View {
    let snap: WidgetSnap
    let now: Int
    let fresh: Bool
    let limit: Int

    var body: some View {
        let next = fresh ? snap.upcoming(now).first?.id : nil
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: "\(DateKit.dayName(snap.day)) \(DateKit.dayNum(snap.day))")
                    .font(T.f(12, .semibold)).foregroundStyle(T.accent)
                Spacer()
                if fresh {
                    Text(verbatim: "\(snap.doneCount) من \(snap.rows.count)").font(T.f(11)).foregroundStyle(T.muted)
                }
            }
            if !fresh {
                Text("افتح التطبيق عشان يتحدث اليوم").font(T.f(13)).foregroundStyle(T.muted)
            } else {
                // اللي ما خلص أول، واللي خلص بآخر القائمة
                let rows = (snap.rows.filter { !$0.done } + snap.rows.filter(\.done)).prefix(limit)
                ForEach(Array(rows), id: \.id) { r in
                    HStack(spacing: 8) {
                        Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(r.done ? T.muted : (r.id == next ? T.accent : T.dim))
                        Text(verbatim: r.title)
                            .font(T.f(13, r.id == next ? .bold : .medium))
                            .foregroundStyle(r.done ? T.muted : T.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(verbatim: r.label).font(T.f(11)).foregroundStyle(T.muted).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: -

struct AnaTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AnaToday", provider: Provider()) { entry in
            AnaWidgetView(entry: entry)
        }
        .configurationDisplayName("اليوم")
        .description("شنو عندك اليوم وشنو الجاي")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline,
                            .systemSmall, .systemMedium, .systemLarge])
    }
}

struct AnaPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AnaPrayer", provider: Provider()) { entry in
            PrayerCircle(entry: entry)
        }
        .configurationDisplayName("الصلاة الجاية")
        .description("وقت الصلاة الجاية")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct AnaWidgets: WidgetBundle {
    var body: some Widget {
        AnaTodayWidget()
        AnaPrayerWidget()
    }
}
