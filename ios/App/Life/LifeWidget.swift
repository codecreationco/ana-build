import Foundation
import WidgetKit

extension LifeStore {
    /// يكتب أشياء اليوم والصلاة للويدجت، ويحدثها إذا تغير شي
    func writeWidget() {
        guard !Snap.on else { return }
        let rows = todayItems.map {
            WidgetSnap.Row(id: $0.id, time: $0.time, timeText: $0.timeText, title: $0.title, sub: $0.sub, done: $0.done)
        }
        func pr(_ day: String) -> [WidgetSnap.Pray] {
            prayers(day).filter(\.pray).map { WidgetSnap.Pray(id: $0.id, name: $0.name, min: $0.min) }
        }
        let snap = WidgetSnap(day: today, rows: rows, prayers: pr(today), prayersTomorrow: pr(tomorrow),
                              prayed: d.prayerDone[today] ?? [])
        if WidgetSnap.save(snap) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
