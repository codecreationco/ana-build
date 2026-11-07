import Foundation

// صفحة اليوم والرئيسية: كل أشياء اليوم بقائمة وحدة، والسطر اللي تحت الاسم،
// والنوم والقيلولة، والصلاة، والأكل، والقراءة.
extension LifeStore {

    // MARK: - أشياء اليوم

    func choresOn(_ day: String) -> [Chore] {
        let wd = DateKit.weekday(day)
        return d.chores.filter { $0.day == day || ($0.day == nil && $0.days.contains(wd)) }
    }

    func isChoreDone(_ id: String, _ day: String) -> Bool { d.choreDone[day]?.contains(id) ?? false }

    func toggleChore(_ id: String, _ day: String) {
        var l = d.choreDone[day] ?? []
        if let i = l.firstIndex(of: id) { l.remove(at: i) } else { l.append(id) }
        d.choreDone[day] = l.isEmpty ? nil : l
        save()
    }

    /// قبل لا أطلع: القهوة (فيها الكرياتين) والمطارة
    var leaveDone: Bool {
        let h = health(today)
        return h.creatine && h.bottle
    }

    var leaveSub: String {
        let h = health(today)
        switch (h.creatine, h.bottle) {
        case (true, true): return "القهوة والمطارة تم"
        case (true, false): return "القهوة تم · المطارة باقي"
        case (false, true): return "المطارة تم · القهوة باقي"
        default: return workout(on: today) != nil ? "القهوة، والمطارة فيها الإلكترولايت" : "القهوة والمطارة"
        }
    }

    func toggleLeave() {
        var h = health(today)
        let v = !(h.creatine && h.bottle)
        h.creatine = v
        h.bottle = v
        if workout(on: today) != nil { h.electrolyte = v }
        d.health[today] = h
        save()
    }

    var gymDoneToday: Bool {
        guard let w = workout(on: today) else { return false }
        let s = setsDone(today, w)
        return isChoreDone("gym", today) || (s.total > 0 && s.done == s.total)
    }

    /// كم يوم من آخر مرة انسوت فيه خطوة بمادة
    func daysSince(course: String, stage: Int) -> Int {
        guard let last = d.lessonLogs.filter({ $0.course == course && $0.stage == stage }).map(\.day).max() else { return 30 }
        return max(0, DateKit.diff(last, today))
    }

    func daysSince(book b: Book) -> Int {
        guard let last = b.logs.keys.filter({ $0 <= today }).max() else { return 30 }
        return max(0, DateKit.diff(last, today))
    }

