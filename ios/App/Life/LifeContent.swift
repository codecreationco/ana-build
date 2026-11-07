import Foundation

// المحتوى اللي تكتبه المحادثات بالجداول (المواد، الدروس، النادي، وزان، الطلعات، المواعيد).
// التطبيق يقراه بس، ويدمجه مع اللي سجله حسن (الأعلى بين رقم المحادثة وتسجيل حسن).

struct ContentDoc: Decodable {
    var courses: [CCourse] = []
    var lessons: [CLesson] = []
    var gymDays: [CGymDay] = []
    var workSteps: [CStep] = []
    var workDecisions: [CDecision] = []
    var weekly: [CWeekly] = []
    var appointments: [CAppt] = []
    var books: [CBook] = []

    enum CodingKeys: String, CodingKey { case courses, lessons, gymDays, workSteps, workDecisions, weekly, appointments, books }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courses = (try? c.decode([CCourse].self, forKey: .courses)) ?? []
        lessons = (try? c.decode([CLesson].self, forKey: .lessons)) ?? []
        gymDays = (try? c.decode([CGymDay].self, forKey: .gymDays)) ?? []
        workSteps = (try? c.decode([CStep].self, forKey: .workSteps)) ?? []
        workDecisions = (try? c.decode([CDecision].self, forKey: .workDecisions)) ?? []
        weekly = (try? c.decode([CWeekly].self, forKey: .weekly)) ?? []
        appointments = (try? c.decode([CAppt].self, forKey: .appointments)) ?? []
        books = (try? c.decode([CBook].self, forKey: .books)) ?? []
    }
}

struct CCourse: Decodable {
    var id: String
    var title: String
    var nick: String?
    var book: String?
    var kind: String
    var days: [Int]?
    var time: String?
    var link: String?
    var endsOn: String?
    var lastReceived: Int?
    var lastAttended: Int?
    var lastTaught: Int?
    var preparedUpto: Int?
    var reportUpto: Int?
    var reportNext: Int?
    var reportLastText: String?
    var reportLeft: Int?
    var nextNote: String?
}

struct CLesson: Decodable {
    var courseId: String
    var num: Int
    var title: String?
    var section: String?
    var summary: String?
    var points: [String]?
    var textRef: String?
    var textRead: Bool?
    var page: String?
    var reportStatus: String?
    var reportNote: String?
    var prepStatus: String?
    var missing: Bool?
    var note: String?
}

struct CGymDay: Decodable {
    struct Walk: Decodable { var min: Int?; var speed: Double? }
    struct Ex: Decodable {
        struct S: Decodable { var setNo: Int; var weight: Double?; var reps: String?; var rir: String?; var warmup: Bool? }
        var exKey: String
        var name: String
        var nameAr: String?
        var muscle: String?
        var grp: String?
        var unit: String?
        var restSec: Int?
        var cue: String?
        var lastTime: String?
        var machine: String?
        var sets: [S]?
    }
    var day: String
    var kind: String
    var title: String?
    var coach: String?
    var walk: [Walk]?
    var pool: Bool?
    var warmup: [String]?
    var exercises: [Ex]?
}

struct CStep: Decodable {
    var num: Int
    var title: String
    var status: String
    var why: String?
    var waitingOn: String?
}

struct CDecision: Decodable {
    var id: Int
    var stepNum: Int?
    var question: String
    var decision: String?
    var decidedOn: String?
}

struct CWeekly: Decodable {
    var id: String
    var title: String
    var weekday: Int
    var everyWeeks: Int?
    var anchor: String?
    var time: String?
    var slot: String?
    var detail: String?
    var kind: String?
}

struct CBook: Decodable {
    var id: String
    var title: String
    var author: String?
    var totalPages: Int?
    var startPage: Int?
}

struct CAppt: Decodable {
    var id: String
    var day: String?
    var time: String?
    var title: String
    var note: String?
    var status: String?
}

extension LifeSync {
    static func content() async throws -> ContentDoc {
        let o = try await rpc("get_content", ["p_key": DeviceKey.get()])
        let data = try JSONSerialization.data(withJSONObject: o)
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(ContentDoc.self, from: data)
    }
}

