import WidgetKit
import SwiftUI
import AppIntents

struct DayEntry: TimelineEntry {
    let date: Date
    let feed: Feed?
    let stale: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), feed: nil, stale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date(), feed: FeedCache.load(), stale: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        Task {
            let today = DateKit.todayKey
            var feed: Feed?
            var stale = false
            if !API.isConfigured {
                if let c = FeedCache.load(), c.today == today { feed = c } else {
                    feed = Sample.feed()
                    FeedCache.save(feed!)
                }
            } else { do {
                let f = try await API.feed(from: DateKit.add(-1, to: today), to: DateKit.add(1, to: today))
                FeedCache.save(f)
                feed = f
            } catch {
                feed = FeedCache.load()
                stale = true
            } }
            let now = Date()
            var entries = [DayEntry(date: now, feed: feed, stale: stale)]
            if let f = feed {
                // نحدّث العرض بعد كل موعد عشان «الجاي» يتغير بروحه
                for it in f.items where it.day == today {
                    if let t = it.atTime, let d = DateKit.fire(day: today, time: t) {
                        let at = d.addingTimeInterval(30 * 60 + 5)
                        if at > now { entries.append(DayEntry(date: at, feed: f, stale: stale)) }
                    }
                }
                if let midnight = DateKit.date(DateKit.add(1, to: today)), midnight > now {
                    entries.append(DayEntry(date: midnight.addingTimeInterval(60), feed: f, stale: stale))
                }
            }
            let refresh = now.addingTimeInterval(stale ? 15 * 60 : 40 * 60)
            completion(Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(refresh)))
        }
    }
}

struct AnaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        Group {
            if let f = entry.feed {
                switch family {
                case .systemSmall: SmallView(feed: f, now: entry.date)
                case .systemMedium: MediumView(feed: f, now: entry.date)
                case .systemLarge: LargeView(feed: f, now: entry.date)
                case .accessoryInline: InlineView(feed: f, now: entry.date)
                default: RectView(feed: f, now: entry.date)
                }
            } else {
                Text("افتح التطبيق مرة وحدة عشان تتعبى الويدجت").font(T.f(13)).foregroundStyle(T.muted)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "ana://today"))
        .containerBackground(for: .widget) { T.bg }
    }
}

// MARK: - أجزاء مشتركة

private func dayKey(_ d: Date) -> String { DateKit.key(d) }

private struct TimeTag: View {
    let item: Item
    var body: some View {
        Text(DateKit.timeLabel(item.atTime) ?? "")
            .font(T.f(11, .medium))
            .foregroundStyle(T.muted)
    }
}

private struct CheckButton: View {
    let item: Item
    var body: some View {
        Button(intent: ToggleItemIntent(itemId: item.id, done: !item.isDone)) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.isDone ? T.good : T.muted)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - صغير: الجاي

struct SmallView: View {
    let feed: Feed
    let now: Date