    /// كل أشياء اليوم: اللي لها وقت بالترتيب، وبعدها اللي بأي وقت
    var todayItems: [TodayItem] {
        var out: [TodayItem] = []

        out.append(TodayItem(id: "leave", time: 400, timeText: "قبل الطلعة", title: "قبل لا أطلع",
                             sub: leaveSub, done: leaveDone, kind: .leave))

        for c in choresOn(today) {
            let t = LFmt.minutesOf(c.time)
            out.append(TodayItem(id: "c-" + c.id, time: t, timeText: c.timeText ?? DateKit.timeLabel(c.time), title: c.title,
                                 sub: c.sub ?? (c.routine ? nil : "مو روتيني"), done: isChoreDone(c.id, today),
                                 routine: c.routine, kind: .chore(c.id)))
        }

        if let w = workout(on: today) {
            out.append(TodayItem(id: "gym", time: 450, timeText: "بعد الروضة", title: "النادي · \(w.kind)",
                                 sub: w.pool ? "مشي، حديد، حوض" : "مشي وحديد", done: gymDoneToday, kind: .gym))
        }

        for t in todayTasks {
            let c = t.course
            var item = TodayItem(id: t.id, title: "", done: t.done, kind: .lesson(t.id))
            switch (c.mode, t.stage) {
            case (.teach, 1):
                item.title = "تدريس \(c.title)"
                item.sub = "درس \(t.num)" + (!t.done && !c.nextPrepared ? " · ما تحضّر" : "")
                item.time = LFmt.minutesOf(c.time)
                item.timeText = DateKit.timeLabel(c.time)
            case (.teach, _):
                item.title = "تحضير \(c.title)"
                item.sub = "درس \(t.num)" + (t.meta.map { " · " + $0 } ?? "")
            case (.online, 0):
                item.title = "حضور درس \(c.shortName)"
                item.sub = "درس \(t.num) · أونلاين"
                item.time = LFmt.minutesOf(c.time)
                item.timeText = DateKit.timeLabel(c.time)
            case (.online, _):
                item.title = "تقرير \(c.shortName)"
                item.sub = "درس \(t.num)"
                let k = daysSince(course: c.id, stage: 1)
                item.stale = k
                item.staleText = k <= 1 ? nil : "صار لك \(k) أيام ما كتبت تقرير"
            case (.recording, _):
                item.title = "تقرير \(c.shortName)"
                item.sub = "درس \(t.num)"
                let k = daysSince(course: c.id, stage: 0)
                item.stale = k
                item.staleText = k <= 1 ? nil : "صار لك \(k) أيام ما كتبت"
            }
            out.append(item)
        }

        for b in d.books {
            let read = b.logs[today] != nil
            let k = daysSince(book: b)
            out.append(TodayItem(id: "b-" + b.id, title: "قراءة \(b.title)",
                                 sub: read ? "وصلت صفحة \(b.page)" : "من صفحة \(b.page)",
                                 done: read, kind: .book(b.id),
                                 stale: read ? 0 : k, staleText: k <= 1 ? nil : "صار لك \(k) أيام ما قريت"))
        }

        for a in d.special where a.day == today && a.status != .cancelled {
            let t = LFmt.minutesOf(a.time)
            out.append(TodayItem(id: "s-" + a.id, time: t, timeText: DateKit.timeLabel(a.time), title: a.title,
                                 sub: a.status == .confirmed ? a.note : a.status.label,
                                 done: isChoreDone("s-" + a.id, today), routine: false, kind: .chore("s-" + a.id)))
        }

        let timed = out.filter { $0.time != nil }.sorted { ($0.time ?? 0) < ($1.time ?? 0) }
        let any = out.filter { $0.time == nil }.sorted { a, b in
            // الدروس أول، بعدها القراءة، بعدها الباقي
            func rank(_ i: TodayItem) -> Int {
                switch i.kind {
                case .lesson: return 0
                case .book: return 1
                default: return 2
                }
            }
            return rank(a) < rank(b)
        }
        return timed + any
    }

    /// الجاي: أول شي له وقت وما خلص، وما طاف عليه أكثر من ساعة
    func nextItem(_ items: [TodayItem]) -> TodayItem? {
        let now = Self.nowMinutes()
        return items.first { !$0.done && ($0.time ?? -1000) + 60 > now }
    }

    func toggle(_ item: TodayItem) {
        switch item.kind {
        case .lesson(let id):
            if let t = todayTasks.first(where: { $0.id == id }) { toggleTask(t) }
        case .chore(let id):
            toggleChore(id, today)
        case .leave:
            toggleLeave()
        case .gym:
            toggleChore("gym", today)
        case .book:
            break   // القراءة تحتاج رقم الصفحة، الشاشة تسأل
        }
    }

    /// اقتراح من «بأي وقت»: اللي صار له أطول وقت ما انسوى
    func suggestion(_ items: [TodayItem]) -> TodayItem? {
        items.filter { !$0.done && $0.time == nil && ($0.stale ?? 0) >= 2 }
            .max { ($0.stale ?? 0) < ($1.stale ?? 0) }
    }

    /// أقرب موعد خاص بعد اليوم (لين 3 أيام)
    var soonAppt: SpecialAppt? {
        specialSorted.first { a in
            guard let k = a.day else { return false }
            let n = DateKit.diff(today, k)
            return n >= 1 && n <= 3
        }
    }

