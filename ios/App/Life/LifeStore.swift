import Foundation
import SwiftUI

/// كل بيانات التطبيق، محفوظة بملف على التلفون.
@MainActor
final class LifeStore: ObservableObject {
    @Published var d: LifeData
    @Published var today: String = DateKit.todayKey

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ana-life-v5.json")
    }

    /// حالة الربط بقاعدة البيانات (تطلع صغيرة بالرئيسية)
    @Published var sync: String = ""
    private var pushTask: Task<Void, Never>?
    private var pulling = false
    /// إذا ملف السيرفر ما انقرا، ما نكتب فوقه لين ينصلح
    private var blocked = false

    /// رقم آخر نسخة من السيرفر بنينا عليها
    private var base: Int {
        get { UserDefaults.standard.integer(forKey: "sync.base") }
        set { UserDefaults.standard.set(newValue, forKey: "sync.base") }
    }

    init() {
        if Snap.on {
            d = LifeSample.make()
        } else if let data = try? Data(contentsOf: Self.url),
                  let saved = try? JSONDecoder().decode(LifeData.self, from: data) {
            d = saved
        } else {
            d = .empty
        }
        advance()
    }

    func save() {
        writeLocal()
        dirty = true
        schedulePush()
    }

    /// في تعديلات على التلفون ما وصلت السيرفر
    private var dirty: Bool {
        get { UserDefaults.standard.bool(forKey: "sync.dirty") }
        set { UserDefaults.standard.set(newValue, forKey: "sync.dirty") }
    }

    private func writeLocal() {
        guard !Snap.on, let data = try? JSONEncoder().encode(d) else { return }
        try? data.write(to: Self.url, options: .atomic)
    }

    // MARK: - المزامنة

    private func schedulePush() {
        guard !Snap.on, !pulling, !blocked else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    private func push() async {
        guard let data = try? JSONEncoder().encode(d) else { return }
        do {
            let (ok, v, server) = try await LifeSync.save(data, base: base)
            if ok {
                base = v
                dirty = false
                sync = ""
            } else if let server {
                // انحدثت بالسيرفر (من المحادثة): ناخذ نسخة السيرفر
                adopt(server, v)
                dirty = false
                undoData = nil
                toast = UndoToast(text: "انحدثت البيانات من المحادثة")
            }
        } catch {
            sync = "ما في اتصال · محفوظ على التلفون"
        }
    }

    /// يجيب آخر نسخة من السيرفر (لما تفتح التطبيق)
    func pull() async {
        guard !Snap.on else { return }
        pulling = true
        defer { pulling = false }
        do {
            if !UserDefaults.standard.bool(forKey: "sync.claimed") {
                guard try await LifeSync.claim() else {
                    sync = "هالجهاز مو مسجل بقاعدة البيانات"
                    blocked = true
                    return
                }
                UserDefaults.standard.set(true, forKey: "sync.claimed")
            }
            let (v, doc) = try await LifeSync.get()
            if v == 0 || doc == nil {
                // السيرفر فاضي: نبدأ فاضي (بدون البيانات الوهمية القديمة) ونرفعه
                if base == 0 { d = .empty; writeLocal() }
                await loadContent()
                pulling = false
                await push()
                return
            }
            if v != base, let doc {
                // السيرفر انحدث (من المحادثة): ناخذ نسخته
                if !adopt(doc, v) { return }
                dirty = false
            }
            await loadContent()
            if dirty {
                pulling = false
                await push()
                return
            }
            sync = ""
        } catch {
            sync = "ما في اتصال · محفوظ على التلفون"
        }
    }

    /// محتوى المحادثات (المواد، الدروس، النادي…)
    private func loadContent() async {
        guard let c = try? await LifeSync.content() else { return }
        let before = d
        applyContent(c)
        if d != before {
            writeLocal()
            dirty = true
            LifeNotifier.schedule(self)
        }
    }

    @discardableResult
    private func adopt(_ doc: Data, _ v: Int) -> Bool {
        do {
            d = try JSONDecoder().decode(LifeData.self, from: doc)
            base = v
            blocked = false
            writeLocal()
            advance()
            LifeNotifier.schedule(self)
            return true
        } catch {
            blocked = true
            sync = "ما قدرت أقرا البيانات من السيرفر · قول لـClaude"
            return false
        }
    }

    /// يفضي البيانات
    func reset() {
        d = .empty
        today = DateKit.todayKey
        save()
        LifeNotifier.schedule(self)
    }

    /// لما يتغير اليوم: الدروس اللي انعقدت أو وصل تسجيلها تنحسب
    func advance() {
        today = DateKit.todayKey
        let nowMin = Self.nowMinutes()
        let before = d.courses
        for i in d.courses.indices where d.courses[i].mode != .teach {
            var c = d.courses[i]
            var day = DateKit.add(1, to: c.asOf)
            while day <= today {
                let on = held(c, day)
                if day == today, let t = LFmt.minutesOf(c.time), nowMin < t { break }
                if on { c.released += 1 }
                c.asOf = day
                day = DateKit.add(1, to: day)
            }
            d.courses[i] = c
        }
        if d.courses != before { save() }
    }

    static func nowMinutes() -> Int {
        let c = DateKit.cal.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: - الدروس

    func course(_ id: String) -> Course? { d.courses.first { $0.id == id } }

    /// يزيد أو ينقص خطوة بالمادة، ويسجلها باليوم
    func bump(_ id: String, stage: Int, by delta: Int) {
        guard let i = d.courses.firstIndex(where: { $0.id == id }) else { return }
        var c = d.courses[i]
        if stage == 0 {
            let cap = c.mode == .teach ? c.stageB + 3 : c.released
            let v = min(max(c.stageA + delta, c.mode == .teach ? c.stageB : 0), cap)
            guard v != c.stageA else { return }
            if delta > 0 { d.lessonLogs.append(LessonLog(day: today, course: id, stage: 0, num: v)) }
            else { removeLog(course: id, stage: 0, num: c.stageA) }
            c.stageA = v
        } else {
            let v = min(max(c.stageB + delta, 0), c.stageA)
            guard v != c.stageB else { return }
            if delta > 0 { d.lessonLogs.append(LessonLog(day: today, course: id, stage: 1, num: v)) }
            else { removeLog(course: id, stage: 1, num: c.stageB) }
            c.stageB = v
            if c.mode == .teach { c.released = max(c.released, v) }
        }
        d.courses[i] = c
        save()
        LifeNotifier.schedule(self)
    }

    private func removeLog(course: String, stage: Int, num: Int) {
        if let j = d.lessonLogs.lastIndex(where: { $0.course == course && $0.stage == stage && $0.num == num }) {
            d.lessonLogs.remove(at: j)
        }
    }

    func info(_ c: Course, _ n: Int) -> LessonInfo { c.info[String(n)] ?? LessonInfo() }

    func setLessonNote(_ id: String, _ n: Int, _ t: String) {
        guard let i = d.courses.firstIndex(where: { $0.id == id }) else { return }
        var inf = d.courses[i].info[String(n)] ?? LessonInfo()
        inf.note = t.isEmpty ? nil : t
        d.courses[i].info[String(n)] = inf
        save()
    }

    /// آخر درس خلصته (للمراجعة)
    func lastDone(_ c: Course) -> Int? {
        let n = c.mode == .teach ? c.stageB : c.stageA
        return n >= c.startNum && n > 0 ? n : nil
    }

    /// مهام الدروس لليوم برقم الدرس اللي عليك. اللي خلصته اليوم يبقى ظاهر (تم)،
    /// واللي ما خلصته يبقى نفس الرقم لين تخلصه، حتى لو مر يوم.
    var todayTasks: [LessonTask] {
        var out: [LessonTask] = []
        let wd = DateKit.weekday(today)
        for c in d.courses {
            switch c.mode {
            case .teach:
                let label = "\(c.title) · تدريس"
                if held(c, today) {
                    let did = logs(on: today, course: c.id, stage: 1)
                    if let n = did.last {
                        out.append(LessonTask(id: "\(c.id)-teach-\(n)", course: c, stage: 1, label: label,
                                              title: "درّست درس \(n)", meta: DateKit.timeLabel(c.time), done: true, num: n))
                    } else {
                        // يبقى طول اليوم لين تضغط «درّسته»، حتى لو طاف الوقت
                        let n = c.nextTeach
                        let meta = [DateKit.timeLabel(c.time), c.nextPrepared ? "محضّر" : "ما تحضّر"].compactMap { $0 }.joined(separator: " · ")
                        out.append(LessonTask(id: "\(c.id)-teach", course: c, stage: 1, label: label,
                                              title: "درّس درس \(n)", meta: meta, warn: !c.nextPrepared,
                                              done: false, num: n, action: "درّسته"))
                    }
                }
                let plabel = "\(c.title) · تحضير"
                for n in logs(on: today, course: c.id, stage: 0) {
                    out.append(LessonTask(id: "\(c.id)-prep-\(n)", course: c, stage: 0, label: plabel,
                                          title: "حضّرت درس \(n)", meta: nil, done: true, num: n))
                }
                // التحضير يطلع قبل الدرس بيوم أو أكثر (لين 3 أيام)
                let n = c.stageA + 1
                if let day = teachDay(c, num: n), DateKit.diff(today, day) <= 3 {
                    let k = DateKit.diff(today, day)
                    let meta = k == 0 ? "للدرس اليوم" : "لدرس " + DateKit.dayName(day)
                    out.append(LessonTask(id: "\(c.id)-prep", course: c, stage: 0, label: plabel,
                                          title: "حضّر درس \(n)", meta: meta, warn: k == 0, done: false, num: n))
                }
            case .online:
                if held(c, today) {
                    let label = "\(c.title) · حضور"
                    let did = logs(on: today, course: c.id, stage: 0)
                    if let n = did.last {
                        out.append(LessonTask(id: "\(c.id)-attend-\(n)", course: c, stage: 0, label: label,
                                              title: "حضرت درس \(n)", meta: DateKit.timeLabel(c.time), done: true, num: n))
                    } else {
                        let n = max(c.stageA + 1, lessonNumber(c, on: today) ?? c.released)
                        out.append(LessonTask(id: "\(c.id)-attend", course: c, stage: 0, label: label,
                                              title: "احضر درس \(n)", meta: DateKit.timeLabel(c.time),
                                              done: false, num: n, action: "حضرت"))
                    }
                }
                let label = "\(c.title) · تقرير"
                for n in logs(on: today, course: c.id, stage: 1) {
                    out.append(LessonTask(id: "\(c.id)-report-\(n)", course: c, stage: 1, label: label,
                                          title: "كتبت تقرير درس \(n)", meta: nil, done: true, num: n))
                }
                if c.backlog > 0 {
                    let n = c.stageB + 1
                    out.append(LessonTask(id: "\(c.id)-report", course: c, stage: 1, label: label,
                                          title: "اكتب تقرير درس \(n)", meta: c.backlog > 1 ? "عليك \(c.backlog) تقرير" : nil,
                                          warn: c.backlog > 1, done: false, num: n))
                }
            case .recording:
                let label = "\(c.title) · \(c.book)"
                for n in logs(on: today, course: c.id, stage: 0) {
                    out.append(LessonTask(id: "\(c.id)-write-\(n)", course: c, stage: 0, label: label,
                                          title: "سمعت وكتبت درس \(n)", meta: nil, done: true, num: n))
                }
                if c.backlog > 0 {
                    let n = c.stageA + 1
                    var parts: [String] = []
                    var warn = false
                    if let since = dateOf(c, num: n), since < today {
                        let k = DateKit.diff(since, today)
                        parts.append(k == 1 ? "باقي من أمس" : "باقي من \(k) يوم")
                        warn = true
                    }
                    if c.backlog > 1 { parts.append("عليك \(c.backlog) درس") }
                    out.append(LessonTask(id: "\(c.id)-write", course: c, stage: 0, label: label,
                                          title: "اسمع واكتب درس \(n)", meta: parts.isEmpty ? nil : parts.joined(separator: " · "),
                                          warn: warn, done: false, num: n))
                }
            }
        }
        return out
    }

    /// رقم درس التدريس بيوم جاي (أو اليوم)
    func teachNumber(_ c: Course, on day: String) -> Int? {
        guard c.mode == .teach, held(c, day) else { return nil }
        if day == today && logs(on: today, course: c.id, stage: 1).isEmpty { return c.nextTeach }
        var k = nextTeachDay(c)
        guard day >= k else { return nil }
        var n = c.nextTeach
        while k < day {
            k = DateKit.add(1, to: k)
            if held(c, k) { n += 1 }
        }
        return n
    }

    /// يوم درس تدريس معين (من الدروس الجاية)
    func teachDay(_ c: Course, num: Int) -> String? {
        guard c.mode == .teach, num >= c.nextTeach else { return nil }
        var day = nextTeachDay(c)
        var n = c.nextTeach
        for _ in 0..<120 {
            if n == num { return day }
            day = DateKit.add(1, to: day)
            if held(c, day) { n += 1 }
        }
        return nil
    }

    /// الضغط على مهمة: إذا ما خلصت تنحسب، وإذا خلصت (وهي آخر وحدة) ترجع
    func toggleTask(_ t: LessonTask) {
        guard let c = course(t.course.id) else { return }
        if t.done {
            let cur = t.stage == 0 ? c.stageA : c.stageB
            if cur == t.num { bump(c.id, stage: t.stage, by: -1) }
        } else {
            bump(c.id, stage: t.stage, by: 1)
        }
    }

    // MARK: - التراجع

    @Published var toast: UndoToast?
    private var undoData: LifeData?

    /// أي شي ينسوى من هني يطلع تحته «تم · تراجع»
    func act(_ text: String, _ f: () -> Void) {
        let before = d
        f()
        guard before != d else { return }
        undoData = before
        toast = UndoToast(text: text)
    }

    func undo() {
        guard let b = undoData else { return }
        d = b
        undoData = nil
        toast = nil
        save()
        LifeNotifier.schedule(self)
    }

    func logs(on day: String, course: String, stage: Int) -> [Int] {
        d.lessonLogs.filter { $0.day == day && $0.course == course && $0.stage == stage }.map(\.num).sorted()
    }

    /// يوم الدرس القادم للتدريس
    func nextTeachDay(_ c: Course) -> String {
        var day = today
        let past = (LFmt.minutesOf(c.time) ?? 0) + 60 <= Self.nowMinutes()
        for i in 0..<14 {
            day = DateKit.add(i, to: today)
            if held(c, day) && !(i == 0 && past) { return day }
        }
        return day
    }

    /// تاريخ تقريبي لدرس معين (نرجع من آخر يوم انحسب على أيام الدرس)
    func dateOf(_ c: Course, num: Int) -> String? {
        guard c.mode != .teach, num <= c.released else { return nil }
        var left = c.released - num
        var day = c.asOf
        for _ in 0..<400 {
            if held(c, day) {
                if left == 0 { return day }
                left -= 1
            }
            day = DateKit.add(-1, to: day)
        }
        return nil
    }

    /// كل المتأخر بسطر واحد لكل مادة
    var lateLines: [LateLine] {
        var out: [LateLine] = []
        for c in d.courses {
            switch c.mode {
            case .recording:
                if c.backlog > 0 { out.append(LateLine(course: c, text: "\(c.backlog) درس ما انسمع وانكتب", count: c.backlog)) }
            case .online:
                if c.backlog > 0 { out.append(LateLine(course: c, text: "\(c.backlog) تقرير ما انكتب", count: c.backlog)) }
            case .teach:
                if !c.nextPrepared {
                    let day = nextTeachDay(c)
                    let n = DateKit.diff(today, day)
                    if n <= 1 { out.append(LateLine(course: c, text: "درس \(c.nextTeach) ما تحضّر · " + DateKit.countdown(from: today, to: day), count: 1)) }
                }
            }
        }
        return out
    }

    // MARK: - الشغل

    func workMinutes(_ p: WorkProject, week: String) -> Int {
        (0..<7).reduce(0) { $0 + (p.logs[DateKit.add($1, to: week)] ?? 0) }
    }

    func logWork(_ id: String, minutes: Int) {
        guard let i = d.work.firstIndex(where: { $0.id == id }) else { return }
        let v = max(0, (d.work[i].logs[today] ?? 0) + minutes)
        d.work[i].logs[today] = v == 0 ? nil : v
        save()
    }

    // MARK: - الجدول

    func isOn(_ e: WeeklyEvent, day: String) -> Bool {
        guard e.day == DateKit.weekday(day) else { return false }
        guard e.everyOtherWeek, let ref = e.onWeekOf else { return true }
        let weeks = DateKit.diff(ref, DateKit.weekStart(day)) / 7
        return weeks % 2 == 0
    }

    func workout(on day: String) -> WorkoutDay? {
        d.workouts.first { $0.weekday == DateKit.weekday(day) }
    }

    func events(on day: String) -> [DayEvent] {
        let wd = DateKit.weekday(day)
        var out: [DayEvent] = []

        for c in d.courses where c.mode != .recording && c.days.contains(wd) {
            let t = LFmt.minutesOf(c.time) ?? 600
            let title = c.mode == .teach ? "تدريس \(c.title)" : "درس \(c.shortName)"
            var detail: String? = c.mode == .online ? "أونلاين" : nil
            if c.mode == .online, let n = lessonNumber(c, on: day) { detail = "درس \(n)" }
            if c.mode == .teach, let n = teachNumber(c, on: day) {
                detail = "درس \(n)" + (n == c.nextTeach && !c.nextPrepared ? " · ما تحضّر" : "")
            }
            if c.mode == .teach, let n = logs(on: day, course: c.id, stage: 1).last { detail = "درس \(n) · درّسته" }
            if isOff(c, day) { detail = "ماكو درس" }
            out.append(DayEvent(id: "c-\(c.id)-\(day)", sortMin: t, when: DateKit.timeLabel(c.time) ?? "",
                                title: title, detail: detail, kind: c.mode == .teach ? .teach : .lesson))
        }
        if let w = workout(on: day) {
            out.append(DayEvent(id: "gym-\(day)", sortMin: 480, when: "الصبح",
                                title: "النادي · \(w.kind)", detail: nil, kind: .gym))
        }
        for e in d.weekly where isOn(e, day: day) {
            // إذا في موعد خاص بنفس العنوان ونفس اليوم، الموعد الخاص يغني عنه
            if d.special.contains(where: { $0.day == day && $0.title == e.title }) { continue }
            out.append(DayEvent(id: "w-\(e.id)-\(day)", sortMin: slotMin(e.slot), when: e.slot,
                                title: e.title, detail: e.detail, kind: e.kind))
        }
        for s in d.special where s.day == day {
            out.append(DayEvent(id: "s-\(s.id)", sortMin: LFmt.minutesOf(s.time) ?? 1110,
                                when: DateKit.timeLabel(s.time) ?? "اليوم", title: s.title, detail: s.note,
                                kind: .special, status: s.status))
        }
        return out.sorted { $0.sortMin < $1.sortMin }
    }

    private func slotMin(_ s: String) -> Int {
        switch s {
        case "الصبح": return 480
        case "الظهر": return 750
        case "العصر": return 960
        default: return 1230
        }
    }

    /// «اليوم ماكو درس»: الدرس انلغى هاليوم
    func isOff(_ c: Course, _ day: String) -> Bool { d.noLesson[day]?.contains(c.id) ?? false }

    /// في درس فعلاً بهاليوم (يومه، وما انلغى)
    func held(_ c: Course, _ day: String) -> Bool { c.days.contains(DateKit.weekday(day)) && !isOff(c, day) }

    func toggleNoLesson(_ c: Course, _ day: String) {
        var l = d.noLesson[day] ?? []
        if let i = l.firstIndex(of: c.id) { l.remove(at: i) } else { l.append(c.id) }
        d.noLesson[day] = l.isEmpty ? nil : l
        save()
        LifeNotifier.schedule(self)
    }

    /// رقم درس الفرائد بيوم معين (للأيام اللي طافت والجاية)
    func lessonNumber(_ c: Course, on day: String) -> Int? {
        guard held(c, day) else { return nil }
        if day <= c.asOf {
            var n = c.released
            var k = c.asOf
            while k > day {
                if held(c, k) { n -= 1 }
                k = DateKit.add(-1, to: k)
            }
            return n
        }
        var n = c.released
        var k = DateKit.add(1, to: c.asOf)
        while k <= day {
            if held(c, k) { n += 1 }
            k = DateKit.add(1, to: k)
        }
        return n
    }

    /// المواعيد الخاصة بالترتيب: اللي جاية أول، وبعدها اللي ما لها يوم، وبعدها اللي طافت
    var specialSorted: [SpecialAppt] {
        let up = d.special.filter { ($0.day ?? "") >= today }.sorted { ($0.day ?? "") < ($1.day ?? "") }
        let noDay = d.special.filter { $0.day == nil }
        let past = d.special.filter { if let k = $0.day { return k < today } else { return false } }
        return up + noDay + past
    }

    func setApptNote(_ id: String, _ t: String) {
        guard let i = d.special.firstIndex(where: { $0.id == id }) else { return }
        d.special[i].note = t.isEmpty ? nil : t
        save()
    }

    func setStatus(_ id: String, _ s: ApptStatus) {
        guard let i = d.special.firstIndex(where: { $0.id == id }) else { return }
        d.special[i].status = s
        save()
    }

    // MARK: - النادي

    func gymLog(_ day: String) -> GymLog { d.gymLogs[day] ?? GymLog() }

    func setLog(_ day: String, _ ex: Exercise, _ i: Int) -> SetLog {
        gymLog(day).sets["\(ex.id)#\(i)"] ?? SetLog()
    }

    func isSetDone(_ day: String, _ ex: Exercise, _ i: Int) -> Bool {
        // الجولة تخلص لما تضغط الدائرة بس (كتابة العدات ما تعلّمها)
        return setLog(day, ex, i).done
    }

    func updateSet(_ day: String, _ ex: Exercise, _ i: Int, _ f: (inout SetLog) -> Void) {
        var g = gymLog(day)
        var s = g.sets["\(ex.id)#\(i)"] ?? SetLog()
        f(&s)
        g.sets["\(ex.id)#\(i)"] = s
        d.gymLogs[day] = g
        save()
    }

    /// الضغط على رقم الجولة: تم أو لا. إذا تم وما كتبت عدات، تنحط عدات الخطة
    func toggleSet(_ day: String, _ ex: Exercise, _ i: Int) {
        let was = isSetDone(day, ex, i)
        updateSet(day, ex, i) { s in
            if was { s.done = false }
            else {
                s.done = true
                if s.w == nil { s.w = ex.sets[i].weight }
            }
        }
    }

    func updateGym(_ day: String, _ f: (inout GymLog) -> Void) {
        var g = gymLog(day)
        f(&g)
        d.gymLogs[day] = g
        save()
    }

    func toggleWalk(_ day: String) { updateGym(day) { $0.walk.toggle() } }

    func setPool(_ day: String, _ min: Int?) { updateGym(day) { $0.poolMin = min } }

    func setsDone(_ day: String, _ w: WorkoutDay) -> (done: Int, total: Int) {
        let total = w.exercises.reduce(0) { $0 + $1.sets.count }
        let done = w.exercises.reduce(0) { acc, ex in
            acc + ex.sets.indices.filter { isSetDone(day, ex, $0) }.count
        }
        return (done, total)
    }

    /// آخر مرة سويت التمرين قبل هاليوم
    func previous(_ ex: Exercise, before day: String) -> (day: String, sets: [SetLog])? {
        let days = d.gymLogs.keys.filter { $0 < day }.sorted(by: >)
        for k in days {
            guard let g = d.gymLogs[k] else { continue }
            let list = ex.sets.indices.compactMap { g.sets["\(ex.id)#\($0)"] }.filter { $0.done || ($0.r ?? 0) > 0 }
            if !list.isEmpty { return (k, list) }
        }
        return nil
    }

    /// أعلى وزن بكل حصة للتمرين (من الأقدم للأحدث)
    func history(_ ex: Exercise, limit: Int = 6) -> [(day: String, top: Double)] {
        var out: [(day: String, top: Double)] = []
        for k in d.gymLogs.keys.sorted() {
            guard let g = d.gymLogs[k] else { continue }
            let ws = ex.sets.indices.compactMap { i -> Double? in
                guard let s = g.sets["\(ex.id)#\(i)"], s.done || (s.r ?? 0) > 0 else { return nil }
                return s.w ?? ex.sets[i].weight
            }
            if let m = ws.max() { out.append((day: k, top: m)) }
        }
        return Array(out.suffix(limit))
    }

    /// سجل اليوم كنص، عشان ينرسل لـClaude يعدل الخطة
    func gymText(_ day: String, _ w: WorkoutDay) -> String {
        let g = gymLog(day)
        var lines = ["سجل النادي · \(DateKit.long(day)) · \(w.title)"]
        lines.append("المشي: " + (g.walk ? "تم" : "ما تم") + (g.walkNote.isEmpty ? "" : " · " + g.walkNote))
        for ex in w.exercises {
            let parts = ex.sets.indices.map { i -> String in
                let s = g.sets["\(ex.id)#\(i)"] ?? SetLog()
                guard s.done || (s.r ?? 0) > 0 else { return "—" }
                var t = LFmt.weight(s.w ?? ex.sets[i].weight) + "×" + (s.r.map(String.init) ?? ex.sets[i].reps)
                if let rir = s.rir { t += " (باقي \(rir))" }
                return t
            }
            var line = ex.name + ": " + parts.joined(separator: "، ")
            if let n = g.notes[ex.id], !n.isEmpty { line += " · ملاحظة: " + n }
            lines.append(line)
        }
        if let p = g.poolMin { lines.append("الحوض: \(p) د") }
        if !g.dayNote.isEmpty { lines.append("ملاحظات اليوم: " + g.dayNote) }
        return lines.joined(separator: "\n")
    }

    /// جولات الأسبوع لكل عضلة: (تم، مخطط)
    func muscleVolume(week: String) -> [MuscleRow] {
        var order: [String] = []
        var plan: [String: Int] = [:], done: [String: Int] = [:]
        for i in 0..<7 {
            let day = DateKit.add(i, to: week)
            guard let w = workout(on: day) else { continue }
            for ex in w.exercises {
                if plan[ex.muscle] == nil { order.append(ex.muscle) }
                plan[ex.muscle, default: 0] += ex.sets.count
                done[ex.muscle, default: 0] += ex.sets.indices.filter { isSetDone(day, ex, $0) }.count
            }
        }
        return order.map { MuscleRow(muscle: $0, done: done[$0] ?? 0, plan: plan[$0] ?? 0) }
    }

    // MARK: - الصحة

    func health(_ day: String) -> DayHealth { d.health[day] ?? DayHealth() }


    func toggleHealth(_ key: WritableKeyPath<DayHealth, Bool>) {
        var h = health(today)
        h[keyPath: key].toggle()
        d.health[today] = h
        save()
    }

    var lastNight: NightLog? { d.nights.first { $0.day == today } ?? d.nights.sorted { $0.day > $1.day }.first }

    var nightsSorted: [NightLog] { d.nights.sorted { $0.day > $1.day } }

    func setHealthNote(_ day: String, _ t: String) {
        var h = health(day)
        h.note = t
        d.health[day] = h
        save()
    }

    func setNightNote(_ day: String, _ t: String) {
        guard let i = d.nights.firstIndex(where: { $0.day == day }) else { return }
        d.nights[i].note = t
        save()
    }

    /// المطارة بالسيارة، وأيام النادي فيها الإلكترولايت: مهمة وحدة
    func toggleBottle() {
        var h = health(today)
        h.bottle.toggle()
        if workout(on: today) != nil { h.electrolyte = h.bottle }
        d.health[today] = h
        save()
    }

    // MARK: - القعدة من النوم

    var todayNight: NightLog? { d.nights.first { $0.day == today } }

    func setNight(day: String, sleep: String, wake: String) {
        if let i = d.nights.firstIndex(where: { $0.day == day }) {
            d.nights[i].sleep = sleep
            d.nights[i].wake = wake
        } else {
            d.nights.append(NightLog(day: day, sleep: sleep, wake: wake))
        }
        save()
    }

    // MARK: - ملخص اليوم

    /// جملة وحدة: «اليوم عندك كذا وكذا وكذا»
    var summaryLine: String {
        let ev = events(on: today).filter { $0.kind != .prep }
        guard !ev.isEmpty else { return "اليوم ما عندك شي بالجدول" }
        let names = ev.map { e -> String in
            switch e.kind {
            case .gym: return "النادي"
            case .lesson: return "درس \(e.title)"
            case .teach: return e.title
            default: return e.title
            }
        }
        var line = "اليوم عندك "
        if names.count == 1 { line += names[0] }
        else { line += names.dropLast().joined(separator: "، ") + " و" + (names.last ?? "") }
        return line
    }

    func dayNote(_ day: String) -> String { d.dayNotes[day] ?? "" }

    func setDayNote(_ day: String, _ t: String) {
        d.dayNotes[day] = t.isEmpty ? nil : t
        save()
    }

    // MARK: - خطوات الشغل

    var remainingSteps: [WorkStep] { d.workSteps.filter { $0.status != .done }.sorted { $0.num < $1.num } }
    var doneSteps: [WorkStep] { d.workSteps.filter { $0.status == .done }.sorted { $0.num < $1.num } }
    /// كل شي ينتظرني: قرار أو قعدة أو شي بيدي
    var stepsNeedingMe: [WorkStep] {
        d.workSteps.filter { $0.decision != nil || $0.waitingOn != nil }.sorted { $0.num < $1.num }
    }

    // MARK: - أرشيف النادي

    /// كل أسبوع فيه نادي: الحصص والجولات (من الأحدث)
    var gymWeeks: [GymWeek] {
        var map: [String: [String]] = [:]
        for k in d.gymLogs.keys where workout(on: k) != nil { map[DateKit.weekStart(k), default: []].append(k) }
        return map.keys.sorted(by: >).map { (w: String) -> GymWeek in
            let days = (map[w] ?? []).sorted()
            var done = 0, total = 0
            for k in days {
                guard let wo = workout(on: k) else { continue }
                let s = setsDone(k, wo)
                done += s.done
                total += s.total
            }
            let sessions = days.filter { k in workout(on: k).map { setsDone(k, $0).done > 0 } ?? false }.count
            return GymWeek(start: w, days: days, sessions: sessions, setsDone: done, setsTotal: total)
        }
    }

    /// أعلى وزن بكل أسبوع لكل تمرين (من الأقدم)
    func weeklyTop(_ ex: Exercise) -> [(week: String, top: Double)] {
        var m: [String: Double] = [:]
        for (k, g) in d.gymLogs {
            for i in ex.sets.indices {
                guard let s = g.sets["\(ex.id)#\(i)"], s.done || (s.r ?? 0) > 0 else { continue }
                let w = s.w ?? ex.sets[i].weight
                let wk = DateKit.weekStart(k)
                m[wk] = max(m[wk] ?? 0, w)
            }
        }
        return m.keys.sorted().map { (week: $0, top: m[$0] ?? 0) }
    }

    /// كل التمارين بدون تكرار
    var allExercises: [Exercise] {
        var seen = Set<String>()
        var out: [Exercise] = []
        for w in d.workouts { for e in w.exercises where !seen.contains(e.id) { seen.insert(e.id); out.append(e) } }
        return out
    }

    // MARK: - الأخبار

    func setRating(_ id: String, _ r: Int?) {
        guard let i = d.news.firstIndex(where: { $0.id == id }) else { return }
        d.news[i].rating = r
        save()
    }

    func markRead(_ id: String) {
        guard let i = d.news.firstIndex(where: { $0.id == id }) else { return }
        d.news[i].read = true
        save()
    }

    // MARK: - الدفتر

    var unsent: [InboxNote] { d.inbox.filter { !$0.sent }.sorted { $0.created < $1.created } }

    func addNote(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        d.inbox.append(InboxNote(id: UUID().uuidString, text: t, created: Date()))
        save()
    }

    func deleteNote(_ id: String) {
        d.inbox.removeAll { $0.id == id }
        save()
    }

    func markAllSent() {
        for i in d.inbox.indices { d.inbox[i].sent = true }
        save()
    }

    /// النص اللي ينرسل لـClaude
    var exportText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar@numbers=latn")
        f.timeZone = DateKit.tz
        f.dateFormat = "EEEE d MMMM، h:mm a"
        var lines = ["ملاحظات من تطبيق أنا، رتبها بالجدول:"]
        for n in unsent { lines.append("- (\(f.string(from: n.created))) \(n.text)") }
        return lines.joined(separator: "\n")
    }
}
