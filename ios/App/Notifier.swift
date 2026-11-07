import Foundation
import UserNotifications

/// التنبيهات تنضبط على التلفون نفسه، فتوصل في وقتها حتى بدون نت.
enum Notifier {
    static func requestAuth() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func schedule(feed: Feed) async {
        let c = UNUserNotificationCenter.current()
        let pending = await c.pendingNotificationRequests()
        c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("m-") })

        let now = Date()
        let horizon = now.addingTimeInterval(14 * 86400)
        var reqs: [(Date, String, UNMutableNotificationContent)] = []

        for it in feed.items where it.status == "planned" {
            guard let t = it.atTime, let at = DateKit.fire(day: it.day, time: t) else { continue }
            let fire = at.addingTimeInterval(-Double(it.remindMin) * 60)
            guard fire > now, fire < horizon else { continue }
            let content = UNMutableNotificationContent()
            content.title = it.title
            var body = it.remindMin > 0 ? "بعد \(it.remindMin) دقيقة" : "الحين"
            if let time = DateKit.timeLabel(t) { body += " · الساعة \(time)" }
            if let tp = it.topic, !tp.isEmpty { body += "\n" + tp }
            content.body = body
            content.sound = .default
            reqs.append((fire, "m-" + it.id, content))
        }

        // ملخص الصبح الساعة 7
        for i in 0..<7 {
            let k = DateKit.add(i, to: DateKit.todayKey)
            let list = feed.items(on: k, kinds: ["appt", "special"]).filter { $0.status == "planned" }
            guard !list.isEmpty, let fire = DateKit.fire(day: k, time: "07:00:00"), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "جدول اليوم · \(list.count) " + (list.count == 1 ? "موعد" : "مواعيد")
            var body = list.prefix(4).map { it -> String in
                if let t = DateKit.timeLabel(it.atTime) { return "\(it.title) (\(t))" }
                return it.title
            }.joined(separator: " · ")
            if list.count > 4 { body += " و\(list.count - 4) غيرها" }
            content.body = body
            content.sound = .default
            reqs.append((fire, "m-am-" + k, content))
        }

        for (fire, id, content) in reqs.sorted(by: { $0.0 < $1.0 }).prefix(60) {
            let trig = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
            try? await c.add(UNNotificationRequest(identifier: id, content: content, trigger: trig))
        }
    }
}