    func apptLine(_ a: SpecialAppt) -> String {
        let when = DateKit.countdown(from: today, to: a.day ?? today)
        return when + " " + a.title + (a.status == .confirmed ? "" : " (\(a.status.label))")
    }

    /// رقم الدرس اللي عليك بيوم جاي حسب الخطة (تقرير المتاجر كل يوم، وتقرير الأصول كل يوم إلا الجمعة)
    func planned(_ c: Course, stage: Int, on day: String) -> Int? {
        let start = logs(on: today, course: c.id, stage: stage).isEmpty ? today : DateKit.add(1, to: today)
        guard day >= start else { return nil }
        switch c.mode {
        case .recording:
            let n = c.stageA + 1 + DateKit.diff(start, day)
            return n <= c.released + DateKit.diff(today, day) ? n : nil
        case .online:
            guard DateKit.weekday(day) != 6 else { return nil }
            var n = c.stageB + 1
            var k = start
            while k < day { if DateKit.weekday(k) != 6 { n += 1 }; k = DateKit.add(1, to: k) }
            return n
        case .teach:
            return nil
        }
    }

    // MARK: - القراءة

    func savePage(_ id: String, _ page: Int) {
        guard let i = d.books.firstIndex(where: { $0.id == id }) else { return }
        let p = min(max(page, 0), d.books[i].total)
        d.books[i].page = p
        d.books[i].logs[today] = p
        save()
    }

    /// «آخر قراءة أمس · قريت 12 صفحة»
    func readLine(_ b: Book) -> String {
        let days = b.logs.keys.sorted()
        guard let last = days.last, let p = b.logs[last] else { return "ما سجلت قراءة للحين" }
        let before = days.dropLast().last.flatMap { b.logs[$0] }
        let k = DateKit.diff(last, today)
        let when = k == 0 ? "اليوم" : (k == 1 ? "أمس" : "قبل \(k) أيام")
        if let before, p > before { return "آخر قراءة \(when) · قريت \(p - before) صفحة" }
        return "آخر قراءة \(when)"
    }

    // MARK: - النوم والقيلولة

    var wakePlanMin: Int { LFmt.minutesOf(d.sleep.wake) ?? 300 }

    /// المنبه شغال بهاليوم؟ من الأحد لين الخميس، والجمعة والسبت إذا شغّلته
    func alarmOn(_ day: String) -> Bool {
        guard d.sleep.alarm else { return false }
        let wd = DateKit.weekday(day)
        if (1...5).contains(wd) { return true }
        return d.sleep.weekendTimes?[day] != nil || d.sleep.weekendOn.contains(day)
    }

    /// وقت القعدة بيوم معين: من الأحد لين الخميس وقت الخطة، والعطلة وقتها إذا محدد
    func wakeFor(_ day: String) -> Int {
        let wd = DateKit.weekday(day)
        if (1...5).contains(wd) { return wakePlanMin }
        if let t = LFmt.minutesOf(d.sleep.weekendTimes?[day]) { return t }
        return LFmt.minutesOf(d.sleep.weekendWake) ?? wakePlanMin
    }

    /// وقت منبه العطلة اللي اخترته (للورقة)
    var weekendDefault: Int { LFmt.minutesOf(d.sleep.weekendWake) ?? 420 }

    /// يشغّل منبه جمعة أو سبت بوقت معين، أو يطفيه (nil)
    func setWeekendAlarm(_ day: String, _ m: Int?) {
        var t = d.sleep.weekendTimes ?? [:]
        d.sleep.weekendOn.removeAll { $0 == day }
        if let m {
            t[day] = LFmt.hhmm(m)
            d.sleep.weekendWake = LFmt.hhmm(m)
        } else {
            t[day] = nil
        }
        d.sleep.weekendTimes = t
        save()
        LifeNotifier.schedule(self)
    }

