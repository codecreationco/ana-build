import Foundation

// كل بيانات التطبيق الحين محلية على التلفون (بيانات تجريبية).
// لما نربط قاعدة البيانات، نفس الأشكال تنحفظ هناك.

// MARK: - الدروس

enum CourseMode: String, Codable {
    case teach       // تدريس: تحضير ← تدريس
    case online      // درس أحضره: حضور ← تقرير
    case recording   // تسجيل يوصلني: سماع وكتابة بخطوة وحدة
}

struct Course: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var book: String
    var mode: CourseMode
    var days: [Int]            // 1 = الأحد … 7 = السبت
    var time: String?          // "17:45"
    var released: Int          // آخر درس انعقد أو وصل تسجيله
    var stageA: Int            // تدريس: آخر درس حضّرته · أونلاين: آخر درس حضرته · تسجيل: آخر درس كتبته
    var stageB: Int            // تدريس: آخر درس درّسته · أونلاين: آخر تقرير
    var startNum: Int          // من وين نبدأ العرض
    var asOf: String           // آخر يوم انحسب فيه «released»
    var info: [String: LessonInfo] = [:]   // رقم الدرس ← موضوعه وتفاصيله
    var endsOn: String? = nil      // آخر يوم بالكورس (إذا معروف)، للشبكة
    var firstLesson: Int? = nil   // أول درس بالمادة (الظن يبدأ من 78)، ما نعرض اللي قبله
    var nick: String? = nil        // اسم قصير: «الأصول» بدال «فرائد الأصول»
    var link: String? = nil        // رابط الدرس (Zoom، Meet…)
    var nextNote: String? = nil    // من المحادثة: شي عن الدرس الجاي
    var reportLastText: String? = nil   // آخر عبارة انكتبت بالتقرير

    var shortName: String { nick ?? title }

    var stageNames: [String] {
        switch mode {
        case .teach: return ["تحضير", "تدريس"]
        case .online: return ["حضور", "تقرير"]
        case .recording: return ["سماع وكتابة"]
        }
    }

    var modeLabel: String {
        switch mode {
        case .teach: return "تدريس"
        case .online: return "أونلاين"
        case .recording: return "تسجيل يوصل كل يوم"
        }
    }

    /// كم درس متأخر (حسب نوع المادة)
    var backlog: Int {
        switch mode {
        case .teach: return 0
        case .online: return max(0, stageA - stageB)
        case .recording: return max(0, released - stageA)
        }
    }

    /// دروس فاتتني (أونلاين)
    var missed: Int { mode == .online ? max(0, released - stageA) : 0 }

    var nextTeach: Int { stageB + 1 }
    var nextPrepared: Bool { stageA >= stageB + 1 }

    func topic(_ n: Int) -> String? { info[String(n)]?.topic }
}

/// تفاصيل درس: الموضوع والملخص والنقاط (تنضاف من المحادثات)، وملاحظتي
struct LessonInfo: Codable, Hashable {
    var topic: String? = nil
    var summary: String? = nil
    var points: [String] = []
    var note: String? = nil
    var section: String? = nil      // العنوان الكبير (مثل «خيار الغبن»)
    var textRef: String? = nil      // موضعه من المتن
    var report: String? = nil       // حالة التقرير من المحادثة
    var reportNote: String? = nil
    var missing: Bool? = nil        // الدرس نفسه مفقود
    var details: String? = nil      // فقرة: شنو يتكلم الدرس وشنو المسائل
    var textFrom: String? = nil     // أول عبارة من المتن بالدرس
    var textTo: String? = nil       // آخر عبارة
    var page: String? = nil

