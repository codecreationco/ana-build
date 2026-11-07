import Foundation

/// بيانات تجريبية: يشتغل فيها التطبيق قبل ما نربطه بقاعدة البيانات.
/// فيها موعد «تجربة التنبيه» بعد ٦ دقايق من فتح التطبيق، والتنبيه قبله بدقيقتين.
enum Sample {
    static func feed(now: Date = Date()) -> Feed {
        let today = DateKit.key(now)
        let start = DateKit.weekStart(today)

        let tracks = [
            Track(id: "mantiq", name: "تدريس المنطق", short: "منطق", grp: "دروس", color: "#2B333D", inGrid: true, sort: 1),
            Track(id: "matajer", name: "درس المتاجر", short: "متاجر", grp: "دروس", color: "#2B333D", inGrid: true, sort: 2),
            Track(id: "rasael", name: "درس الرسائل", short: "رسائل", grp: "دروس", color: "#2B333D", inGrid: true, sort: 3),
            Track(id: "taqrir", name: "تقرير المتاجر", short: "تقرير متاجر", grp: "كتابة", color: "#2B333D", inGrid: true, sort: 4),
            Track(id: "ktbrasael", name: "كتابة الرسائل", short: "رسائل", grp: "كتابة", color: "#2B333D", inGrid: true, sort: 5),
            Track(id: "wazzan", name: "وزان", short: "وزان", grp: "شغل", color: "#2B333D", inGrid: true, sort: 6),
            Track(id: "daftar", name: "دفتر الحصة", short: "دفتر الحصة", grp: "شغل", color: "#2B333D", inGrid: true, sort: 7),
            Track(id: "gym", name: "النادي", short: "نادي", grp: "نادي", color: "#2B333D", inGrid: true, sort: 8),
            Track(id: "outing", name: "طلعات", short: "طلعات", grp: "طلعات", color: "#2B333D", inGrid: true, sort: 9),
            Track(id: "routine", name: "الروتين", short: "روتين", grp: "روتين", color: "#2B333D", inGrid: false, sort: 10)
        ]

        var items: [Item] = []
        func mk(_ day: String, _ track: String, _ kind: String, _ title: String, label: String? = nil, num: Int? = nil,
                topic: String? = nil, details: String? = nil, time: String? = nil, remind: Int = 15, sort: Int = 0) {
            let past = day < today
            items.append(Item(id: "s-\(day)-\(track)-\(sort)", day: day, trackId: track, kind: kind, title: title,
                              label: label, num: num, topic: topic, details: details, atTime: time, remindMin: remind,
                              status: past ? "done" : "planned", note: nil, sort: sort))
        }

        var mt = 165, rs = 72, mn = 9
        for i in 0..<21 {
            let d = DateKit.add(i, to: start)
            let w = DateKit.weekday(d)   // 1 أحد ... 7 سبت
            if w == 7 || w <= 4 {
                mk(d, "matajer", "appt", "المتاجر · الدرس \(mt)", num: mt, topic: "[موضوع الدرس]", sort: 1); mt += 1
            }
            if w == 7 || w == 2 || w == 4 {
                mk(d, "rasael", "appt", "الرسائل · الدرس \(rs)", num: rs, topic: "[موضوع الدرس]", sort: 2); rs += 1
            }
            if w == 3 || w == 5 {
                mk(d, "mantiq", "appt", "تدريس المنطق · الدرس \(mn)", num: mn, topic: "[موضوع الدرس]", sort: 3); mn += 1
            }
            if w == 2 || w == 4 {
                mk(d, "mantiq", "appt", "تحضير المنطق · الدرس \(mn)", label: "تحضير", topic: "[النقاط اللي بتشرحها]", sort: 4)
            }
            if let g = [1: "U", 2: "L", 4: "U", 5: "L"][w] {
                mk(d, "gym", "appt", "النادي · \(g == "U" ? "Upper" : "Lower")", label: g,
                   details: "الجولات والأوزان في دفتر التمرين", sort: 5)
            }
            if w == 6 && i > 2 {
                mk(d, "outing", "special", "[طلعة]", topic: "[المكان]", sort: 6)
            }
            mk(d, "routine", "routine", "بروتين", topic: "الهدف 110 غ", sort: 10)
            mk(d, "routine", "routine", "دواء الصبح", topic: "[اسم الدواء]", sort: 11)
            mk(d, "routine", "routine", "دواء الليل", topic: "[اسم الدواء]", sort: 12)
        }

        // موعد تجربة التنبيه
        let mins = DateKit.cal.component(.hour, from: now) * 60 + DateKit.cal.component(.minute, from: now) + 6
        if mins < 24 * 60 {
            let t = String(format: "%02d:%02d:00", mins / 60, mins % 60)
            items.append(Item(id: "s-test-\(today)", day: today, trackId: "outing", kind: "special",
                              title: "تجربة التنبيه", label: nil, num: nil,
                              topic: "إذا وصلك تنبيه عن هذا، الإشعارات شغالة", details: nil,
                              atTime: t, remindMin: 2, status: "planned", note: nil, sort: 0))
        }

        let flex = [
            FlexTask(id: "taqrir", title: "تقرير المتاجر القديم", trackId: "taqrir", everyDays: 3, effort: "تركيز",
                     lastDone: DateKit.add(-6, to: today), note: nil, sort: 1),
            FlexTask(id: "ktbrasael", title: "كتابة الرسائل", trackId: "ktbrasael", everyDays: 3, effort: "تركيز",
                     lastDone: DateKit.add(-3, to: today), note: nil, sort: 2),
            FlexTask(id: "wazzan", title: "وزان", trackId: "wazzan", everyDays: 1, effort: "متوسط",
                     lastDone: DateKit.add(-1, to: today), note: nil, sort: 3),
            FlexTask(id: "daftar", title: "دفتر الحصة", trackId: "daftar", everyDays: 2, effort: "خفيف",
                     lastDone: DateKit.add(-1, to: today), note: nil, sort: 4)
        ]
        let log = [
            FlexLog(taskId: "taqrir", day: DateKit.add(-6, to: today)),
            FlexLog(taskId: "ktbrasael", day: DateKit.add(-3, to: today)),
            FlexLog(taskId: "wazzan", day: DateKit.add(-1, to: today)),
            FlexLog(taskId: "daftar", day: DateKit.add(-1, to: today))
        ]

        let days = [DayInfo(day: today, title: "نسخة تجريبية",
                            claudeNote: "هذي بيانات تجريبية عشان نتأكد إن التطبيق والويدجت والتنبيهات شغالة. جدولك الحقيقي يجي في المرحلة الجاية.",
                            myNote: nil, finished: false)]
        let weeks = [WeekInfo(weekStart: start, summary: "أسبوع تجريبي: الأرقام والمواضيع أمثلة.")]

        return Feed(today: today, tracks: tracks, items: items, flex: flex, flexLog: log,
                    days: days, weeks: weeks, lastDone: [:])
    }
}