    var tomorrow: String { DateKit.add(1, to: today) }
    var tomorrowIsWeekend: Bool { [6, 7].contains(DateKit.weekday(tomorrow)) }

    func toggleWeekendAlarm(_ day: String) {
        if let i = d.sleep.weekendOn.firstIndex(of: day) { d.sleep.weekendOn.remove(at: i) }
        else { d.sleep.weekendOn.append(day) }
        save()
        LifeNotifier.schedule(self)
    }

    func setWakePlan(_ m: Int) {
        d.sleep.wake = LFmt.hhmm(m)
        save()
        LifeNotifier.schedule(self)
    }

    func toggleAlarm() {
        d.sleep.alarm.toggle()
        save()
        LifeNotifier.schedule(self)
    }

    var napToday: NapLog? { d.naps[today] }

    func setNap(_ day: String, _ min: Int?) {
        if let min { d.naps[day] = NapLog(min: min, at: LFmt.hhmm(Self.nowMinutes())) }
        else { d.naps[day] = nil }
        save()
        LifeNotifier.schedule(self)
    }

    /// النوم المقترح بدون القيلولة: 9 ساعات قبل قعدة اليوم اللي بعده
    func bedBase(_ day: String) -> Int { (wakeFor(DateKit.add(1, to: day)) - d.sleep.needMin + 1440) % 1440 }

    /// النوم المقترح الليلة: القيلولة تأخره على قد مدتها، وإذا عدلته بيدك ناخذ تعديلك
    func bedtime(_ day: String) -> Int {
        if let o = LFmt.minutesOf(d.bedOverride[day]) { return o }
        return (bedBase(day) + (d.naps[day]?.min ?? 0)) % 1440
    }

    func remindTime(_ day: String) -> Int { (bedtime(day) - d.sleep.remindMin + 1440) % 1440 }

    func setBedtime(_ day: String, _ m: Int?) {
        d.bedOverride[day] = m.map(LFmt.hhmm)
        save()
        LifeNotifier.schedule(self)
    }

    /// كم نمت ليلة يوم معين (من سجل الليالي)
    func night(_ day: String) -> NightLog? { d.nights.first { $0.day == day } }

    // MARK: - الصلاة

    /// الفجر والظهر والمغرب (على طريقة تقويم الصايغ للكويت)، والشروق ومنتصف الليل للعلم
    func prayers(_ day: String) -> [Prayer] {
        guard let t = PrayerCalc.day(day) else { return [] }
        return [
            Prayer(id: "fajr", name: "الفجر", min: t.subh, end: t.sunrise, note: "الأذان " + LFmt.clock(t.fajrAdhan)),
            Prayer(id: "sunrise", name: "الشروق", min: t.sunrise, pray: false),
            Prayer(id: "dhuhr", name: "الظهر", min: t.dhuhr, end: t.sunset, note: "الزوال " + LFmt.clock(t.zawal)),
            Prayer(id: "maghrib", name: "المغرب", min: t.maghrib, end: t.midnight, note: "الغروب " + LFmt.clock(t.sunset)),
            Prayer(id: "midnight", name: "منتصف الليل", min: t.midnight, pray: false),
        ]
    }

    func prayed(_ id: String, _ day: String) -> Bool { d.prayerDone[day]?.contains(id) ?? false }

    func togglePrayer(_ id: String, _ day: String) {
        var l = d.prayerDone[day] ?? []
        if let i = l.firstIndex(of: id) { l.remove(at: i) } else { l.append(id) }
        d.prayerDone[day] = l.isEmpty ? nil : l
        save()
        LifeNotifier.schedule(self)
    }

    /// الصلاة اللي دخل وقتها وما جت اللي بعدها
    var currentPrayer: Prayer? {
        let now = Self.nowMinutes()
        return prayers(today).first { $0.pray && now >= $0.min && now < ($0.end ?? 1440) }
    }