    var body: some View {
        let today = dayKey(now)
        let next = feed.nextUp(now: now)
        let routine = feed.items(on: today, kinds: ["routine"])
        VStack(alignment: .leading, spacing: 4) {
            Text(next == nil ? "اليوم" : "الجاي")
                .font(T.f(11, .semibold)).foregroundStyle(T.accent)
            if let n = next {
                Text(n.title).font(T.f(15, .bold)).lineLimit(2).minimumScaleFactor(0.8)
                if let t = DateKit.timeLabel(n.atTime) { Text(t).font(T.f(13, .medium)) }
                if let tp = n.topic, !tp.isEmpty {
                    Text(tp).font(T.f(11)).foregroundStyle(T.muted).lineLimit(2)
                }
            } else {
                Text("خلصت مواعيد اليوم ✓").font(T.f(14, .bold)).foregroundStyle(T.good)
            }
            Spacer(minLength: 0)
            if !routine.isEmpty {
                let d = routine.filter(\.isDone).count
                HStack(spacing: 4) {
                    Text("الروتين").font(T.f(11)).foregroundStyle(T.muted)
                    Spacer(minLength: 0)
                    Text("\(d)/\(routine.count)").font(T.f(12, .semibold))
                        .foregroundStyle(d == routine.count ? T.good : T.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(T.ink)
    }
}

// MARK: - متوسط: مواعيد اليوم + الروتين بأزرار

struct MediumView: View {
    let feed: Feed
    let now: Date

    var body: some View {
        let today = dayKey(now)
        let tasks = feed.items(on: today, kinds: ["appt", "special"])
        let routine = feed.items(on: today, kinds: ["routine"])
        let next = feed.nextUp(now: now)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(DateKit.dayName(today)) \(DateKit.dayNum(today))")
                    .font(T.f(12, .semibold)).foregroundStyle(T.accent)
                if tasks.isEmpty {
                    Text("ما في مواعيد").font(T.f(13)).foregroundStyle(T.muted)
                }
                ForEach(tasks.prefix(4)) { it in
                    HStack(spacing: 6) {
                        CheckButton(item: it)
                        Text(it.title).font(T.f(13, it.id == next?.id ? .bold : .medium))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .strikethrough(it.isDone, color: T.muted)
                            .foregroundStyle(it.isDone ? T.muted : T.ink)
                        Spacer(minLength: 0)
                        TimeTag(item: it)
                    }
                }
                if tasks.count > 4 {
                    Text("و\(tasks.count - 4) غيرها").font(T.f(11)).foregroundStyle(T.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if !routine.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("الروتين").font(T.f(12, .semibold)).foregroundStyle(T.muted)
                    ForEach(routine.prefix(4)) { it in
                        HStack(spacing: 5) {
                            CheckButton(item: it)
                            Text(it.title).font(T.f(12, .medium)).lineLimit(1)
                                .foregroundStyle(it.isDone ? T.muted : T.ink)
                        }
                    }
                }
                .frame(width: 112, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(T.ink)
    }
}

// MARK: - كبير: اليوم كامل

struct LargeView: View {
    let feed: Feed
    let now: Date

    var body: some View {
        let today = dayKey(now)
        let tasks = feed.items(on: today, kinds: ["appt", "special"])
        let routine = feed.items(on: today, kinds: ["routine"])
        let flex = feed.sortedFlex(today).filter { !$0.isDone(today) }.prefix(2)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(DateKit.long(today))").font(T.f(14, .bold))
                Spacer()
                Text(DateKit.hijri(today)).font(T.f(11)).foregroundStyle(T.muted)
            }
            if let n = feed.day(today)?.claudeNote, !n.isEmpty {
                Text(n).font(T.f(11)).foregroundStyle(T.muted).lineLimit(2)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) { Rectangle().fill(T.pin).frame(width: 2) }
            }
            ForEach(tasks.prefix(5)) { it in
                HStack(spacing: 6) {
                    CheckButton(item: it)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(it.title).font(T.f(13, .semibold)).lineLimit(1)
                            .foregroundStyle(it.isDone ? T.muted : T.ink)
                        if let tp = it.topic, !tp.isEmpty {
                            Text(tp).font(T.f(11)).foregroundStyle(T.accent).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    TimeTag(item: it)
                }
            }
            if !routine.isEmpty {
                Divider().overlay(T.line)
                HStack(spacing: 10) {
                    ForEach(routine.prefix(4)) { it in
                        HStack(spacing: 3) {
                            CheckButton(item: it)
                            Text(it.title).font(T.f(11, .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            if !flex.isEmpty {
                Divider().overlay(T.line)
                Text("المرنة: " + flex.map(\.title).joined(separator: " · "))
                    .font(T.f(11)).foregroundStyle(T.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(T.ink)
    }
}

// MARK: - شاشة القفل

struct RectView: View {
    let feed: Feed
    let now: Date

    var body: some View {
        if let n = feed.nextUp(now: now) {
            VStack(alignment: .leading, spacing: 0) {
                Text(DateKit.timeLabel(n.atTime) ?? "الجاي").font(.caption2).widgetAccentable()
                Text(n.title).font(.headline).lineLimit(1)
                if let tp = n.topic { Text(tp).font(.caption).lineLimit(1) }
            }
        } else {
            Text("خلصت مواعيد اليوم ✓").font(.headline)
        }
    }
}

struct InlineView: View {
    let feed: Feed
    let now: Date

    var body: some View {
        if let n = feed.nextUp(now: now) {
            Text("\(n.title) \(DateKit.timeLabel(n.atTime) ?? "")")
        } else {
            Text("خلصت مواعيد اليوم")
        }
    }
}

struct AnaTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AnaToday", provider: Provider()) { entry in
            AnaWidgetView(entry: entry)
        }
        .configurationDisplayName("أنا")
        .description("شنو عندك اليوم وشنو الجاي")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct AnaWidgets: WidgetBundle {
    var body: some Widget {
        AnaTodayWidget()
    }
}