extension LifeStore {
    /// يحط محتوى المحادثات مكان القديم، ويخلي تسجيلات حسن وملاحظاته
    func applyContent(_ c: ContentDoc) {
        let today = self.today
        let yesterday = DateKit.add(-1, to: today)
        let oldCourses = Dictionary(uniqueKeysWithValues: d.courses.map { ($0.id, $0) })

        var courses: [Course] = []
        for cc in c.courses {
            let mode: CourseMode = cc.kind == "teach" ? .teach : (cc.kind == "online" ? .online : .recording)
            var info: [String: LessonInfo] = [:]
            for l in c.lessons where l.courseId == cc.id {
                var i = LessonInfo(topic: l.title ?? l.section, summary: l.summary, points: l.points ?? [],
                                   note: oldCourses[cc.id]?.info[String(l.num)]?.note)
                i.section = l.section
                i.textRef = l.textRef
                i.report = l.reportStatus
                i.reportNote = l.reportNote
                i.missing = l.missing
                info[String(l.num)] = i
            }
            // ملاحظات حسن على دروس ما لها سطر بالجدول
            for (k, v) in oldCourses[cc.id]?.info ?? [:] where info[k] == nil && v.note != nil {
                info[k] = LessonInfo(note: v.note)
            }
            let logged0 = d.lessonLogs.filter { $0.course == cc.id && $0.stage == 0 }.map(\.num).max() ?? 0
            let logged1 = d.lessonLogs.filter { $0.course == cc.id && $0.stage == 1 }.map(\.num).max() ?? 0
            let reportDone = (cc.reportNext.map { $0 - 1 } ?? cc.reportUpto) ?? 0
            var co: Course
            switch mode {
            case .teach:
                let taught = max(cc.lastTaught ?? 0, logged1)
                co = Course(id: cc.id, title: cc.title, book: cc.book ?? "", mode: .teach, days: cc.days ?? [], time: cc.time,
                            released: taught, stageA: max(cc.preparedUpto ?? 0, logged0), stageB: taught,
                            startNum: 1, asOf: today, info: info)
            case .online:
                let attended = max(cc.lastAttended ?? 0, logged0)
                co = Course(id: cc.id, title: cc.title, book: cc.book ?? "", mode: .online, days: cc.days ?? [], time: cc.time,
                            released: max(cc.lastReceived ?? 0, attended), stageA: attended, stageB: max(reportDone, logged1),
                            startNum: max(1, (cc.lastReceived ?? 0) - 40), asOf: yesterday, info: info)
            case .recording:
                co = Course(id: cc.id, title: cc.title, book: cc.book ?? "", mode: .recording, days: cc.days ?? [], time: cc.time,
                            released: cc.lastReceived ?? 0, stageA: max(reportDone, logged0), stageB: 0,
                            startNum: max(1, (cc.lastReceived ?? 0) - 40), asOf: today, info: info)
            }
            co.nick = cc.nick
            co.link = cc.link
            co.endsOn = cc.endsOn
            co.nextNote = cc.nextNote
            co.reportLastText = cc.reportLastText
            courses.append(co)
        }
        d.courses = courses

        // النادي: أيام هالأسبوع (كل يوم بأسبوعه)
        let week = DateKit.weekStart(today)
        d.workouts = c.gymDays.filter { $0.day >= week && $0.day <= DateKit.add(6, to: week) }.compactMap { (g: CGymDay) -> WorkoutDay? in
            let ex: [Exercise] = (g.exercises ?? []).map { (e: CGymDay.Ex) -> Exercise in
                Exercise(id: e.exKey, name: e.name, ar: e.nameAr ?? e.muscle ?? "", muscle: e.grp ?? e.muscle ?? "",
                         cue: e.cue, unit: e.unit ?? "kg",
                         sets: (e.sets ?? []).filter { !($0.warmup ?? false) }.map { (s: CGymDay.Ex.S) -> SetPlan in
                             SetPlan(weight: s.weight ?? 0, reps: s.reps ?? "", rir: s.rir ?? "")
                         },
                         rest: e.restSec, lastTime: e.lastTime, machine: e.machine)
            }
            guard !ex.isEmpty || !(g.walk ?? []).isEmpty else { return nil }
            return WorkoutDay(id: g.day, weekday: DateKit.weekday(g.day), kind: g.kind, title: g.title ?? g.kind,
                              coach: g.coach, walk: (g.walk ?? []).map { WalkSeg(min: $0.min ?? 0, speed: $0.speed ?? 0) },
                              exercises: ex, pool: g.pool ?? false)
        }

        // وزان ماث
        d.workSteps = c.workSteps.map { (s: CStep) -> WorkStep in
            let open = c.workDecisions.filter { $0.stepNum == s.num && ($0.decision ?? "").isEmpty }.map(\.question)
            return WorkStep(id: "s\(s.num)", num: s.num, title: s.title,
                            status: StepStatus(rawValue: s.status) ?? .todo, why: s.why ?? "",
                            waitingOn: s.waitingOn, decision: open.isEmpty ? nil : open.joined(separator: " · "))
        }
        d.workDecisions = c.workDecisions.filter { !($0.decision ?? "").isEmpty }.map {
            WorkDecision(step: $0.stepNum, question: $0.question, decision: $0.decision ?? "", day: $0.decidedOn)
        }

        // الطلعات
        d.weekly = c.weekly.map { (w: CWeekly) -> WeeklyEvent in
            let kind: EventKind = w.kind == "family" ? .family : .social
            return WeeklyEvent(id: w.id, day: w.weekday, title: w.title, detail: w.detail, slot: w.slot ?? "بليل", kind: kind,
                               everyOtherWeek: (w.everyWeeks ?? 1) == 2,
                               onWeekOf: w.anchor.map { DateKit.weekStart($0) })
        }

        // الكتب: العنوان من الجدول، والصفحات اللي سجلها حسن تبقى
        let oldBooks = Dictionary(uniqueKeysWithValues: d.books.map { ($0.id, $0) })
        d.books = c.books.map { (b: CBook) -> Book in
            var book = oldBooks[b.id] ?? Book(id: b.id, title: b.title, author: b.author ?? "", total: b.totalPages ?? 0,
                                              page: max(0, (b.startPage ?? 1) - 1))
            book.title = b.title
            book.author = b.author ?? ""
            book.total = b.totalPages ?? 0
            return book
        }

        // المواعيد
        d.special = c.appointments.map {
            SpecialAppt(id: $0.id, day: $0.day, time: $0.time, title: $0.title, note: $0.note,
                        status: ApptStatus(rawValue: $0.status ?? "confirmed") ?? .confirmed)
        }
    }
}