    /// شنو يغطي من المتن، بسطر وحدة
    var coverage: String? {
        var parts: [String] = []
        if let a = textFrom, let b = textTo { parts.append("من «\(a)» لين «\(b)»") }
        else if let r = textRef { parts.append(r) }
        if let p = page, !p.isEmpty { parts.append(p.hasPrefix("ص") ? p : "ص" + p) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// قرار انخذ بخطوة من خطوات الشغل
struct WorkDecision: Codable, Hashable {
    var step: Int?
    var question: String
    var decision: String
    var day: String?
}

/// سجل كل خطوة: يوم شنو انسوى، عشان الشبكة توري الأرقام
struct LessonLog: Codable, Hashable {
    let day: String
    let course: String
    let stage: Int      // 0 = الخطوة الأولى، 1 = الثانية
    let num: Int
}

// MARK: - الشغل

struct WorkProject: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var weeklyTargetMin: Int
    var logs: [String: Int]    // اليوم ← دقايق
}

// MARK: - الأسبوع والمواعيد

enum EventKind: String, Codable {
    case lesson, teach, gym, social, family, special, work, prep
}

struct WeeklyEvent: Codable, Identifiable, Hashable {
    let id: String
    var day: Int               // 1 = الأحد … 7 = السبت
    var title: String
    var detail: String?
    var slot: String           // "الصبح" / "العصر" / "بالليل"
    var kind: EventKind
    var everyOtherWeek: Bool = false
    var onWeekOf: String? = nil   // أسبوع (سبت) مؤكد فيه، للي أسبوع إيه وأسبوع لا

    /// كلمة وحدة للشبكة
    var short: String {
        if title.contains("ديوان شرف") { return "ديوان" }
        if title.contains("الباحث") { return "باحث" }
        if title.contains("طلعة") { return "طلعة" }
        if title.contains("إخوان") { return "إخوان" }
        return String(title.split(separator: " ").first ?? "")
    }
}

enum ApptStatus: String, Codable, CaseIterable {
    case confirmed, tentative, postponed, cancelled

    var label: String {
        switch self {
        case .confirmed: return "مؤكد"
        case .tentative: return "مو أكيد"
        case .postponed: return "تأجل"
        case .cancelled: return "انلغى"
        }
    }
}

struct SpecialAppt: Codable, Identifiable, Hashable {
    let id: String
    var day: String?           // ممكن ما له يوم (تأجل وما انعرف)
    var time: String?
    var title: String
    var note: String?
    var status: ApptStatus
}

// MARK: - النادي

struct WalkSeg: Codable, Hashable {
    var min: Int
    var speed: Double
}

struct SetPlan: Codable, Hashable {
    var weight: Double
    var reps: String
    var rir: String
}

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    var name: String           // بالإنجليزي مثل اسم الجهاز
    var ar: String
    var muscle: String
    var cue: String?
    var unit: String = "kg"
    var sets: [SetPlan]
    var rest: Int? = nil          // الراحة بالثواني (من محادثة النادي)
    var lastTime: String? = nil   // «آخر مرة: …»
    var machine: String? = nil    // إعدادات الجهاز الثابتة

    var restSec: Int { rest ?? RestTimes.of(id) }
}

struct WorkoutDay: Codable, Identifiable, Hashable {
    let id: String
    var weekday: Int
    var kind: String           // Upper / Lower
    var title: String
    var coach: String?
    var walk: [WalkSeg]
    var exercises: [Exercise]
    var pool: Bool
}

/// جولة وحدة: الوزن والعدات وباقي كم عدة
struct SetLog: Codable, Hashable {
    var w: Double? = nil
    var r: Int? = nil
    var rir: String? = nil
    var done = false
}

struct GymLog: Codable, Hashable {
    var sets: [String: SetLog] = [:]      // "exId#رقم الجولة"
    var notes: [String: String] = [:]     // ملاحظة لكل تمرين
    var dayNote: String = ""
    var walk = false
    var walkNote: String = ""
    var poolMin: Int? = nil
    var walkStart: Double? = nil          // متى بدا المشي (ثواني من 1970)
    var walkHR: [String: Int]? = nil      // النبض عند بداية كل مقطع: "0" البداية، "1" أول تحويل…
    var walkMin: [String: Int]? = nil     // الدقايق الفعلية لكل مقطع إذا غيرها
    var walkSpeed: [String: Double]? = nil  // السرعة الفعلية لكل مقطع إذا غيرها
}

// MARK: - الصحة

struct DayHealth: Codable, Hashable {
    var note: String = ""
    var protein: Int = 0
    var creatine = false       // مع قهوة الصبح
    var electrolyte = false    // بالمطارة أيام النادي
    var bottle = false         // المطارة بالسيارة
}

struct NightLog: Codable, Identifiable, Hashable {
    var id: String { day }
    let day: String            // يوم القعدة
    var sleep: String          // "23:40"
    var wake: String           // "05:20"
    var note: String = ""