    /// الصلاة الجاية: (الصلاة، كم دقيقة باقي)
    var nextPrayer: (Prayer, Int)? {
        let now = Self.nowMinutes()
        let list = prayers(today).filter(\.pray)
        if let p = list.first(where: { $0.min > now }) { return (p, p.min - now) }
        if let f = prayers(tomorrow).first(where: \.pray) { return (f, f.min + 1440 - now) }
        return nil
    }

    func setPrayerAlarm(_ v: Bool) {
        d.prayerAlarm = v
        save()
        LifeNotifier.schedule(self)
    }

    func setPrayerAsk(_ v: Bool) {
        d.prayerAsk = v
        save()
    }

    // MARK: - السطر اللي تحت الاسم

    var status: StatusLine {
        let now = Self.nowMinutes()
        let woke = todayNight != nil
        // قعدت الحين؟ من الفجر لين ساعتين بعد المنبه (أيام العطلة لين الظهر)
        let wakeEnd = (alarmOn(today) ? wakeFor(today) : 600) + 120
        if !woke && now >= 180 && now < wakeEnd { return .wake }
        if let c = lessonNow { return .lesson(c) }
        if d.prayerAsk, let p = currentPrayer, !prayed(p.id, today) { return .prayer(p) }
        if woke && napToday == nil && now >= 720 && now < 1080 { return .nap }
        if (now >= 1080 || now < 180) && sleepHours != nil { return .bed }
        return .none
    }

    /// درس حضوري قرب وقته (من قبله بنص ساعة لين بعده بثلث ساعة) وما سجلت إنك حضرته
    var lessonNow: Course? {
        let now = Self.nowMinutes()
        for c in d.courses where c.mode != .recording && held(c, today) {
            guard let t = LFmt.minutesOf(c.time) else { continue }
            let stage = c.mode == .teach ? 1 : 0
            if !logs(on: today, course: c.id, stage: stage).isEmpty { continue }
            if now >= t - 30 && now <= t + 20 { return c }
        }
        return nil
    }

    /// المادة اللي ورا شي بقائمة اليوم (إذا درس)
    func course(of item: TodayItem) -> Course? {
        guard case .lesson(let id) = item.kind else { return nil }
        return todayTasks.first { $0.id == id }?.course
    }

    /// لو نمت الحين، تقعد بعد كم دقيقة (الأحد لين الخميس 6:30، والجمعة والسبت بس إذا شغّلت المنبه)
    var sleepHours: Int? {
        let now = Self.nowMinutes()
        // بعد نص الليل القعدة نفس اليوم، وقبله باجر
        let wakeDay = now < 720 ? today : tomorrow
        guard alarmOn(wakeDay) else { return nil }
        var m = wakeFor(wakeDay) - now
        if m < 0 { m += 1440 }
        return m
    }

    // MARK: - الأكل

    func foods(_ day: String) -> [FoodEntry] { (d.food[day] ?? []).sorted { $0.at < $1.at } }

    /// البروتين: اللي سجلته بالقائمة، وأي رقم قديم بدونها
    func protein(_ day: String) -> Int {
        foods(day).reduce(0) { $0 + $1.grams } + health(day).protein
    }

    func addFood(_ title: String, _ grams: Int) {
        guard grams > 0 else { return }
        var l = d.food[today] ?? []
        l.append(FoodEntry(id: UUID().uuidString, title: title, grams: grams, at: LFmt.hhmm(Self.nowMinutes())))
        d.food[today] = l
        save()
    }

    func removeFood(_ id: String) {
        d.food[today]?.removeAll { $0.id == id }
        save()
    }
}

/// وقت الراحة بين الجولات لكل تمرين (بالثواني)
enum RestTimes {
    static func of(_ id: String) -> Int {
        switch id {
        case "chest", "legpress": return 150
        case "lat", "row", "legcurl", "backext": return 120
        case "shoulder", "tri", "bi", "legext", "fly": return 90
        case "calf", "crunch": return 60
        default: return 90
        }
    }

    static func label(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
