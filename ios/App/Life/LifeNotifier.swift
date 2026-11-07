import Foundation
import UserNotifications

/// التنبيهات تنضبط على التلفون نفسه: القعدة، الصلاة (وقبل القضاء)، الدروس، وقبل لا تطلع.
/// (عداد الراحة بالنادي ينضبط بروحه ونخليه.)
enum LifeNotifier {
    static func requestAuth() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    @MainActor
    static func schedule(_ store: LifeStore) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        var reqs: [(Date, String, UNMutableNotificationContent)] = []

        func add(_ day: String, _ time: String, _ id: String, _ title: String, _ body: String, link: String? = nil) {
            guard let at = DateKit.fire(day: day, time: time), at > now else { return }
            let c = UNMutableNotificationContent()
            c.title = title
            c.body = body
            c.sound = .default
            if let link { c.userInfo = ["link": link] }
            reqs.append((at, id, c))
        }

        for i in 0..<7 {
            let day = DateKit.add(i, to: store.today)

            // القعدة: من الأحد لين الخميس، والجمعة والسبت إذا شغّلته
            if store.alarmOn(day) {
                add(day, LFmt.hhmm(store.wakeFor(day)), "a-wake-\(day)", "صباح الخير يا حسن", "قعدت؟")
            }

            // الصلاة بوقتها بالضبط (أول 3 أيام)
            if store.d.prayerAlarm && i < 3 {
                for p in store.prayers(day) where p.pray {
                    add(day, p.time, "a-pr-\(p.id)-\(day)", "صلاة \(p.name)", "دخل وقت \(p.name)")
                }
            }
            // ما سجلت إنك صليت: تنبيه قبل القضاء بـ 20 دقيقة
            if i < 3 {
                for p in store.prayers(day) where p.pray && !store.prayed(p.id, day) {
                    guard let end = p.end else { continue }
                    let name = p.id == "fajr" ? "الشروق" : (p.id == "dhuhr" ? "الغروب" : "منتصف الليل")
                    add(day, LFmt.hhmm(end - 20), "q-\(p.id)-\(day)", "ما صليت \(p.name)؟",
                        "باقي 20 دقيقة على \(name) (\(LFmt.clock(end)))")
                }
            }

            // الدروس الحضورية: قبلها بنص ساعة، وقبلها بدقيقة (والرابط ينفتح من الإشعار)
            for c0 in store.d.courses where c0.mode != .recording && store.held(c0, day) {
                guard let t = c0.time, let m = LFmt.minutesOf(t) else { continue }
                let n = c0.mode == .teach ? store.teachNumber(c0, on: day) : store.lessonNumber(c0, on: day)
                let name = c0.mode == .teach ? "تدريس \(c0.title)" : "درس \(c0.shortName)"
                var body = (n.map { "درس \($0) · " } ?? "") + "الساعة " + LFmt.clock(m)
                if c0.mode == .teach, let n, n == c0.nextTeach, !c0.nextPrepared { body += " · ما تحضّر" }
                add(day, LFmt.hhmm(m - 30), "l-\(c0.id)-30-\(day)", name + " بعد نص ساعة", body, link: c0.link)
                add(day, LFmt.hhmm(m - 1), "l-\(c0.id)-1-\(day)", name + " بعد دقيقة",
                    c0.link == nil ? body : "اضغط تدخل الدرس", link: c0.link)
            }

            // قبل لا تطلع
            let gym = store.workout(on: day) != nil
            add(day, "06:45", "l-am-\(day)", "قبل لا تطلع",
                gym ? "القهوة مع الكرياتين، والمطارة مع الإلكترولايت. اليوم نادي" : "القهوة مع الكرياتين، والمطارة")
        }

        let list = reqs.sorted { $0.0 < $1.0 }.prefix(60)
        center.getPendingNotificationRequests { pending in
            // نشيل كل شي إلا عداد الراحة، ونرجع نضبط
            let old = pending.map(\.identifier).filter { $0 != "rest" }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for (fire, id, content) in list {
                let trig = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trig))
            }
        }
    }
}