    var minutes: Int {
        func m(_ s: String) -> Int {
            let p = s.split(separator: ":").compactMap { Int($0) }
            return p.count >= 2 ? p[0] * 60 + p[1] : 0
        }
        var d = m(wake) - m(sleep)
        if d < 0 { d += 1440 }
        return d
    }
}

// MARK: - أشياء اليوم غير الدروس

/// شي ينسوى باليوم: يتكرر بأيام معينة، أو مرة وحدة بيوم معين
struct Chore: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var sub: String? = nil
    var time: String? = nil        // "07:15"، وإذا فاضي يطلع تحت «بأي وقت»
    var days: [Int] = []           // 1 = الأحد … 7 = السبت
    var day: String? = nil         // لمرة وحدة
    var routine = true
    var timeText: String? = nil    // اللي يطلع بدال الساعة: «7:00 – 7:30»، «قبل الروضة»
}

// MARK: - القراءة

struct Book: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var author: String
    var total: Int
    var page: Int                  // آخر صفحة وصلتها
    var logs: [String: Int] = [:]  // اليوم ← الصفحة اللي وصلتها ذاك اليوم
}

// MARK: - خطة النوم

struct SleepPlan: Codable, Hashable {
    var wake = "06:30"             // القعدة من الأحد لين الخميس
    var alarm = true
    var needMin = 540              // النوم المقترح: 9 ساعات قبل القعدة
    var remindMin = 30             // «تجهز للنوم» قبلها بنص ساعة
    var weekendOn: [String] = []   // جمعة أو سبت شغّلت فيه المنبه
    var weekendTimes: [String: String]? = nil   // وقت منبه الجمعة أو السبت لكل يوم
    var weekendWake: String? = nil              // آخر وقت اخترته للعطلة
}

struct NapLog: Codable, Hashable {
    var min: Int
    var at: String                 // متى سجلتها
}

// MARK: - الأكل

struct FoodEntry: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var grams: Int
    var at: String
}

// MARK: - الصلاة

struct Prayer: Identifiable, Hashable {
    let id: String
    let name: String
    let min: Int                   // وقتها (دقايق من نص الليل)
    var pray = true                // الشروق ومنتصف الليل ما ينصلون
    var end: Int? = nil            // وقت القضاء: الشروق، الغروب، منتصف الليل
    var note: String? = nil        // «الأذان 4:44»
    var time: String { LFmt.hhmm(min) }
}

// MARK: - الأخبار

struct NewsTopic: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var icon: String
}

struct NewsItem: Codable, Identifiable, Hashable {
    let id: String
    var topic: String
    var title: String
    var summary: String
    var source: String
    var platform: String       // telegram / x
    var minutesAgo: Int
    var read = false
    var rating: Int? = nil     // اهتمامي بالخبر من 10 (بالضغط المطول)
}

// MARK: - خطوات الشغل

enum StepStatus: String, Codable {
    case done, doing, waiting, todo

    var label: String {
        switch self {
        case .done: return "خلصت"
        case .doing: return "شغالين عليها"
        case .waiting: return "تنتظر"
        case .todo: return "ما بدت"
        }
    }
}

struct WorkStep: Codable, Identifiable, Hashable {
    let id: String
    var num: Int
    var title: String
    var status: StepStatus
    var why: String
    var waitingOn: String? = nil     // مثلاً «قعدة معك أول»
    var decision: String? = nil      // سؤال يحتاج قرار مني
}

// MARK: - الدفتر

struct InboxNote: Codable, Identifiable, Hashable {
    let id: String
    var text: String
    var created: Date
    var sent = false
}

// MARK: - الكل

struct LifeData: Codable, Equatable {
    var version = 5
    var courses: [Course]
    var lessonLogs: [LessonLog]
    var work: [WorkProject]
    var workSteps: [WorkStep]
    var dayNotes: [String: String] = [:]
    var weekly: [WeeklyEvent]
    var special: [SpecialAppt]
    var workouts: [WorkoutDay]
    var gymLogs: [String: GymLog]
    var health: [String: DayHealth]
    var nights: [NightLog]
    var proteinTarget: Int
    var proteinMin: Int
    var topics: [NewsTopic]
    var news: [NewsItem]
    var inbox: [InboxNote]
    var chores: [Chore] = []
    var choreDone: [String: [String]] = [:]
    var books: [Book] = []
    var sleep = SleepPlan()
    var naps: [String: NapLog] = [:]
    var bedOverride: [String: String] = [:]
    var prayerDone: [String: [String]] = [:]
    var prayerAlarm = true
    var prayerAsk = true
    var food: [String: [FoodEntry]] = [:]
    var workDecisions: [WorkDecision] = []
    var noLesson: [String: [String]] = [:]   // اليوم ← المواد اللي «ماكو درس» فيها (حسن من التطبيق)
    var planOff: [String: [String]] = [:]    // من جدول lesson_changes: ماكو درس
    var planExtra: [String: [String]] = [:]  // من جدول lesson_changes: درس بيوم غير يومه
}

