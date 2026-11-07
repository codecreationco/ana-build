import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class Store: ObservableObject {
    @Published var feed: Feed?
    @Published var syncing = false
    @Published var offline = false
    @Published var message: String?
    @Published var selDay: String = DateKit.todayKey

    init() {
        feed = FeedCache.load() ?? (API.isConfigured ? nil : Sample.feed())
    }

    var isDemo: Bool { !API.isConfigured }

    var today: String { DateKit.todayKey }

    nonisolated static func rangeFrom() -> String {
        DateKit.add(-7, to: DateKit.weekStart(DateKit.todayKey))
    }

    nonisolated static func rangeTo() -> String {
        DateKit.add(48, to: DateKit.weekStart(DateKit.todayKey))
    }

    func load() async {
        if syncing { return }
        if isDemo {
            if feed == nil || feed?.today != today { feed = Sample.feed() }
            if let f = feed {
                FeedCache.save(f)
                await Notifier.schedule(feed: f)
            }
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        syncing = true
        defer { syncing = false }
        do {
            let f = try await API.feed(from: Self.rangeFrom(), to: Self.rangeTo())
            feed = f
            offline = false
            FeedCache.save(f)
            await Notifier.schedule(feed: f)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            offline = true
        }
    }

    // MARK: - قراءة

    var weekSummary: String? {
        let ws = DateKit.weekStart(selDay)
        return feed?.weeks.first { $0.weekStart == ws }?.summary
    }

    func lastDone(track: String?, before day: String) -> String? {
        guard let track, let f = feed else { return nil }
        let inRange = f.items
            .filter { $0.trackId == track && $0.isDone && $0.day < day }
            .max { $0.day < $1.day }
        if let it = inRange {
            let d = DateKit.diff(it.day, day)
            let when = d == 1 ? "أمس" : (d == 0 ? "اليوم" : DateKit.dayName(it.day))
            let what = it.num.map { "الدرس \($0)" } ?? it.title
            return "آخر مرة: \(what) · \(when)"
        }
        if let d = f.lastDone[track] {
            return "آخر مرة: " + DateKit.long(d)
        }
        return nil
    }

    func dayState(_ day: String) -> Int {   // 0 لا شي، 1 بعضه، 2 خلص
        guard let f = feed else { return 0 }
        if f.day(day)?.finished == true { return 2 }
        let list = f.items.filter { $0.day == day }
        guard !list.isEmpty else { return 0 }
        let done = list.filter(\.isDone).count
        if done == list.count { return 2 }
        return done > 0 ? 1 : 0
    }

    // MARK: - تعديل

    private func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    func toggle(_ item: Item) {
        guard let i = feed?.items.firstIndex(where: { $0.id == item.id }) else { return }
        let old = feed!.items[i].status
        let new = old == "done" ? "planned" : "done"
        feed!.items[i].status = new
        tap()
        Task {
            do {
                try await API.setItem(id: item.id, status: new, note: nil)
                await afterChange()
            } catch {
                if let j = feed?.items.firstIndex(where: { $0.id == item.id }) { feed!.items[j].status = old }
                flash("ما انحفظ، تأكد من النت")
            }
        }
    }

    func saveNote(_ item: Item, _ text: String) {
        guard let i = feed?.items.firstIndex(where: { $0.id == item.id }) else { return }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (feed!.items[i].note ?? "") == clean { return }
        feed!.items[i].note = clean.isEmpty ? nil : clean
        Task {
            do {
                try await API.setItem(id: item.id, status: nil, note: clean)
                await afterChange()
            } catch { flash("الملاحظة ما انحفظت") }
        }
    }

    func toggleFlex(_ t: FlexTask) {
        guard let i = feed?.flex.firstIndex(where: { $0.id == t.id }) else { return }
        let undo = t.isDone(today)
        let old = feed!.flex[i].lastDone
        let oldLog = feed!.flexLog
        let d = today
        feed!.flex[i].lastDone = undo ? nil : d
        if undo {
            feed!.flexLog.removeAll { $0.taskId == t.id && $0.day == d }
        } else {
            feed!.flexLog.append(FlexLog(taskId: t.id, day: d))
        }
        tap()
        Task {
            do {
                try await API.flexDone(id: t.id, undo: undo)
                if undo { await load() } else { await afterChange() }
            } catch {
                if let j = feed?.flex.firstIndex(where: { $0.id == t.id }) { feed!.flex[j].lastDone = old }
                feed?.flexLog = oldLog
                flash("ما انحفظ، تأكد من النت")
            }
        }
    }

    func saveDay(_ day: String, note: String?, finished: Bool?) {
        guard feed != nil else { return }
        if let i = feed!.days.firstIndex(where: { $0.day == day }) {
            if let note { feed!.days[i].myNote = note.isEmpty ? nil : note }
            if let finished { feed!.days[i].finished = finished }
        } else {
            feed!.days.append(DayInfo(day: day, title: nil, claudeNote: nil, myNote: note, finished: finished ?? false))
        }
        if finished != nil { tap() }
        Task {
            do {
                try await API.setDay(day: day, note: note, finished: finished)
                await afterChange()
            } catch { flash("ما انحفظ، تأكد من النت") }
        }
    }

    private func afterChange() async {
        if let f = feed {
            FeedCache.save(f)
            await Notifier.schedule(feed: f)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func flash(_ m: String) {
        message = m
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if message == m { message = nil }
        }
    }
}