extension LifeData {
    /// بداية فاضية: بدون أي بيانات وهمية
    static var empty: LifeData {
        LifeData(courses: [], lessonLogs: [], work: [], workSteps: [], weekly: [], special: [],
                 workouts: [], gymLogs: [:], health: [:], nights: [],
                 proteinTarget: 110, proteinMin: 100, topics: [], news: [], inbox: [])
    }

    /// قراءة متسامحة: أي جزء ناقص بالملف ياخذ قيمته الافتراضية (عشان أي تعديل من المحادثة ما يخرب التطبيق)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let e = LifeData.empty
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 5
        courses = try c.decodeIfPresent([Course].self, forKey: .courses) ?? []
        lessonLogs = try c.decodeIfPresent([LessonLog].self, forKey: .lessonLogs) ?? []
        work = try c.decodeIfPresent([WorkProject].self, forKey: .work) ?? []
        workSteps = try c.decodeIfPresent([WorkStep].self, forKey: .workSteps) ?? []
        dayNotes = try c.decodeIfPresent([String: String].self, forKey: .dayNotes) ?? [:]
        weekly = try c.decodeIfPresent([WeeklyEvent].self, forKey: .weekly) ?? []
        special = try c.decodeIfPresent([SpecialAppt].self, forKey: .special) ?? []
        workouts = try c.decodeIfPresent([WorkoutDay].self, forKey: .workouts) ?? []
        gymLogs = try c.decodeIfPresent([String: GymLog].self, forKey: .gymLogs) ?? [:]
        health = try c.decodeIfPresent([String: DayHealth].self, forKey: .health) ?? [:]
        nights = try c.decodeIfPresent([NightLog].self, forKey: .nights) ?? []
        proteinTarget = try c.decodeIfPresent(Int.self, forKey: .proteinTarget) ?? e.proteinTarget
        proteinMin = try c.decodeIfPresent(Int.self, forKey: .proteinMin) ?? e.proteinMin
        topics = try c.decodeIfPresent([NewsTopic].self, forKey: .topics) ?? []
        news = try c.decodeIfPresent([NewsItem].self, forKey: .news) ?? []
        inbox = try c.decodeIfPresent([InboxNote].self, forKey: .inbox) ?? []
        chores = try c.decodeIfPresent([Chore].self, forKey: .chores) ?? []
        choreDone = try c.decodeIfPresent([String: [String]].self, forKey: .choreDone) ?? [:]
        books = try c.decodeIfPresent([Book].self, forKey: .books) ?? []
        sleep = try c.decodeIfPresent(SleepPlan.self, forKey: .sleep) ?? SleepPlan()
        naps = try c.decodeIfPresent([String: NapLog].self, forKey: .naps) ?? [:]
        bedOverride = try c.decodeIfPresent([String: String].self, forKey: .bedOverride) ?? [:]
        prayerDone = try c.decodeIfPresent([String: [String]].self, forKey: .prayerDone) ?? [:]
        prayerAlarm = try c.decodeIfPresent(Bool.self, forKey: .prayerAlarm) ?? true
        prayerAsk = try c.decodeIfPresent(Bool.self, forKey: .prayerAsk) ?? true
        food = try c.decodeIfPresent([String: [FoodEntry]].self, forKey: .food) ?? [:]
        workDecisions = try c.decodeIfPresent([WorkDecision].self, forKey: .workDecisions) ?? []
        noLesson = try c.decodeIfPresent([String: [String]].self, forKey: .noLesson) ?? [:]
        planOff = try c.decodeIfPresent([String: [String]].self, forKey: .planOff) ?? [:]
        planExtra = try c.decodeIfPresent([String: [String]].self, forKey: .planExtra) ?? [:]
    }
}

/// شي واحد بصفحة اليوم (درس، مشوار، قراءة…)
enum ItemKind: Hashable {
    case lesson(String)            // id المهمة
    case chore(String)
    case leave                     // قبل لا أطلع: القهوة والمطارة
    case gym
    case book(String)
}

struct TodayItem: Identifiable {
    let id: String
    var time: Int? = nil           // دقايق من نص الليل
    var timeText: String? = nil
    var title: String
    var sub: String? = nil
    var done: Bool
    var routine = true
    var kind: ItemKind
    var stale: Int? = nil          // كم يوم ما انسوى، للاقتراح
    var staleText: String? = nil

    /// 0 الصبح، 1 المسا، 2 بأي وقت
    var slot: Int {
        guard let t = time else { return 2 }
        return t < 720 ? 0 : 1
    }
}

/// السطر اللي تحت أيام الأسبوع بالرئيسية
enum StatusLine: Equatable {
    case wake
    case nap
    case bed
    case prayer(Prayer)
    case lesson(Course)
    case none
}

/// شريط «تم · تراجع» اللي يطلع بعد أي شي تسويه
struct UndoToast: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// يوم بالجدول: كل شي يطلع بيوم معين، من أي مصدر
struct DayEvent: Identifiable, Hashable {
    let id: String
    var sortMin: Int
    var when: String           // "10:00 ص" أو "الصبح"
    var title: String
    var detail: String?
    var kind: EventKind
    var status: ApptStatus? = nil
}

struct GymWeek: Identifiable {
    let start: String
    let days: [String]
    let sessions: Int
    let setsDone: Int
    let setsTotal: Int
    var id: String { start }
}

struct MuscleRow: Identifiable {
    let muscle: String
    let done: Int
    let plan: Int
    var id: String { muscle }
}

/// مهمة درس باليوم. اللي لها عدد (كتابة) تقبل أكثر من وحدة باليوم
/// مهمة درس اليوم: برقم الدرس اللي عليك، وتبقى لين تخلصها
struct LessonTask: Identifiable {
    let id: String
    let course: Course
    let stage: Int
    let label: String          // «المتاجر · اللمعة»
    let title: String          // «اسمع واكتب درس 140»
    let meta: String?          // «باقي من أمس»
    var warn = false
    let done: Bool
    let num: Int
    var action = "خلصت"
}

struct LateLine: Identifiable {
    let course: Course
    let text: String
    let count: Int
    var id: String { course.id }
}

enum LFmt {
    static func hm(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)د" }
        if m == 0 { return "\(h)س" }
        return "\(h)س \(m)د"
    }

    static func hours(_ minutes: Int) -> String {
        let v = Double(minutes) / 60
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    static func weight(_ w: Double) -> String {
        w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
    }

    static func minutesOf(_ t: String?) -> Int? {
        guard let t else { return nil }
        let p = t.split(separator: ":").compactMap { Int($0) }
        return p.count >= 2 ? p[0] * 60 + p[1] : nil
    }

    /// «بعد ساعة»، «بعد 20 دقيقة»
    static func until(_ d: Int) -> String {
        if d <= 0 { return "الحين" }
        if d < 60 { return "بعد \(d) دقيقة" }
        let h = d / 60, m = d % 60
        let hs: String
        switch h {
        case 1: hs = "ساعة"
        case 2: hs = "ساعتين"
        case 3...10: hs = "\(h) ساعات"
        default: hs = "\(h) ساعة"
        }
        if m < 10 { return "بعد " + hs }
        return "بعد " + hs + " و\(m) دقيقة"
    }

    /// وقت من دقايق: «8:40 م»
    static func clock(_ m: Int) -> String {
        let v = ((m % 1440) + 1440) % 1440
        return DateKit.timeLabel(String(format: "%02d:%02d", v / 60, v % 60)) ?? ""
    }

    static func hhmm(_ m: Int) -> String {
        let v = ((m % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", v / 60, v % 60)
    }

    /// «6 س 2 د»
    static func dur(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) د" }
        if m == 0 { return "\(h) س" }
        return "\(h) س \(m) د"
    }

    static func ago(_ m: Int) -> String {
        if m < 60 { return "قبل \(m) د" }
        if m < 1440 { return "قبل \(m / 60) س" }
        return "قبل \(m / 1440) يوم"
    }
}
