import SwiftUI

/// تاب الدروس: كل مادة وين واصل فيها، والكتاب اللي أقراه، ومراجعة آخر الدروس
struct LessonsTab: View {
    @EnvironmentObject var life: LifeStore
    @State private var path: [String] = []
    @State private var reading: ReadRef? = nil

    var body: some View {
        NavigationStack(path: $path) {
            TabPage {
                PageHead(title: "الدروس", sub: subtitle)
                SecLabel(text: "المواد")
                Card {
                    ForEach(Array(life.d.courses.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { RowLine() }
                        Button { path.append(c.id) } label: { CourseBlock(course: c) }
                            .buttonStyle(.plain)
                            .accessibilityHint("يفتح دروس المادة")
                    }
                }
                if !life.d.books.isEmpty {
                    SecLabel(text: "قراءة")
                    Card {
                        ForEach(Array(life.d.books.enumerated()), id: \.element.id) { i, b in
                            if i > 0 { RowLine() }
                            BookBlock(book: b)
                        }
                    }
                }
                ReviewList { reading = $0 }
            }
            .navigationDestination(for: String.self) { id in
                CourseDetail(id: id)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(ScrollTop.shared.$signal) { s in
                // ضغطة التاب وإنت داخل مادة: يرجعك لقائمة المواد
                if s.tab == 2, s.n > 0, !path.isEmpty { path = [] }
            }
            .onReceive(Snap.shared.$index) { i in
                let st = Snap.steps[min(i, Snap.steps.count - 1)]
                guard Snap.on, st.tab == 2 else { return }
                let want = st.course.map { [$0] } ?? []
                if path != want { path = want }
            }
            .sheet(item: $reading) { r in
                LessonSheet(courseId: r.courseId, num: r.num)
                    .environmentObject(life)
                    .environment(\.layoutDirection, .rightToLeft)
                    .preferredColorScheme(.dark)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var subtitle: String {
        let n = life.d.courses.count, b = life.d.books.count
        let cs = n == 1 ? "مادة وحدة" : "\(n) مواد"
        if b == 0 { return cs }
        return cs + (b == 1 ? " وكتاب" : " و\(b) كتب")
    }
}

enum CourseText {
    static let initials = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]

    static func days(_ c: Course) -> String {
        if c.days.count == 7 { return "كل يوم" }
        let order = [7, 1, 2, 3, 4, 5, 6]
        let list = order.filter { c.days.contains($0) }
        if list.count >= 4, let a = list.first, let b = list.last {
            return "\(initials[a - 1]) لين \(initials[b - 1])"
        }
        return list.map { initials[$0 - 1] }.joined(separator: " ")
    }

    static func schedule(_ c: Course) -> String {
        var s = days(c)
        if let t = c.time, let m = LFmt.minutesOf(t) {
            let h = m / 60 % 12 == 0 ? 12 : m / 60 % 12
            s += " · " + String(format: "%d:%02d", h, m % 60)
        }
        return s
    }

    static func mode(_ c: Course) -> String {
        switch c.mode {
        case .teach: return "تدريس · " + schedule(c)
        case .online: return "أونلاين · " + schedule(c)
        case .recording: return "تسجيل يوصل كل يوم"
        }
    }
}

// MARK: - المادة بالقائمة

struct CourseBlock: View {
    @EnvironmentObject var life: LifeStore
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(course.title).font(T.f(19, .bold)).foregroundStyle(T.ink)
                Spacer(minLength: T.s2)
                Text(CourseText.mode(course)).font(T.f(13)).foregroundStyle(T.muted).lineLimit(1)
            }
            Text(nextLine).font(T.f(16)).foregroundStyle(T.ink).padding(.top, 6)
            Text(metaLine).font(T.f(14)).foregroundStyle(T.muted)
            Bar(value: progress).padding(.top, T.s2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, T.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func topic(_ n: Int) -> String {
        course.topic(n).map { " · " + $0 } ?? ""
    }

    private var nextLine: String {
        let c = course
        switch c.mode {
        case .teach:
            return "الجاي: درس \(c.nextTeach)" + topic(c.nextTeach)
        case .recording:
            return c.backlog > 0 ? "عليك: درس \(c.stageA + 1)" + topic(c.stageA + 1) : "ملحّق، ما عليك شي"
        case .online:
            if life.held(c, life.today), let n = life.lessonNumber(c, on: life.today), n > c.stageA {
                return "اليوم: حضور درس \(n)"
            }
            let day = nextLessonDay(c)
            let n = life.lessonNumber(c, on: day) ?? c.released + 1
            return "الجاي: درس \(n) · " + DateKit.countdown(from: life.today, to: day)
        }
    }

    private func nextLessonDay(_ c: Course) -> String {
        for i in 1..<14 {
            let d = DateKit.add(i, to: life.today)
            if life.held(c, d) { return d }
        }
        return DateKit.add(1, to: life.today)
    }

    private var metaLine: String {
        let c = course
        switch c.mode {
        case .teach:
            return (c.nextPrepared ? "محضّر" : "ما تحضّر") + " · درّست \(c.stageB)"
        case .recording:
            return "كتبت \(c.stageA) · وصلني \(c.released)" + (c.backlog > 0 ? " · متأخر \(c.backlog)" : "")
        case .online:
            return "حضرت \(c.stageA) · التقارير لين \(c.stageB)" + (c.backlog > 0 ? " · عليك \(c.backlog)" : "")
        }
    }

    private var progress: Double {
        let c = course
        switch c.mode {
        case .teach:
            guard let end = c.endsOn else { return 0 }
            // كم درس باقي لين نهاية الكورس
            var left = 0
            var k = life.today
            while k <= end { if c.days.contains(DateKit.weekday(k)) { left += 1 }; k = DateKit.add(1, to: k) }
            return Double(c.stageB) / Double(max(c.stageB + left, 1))
        case .recording:
            return Double(c.stageA - c.startNum) / Double(max(c.released - c.startNum, 1))
        case .online:
            return Double(c.stageB - c.startNum) / Double(max(c.stageA - c.startNum, 1))
        }
    }
}

// MARK: - الكتاب

private struct BookBlock: View {
    @EnvironmentObject var life: LifeStore
    let book: Book
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(book.title).font(T.f(19, .bold)).foregroundStyle(T.ink)
                Spacer(minLength: T.s2)
                Text(book.author).font(T.f(13)).foregroundStyle(T.muted)
            }
            Text(verbatim: book.page == 0 ? "ما بديت للحين" : (book.total > 0 ? "وصلت صفحة \(book.page) من \(book.total)" : "وصلت صفحة \(book.page)"))
                .font(T.f(16)).foregroundStyle(T.ink).padding(.top, 6)
            Text(life.readLine(book)).font(T.f(14)).foregroundStyle(T.muted)
            if book.total > 0 { Bar(value: Double(book.page) / Double(book.total)).padding(.top, T.s2) }
        }
        .padding(.horizontal, 18)
        .padding(.top, T.s4)
        .padding(.bottom, T.s3)
        HStack(spacing: T.s2) {
            TextField("", text: $text, prompt: Text("وصلت صفحة كم اليوم؟").foregroundStyle(T.faint))
                .font(T.f(18)).monospacedDigit()
                .foregroundStyle(T.ink)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .focused($focused)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(T.card2))
                .accessibilityLabel("وصلت صفحة كم اليوم")
            PillButton(text: "حفظ") {
                guard let p = NumParse.int(text) else { return }
                life.act("تم: وصلت صفحة \(p)") { life.savePage(book.id, p) }
                text = ""
                focused = false
            }
            .opacity(NumParse.int(text) == nil ? 0.5 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, T.s4)
    }
}

// MARK: - عندك وقت؟ راجع

private struct ReviewList: View {
    @EnvironmentObject var life: LifeStore
    let open: (ReadRef) -> Void

    var body: some View {
        let rows: [(Course, Int)] = life.d.courses.compactMap { (c: Course) -> (Course, Int)? in
            guard let n = life.lastDone(c) else { return nil }
            return (c, n)
        }
        if !rows.isEmpty {
            SecLabel(text: "عندك وقت؟ راجع")
            Card {
                ForEach(rows.indices, id: \.self) { i in
                    let c = rows[i].0, n = rows[i].1
                    if i > 0 { RowLine() }
                    HStack(spacing: T.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(c.shortName) · " + lastLabel(c)).font(T.f(14)).foregroundStyle(T.muted)
                            Text(verbatim: "درس \(n)" + (c.topic(n).map { " · " + $0 } ?? "")).font(T.f(18)).foregroundStyle(T.ink)
                            if life.info(c, n).summary != nil {
                                Text("الملخص والنقاط وملاحظتك").font(T.f(14)).foregroundStyle(T.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        PillButton(text: "اقرا", ghost: true) { open(ReadRef(courseId: c.id, num: n)) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .frame(minHeight: 52)
                }
            }
        }
    }

    private func lastLabel(_ c: Course) -> String {
        switch c.mode {
        case .teach: return "آخر درس درّسته"
        case .online: return "آخر درس حضرته"
        case .recording: return "آخر درس كتبته"
        }
    }
}

// MARK: - تفاصيل المادة

struct CourseDetail: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var open: LessonRef? = nil

    var body: some View {
        TabPage {
            if let c = life.course(id) {
                PageHead(title: c.title, sub: [c.book, CourseText.mode(c)].filter { !$0.isEmpty }.joined(separator: " · "), back: { dismiss() })
                stats(c)
                    .padding(.top, T.s5)
                if let n = c.nextNote { Foot(text: n, center: false) }
                if let r = c.reportLastText { Foot(text: "آخر عبارة بالتقرير: " + r, center: false) }
                if c.mode != .recording {
                    Card {
                        if c.link != nil {
                            Button { life.enterLesson(c) } label: {
                                HStack(spacing: T.s3) {
                                    Image(systemName: "video").font(.system(size: 17)).foregroundStyle(T.muted).frame(width: 22)
                                    Text("ادخل الدرس").font(T.f(18)).foregroundStyle(T.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Chevron()
                                }
                                .padding(.horizontal, 18).frame(minHeight: 52).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            RowLine()
                        }
                        let todayOn = c.days.contains(DateKit.weekday(life.today))
                        ValueRow(title: life.isOff(c, life.today) ? "اليوم ماكو درس" : "درس اليوم",
                                 sub: todayOn ? "إذا انلغى، الرقم ما يتقدم والتنبيه يتشال" : "ما عندك درس اليوم") {
                            if todayOn {
                                SmallButton(text: life.isOff(c, life.today) ? "رجّعه" : "ماكو درس") {
                                    life.act(life.isOff(c, life.today) ? "رجع درس اليوم" : "ماكو درس اليوم") {
                                        life.toggleNoLesson(c, life.today)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, T.s3)
                    RecorderCard(course: c.id)
                }
                SecLabel(text: "الدروس", trailing: "من الأحدث")
                LessonList(course: c) { open = LessonRef(num: $0) }
                Foot(text: "كل درس تفتحه: الملخص، النقاط، وملاحظتك")
                Steppers(course: c)
            } else {
                EmptyNote(text: "المادة مو موجودة")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $open) { r in
            LessonSheet(courseId: id, num: r.num)
                .environmentObject(life)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .presentationDragIndicator(.visible)
        }
    }

    private func stats(_ c: Course) -> some View {
        let items: [(String, String)]
        switch c.mode {
        case .recording: items = [("\(c.released)", "وصلني"), ("\(c.stageA)", "كتبت"), ("\(c.backlog)", "عليك")]
        case .online: items = [("\(c.stageA)", "حضرت"), ("\(c.stageB)", "التقارير لين"), ("\(c.backlog)", "عليك")]
        case .teach: items = [("\(c.stageB)", "درّست"), ("\(c.stageA)", "محضّر لين"), ("\(c.nextTeach)", "الجاي")]
        }
        return HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                VStack(spacing: 0) {
                    Text(items[i].0).font(T.f(24, .bold)).monospacedDigit().foregroundStyle(T.ink)
                    Text(items[i].1).font(T.f(13)).foregroundStyle(T.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, T.s4)
        .padding(.horizontal, T.s2)
        .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
    }
}

/// تصحيح الأرقام: زيادة أو نقص لكل خطوة
private struct Steppers: View {
    @EnvironmentObject var life: LifeStore
    let course: Course

    var body: some View {
        SecLabel(text: "تصحيح الأرقام")
        Card {
            ForEach(course.stageNames.indices, id: \.self) { i in
                if i > 0 { RowLine() }
                let v = i == 0 ? course.stageA : course.stageB
                ValueRow(title: course.stageNames[i]) {
                    SmallButton(text: "−", label: "نقّص \(course.stageNames[i])") {
                        life.act("رجعت: \(course.title)") { life.bump(course.id, stage: i, by: -1) }
                    }
                    Text(verbatim: "\(v)").font(T.f(17, .bold)).monospacedDigit().foregroundStyle(T.ink).frame(minWidth: 44)
                    SmallButton(text: "+", label: "زيد \(course.stageNames[i])") {
                        life.act("تم: \(course.title)") { life.bump(course.id, stage: i, by: 1) }
                    }
                }
            }
        }
    }
}

/// صف الدرس: الرقم، العنوان الكبير، العنوان، شنو يغطي من المتن، والحالة
private struct LessonRow: View {
    let num: Int
    let info: LessonInfo?
    let status: String
    let done: Bool
    let current: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: T.s3) {
                Text(verbatim: "\(num)").font(T.f(14)).monospacedDigit()
                    .foregroundStyle(current ? T.accent : T.muted)
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    if let s = info?.section { Text(s).font(T.f(12)).foregroundStyle(current ? T.accent : T.faint) }
                    Text(info?.topic ?? "درس \(num)").font(T.f(17)).foregroundStyle(done ? T.faint : T.ink)
                        .multilineTextAlignment(.leading)
                    if let c = info?.coverage {
                        Text(c).font(T.f(13)).foregroundStyle(T.muted).lineLimit(2).multilineTextAlignment(.leading)
                    } else if let d = info?.details ?? info?.summary {
                        Text(d).font(T.f(13)).foregroundStyle(T.muted).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Text(status).font(T.f(13)).foregroundStyle(current ? T.accent : T.faint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron().padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(current ? T.rowNext : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// كل درس وحالته، من الأحدث
private struct LessonList: View {
    @EnvironmentObject var life: LifeStore
    let course: Course
    let onOpen: (Int) -> Void

    private var top: Int {
        switch course.mode {
        case .teach: return max(course.stageA, course.stageB) + 1
        default: return max(course.released, course.firstLesson ?? 0)
        }
    }

    /// الدرس اللي عليك الحين
    private var current: Int {
        switch course.mode {
        case .teach: return course.nextTeach
        case .online: return course.stageB + 1
        case .recording: return course.stageA + 1
        }
    }

    var body: some View {
        // كل الدروس من الأحدث: اللي وصل كله، لين قبل اللي عليك بعشرة دروس (أو أول درس عندنا تفصيله)
        let known = course.info.keys.compactMap { Int($0) }
        let low = max(course.firstLesson ?? 1, min(known.min() ?? current, current - 10))
        let nums = top >= low ? Array(stride(from: top, through: low, by: -1)) : []
        Card {
            ForEach(Array(nums.enumerated()), id: \.element) { i, n in
                if i > 0 { RowLine() }
                LessonRow(num: n, info: course.info[String(n)], status: status(n),
                          done: n < current, current: n == current) { onOpen(n) }
            }
        }
    }

    private func status(_ n: Int) -> String {
        // حالة التقرير من المحادثة إذا موجودة
        if let i = course.info[String(n)] {
            if i.missing == true { return "الدرس مفقود" }
            if let r = i.report {
                let base: String
                switch r {
                case "done", "in_file": base = r == "in_file" ? "التقرير بالملف" : "التقرير مكتمل"
                case "partial": base = "التقرير جزئي"
                case "draft": base = "مسودة تنتظر مراجعتك"
                case "missing": base = "الدرس مفقود"
                default: base = course.mode == .teach ? "ما تحضّر" : "التقرير ما انكتب"
                }
                return base + (i.reportNote.map { " · " + $0 } ?? "")
            }
        }
        let date = life.dateOf(course, num: n).map { "\(DateKit.dayNum($0)) \(DateKit.monthName($0))" }
        switch course.mode {
        case .recording:
            if n <= course.stageA { return "كتبته" + (date.map { " · " + $0 } ?? "") }
            if n == course.stageA + 1 {
                if let since = life.dateOf(course, num: n), since < life.today {
                    return "عليك · باقي من \(DateKit.diff(since, life.today)) يوم"
                }
                return "عليك"
            }
            return "وصل · ما انكتب"
        case .online:
            if n <= course.stageB { return "حضرته وكتبت التقرير" + (date.map { " · " + $0 } ?? "") }
            if n <= course.stageA { return n == course.stageB + 1 ? "عليك التقرير" : "حضرته · التقرير باقي" }
            return "ما حضرته"
        case .teach:
            if n <= course.stageB { return "درّسته" }
            if n <= course.stageA { return "محضّر" }
            return "ما تحضّر"
        }
    }
}

struct LessonRef: Identifiable {
    let num: Int
    var id: Int { num }
}

struct ReadRef: Identifiable {
    let courseId: String
    let num: Int
    var id: String { "\(courseId)-\(num)" }
}

/// صفحة الدرس: الموضوع، الملخص، النقاط، الحالة، وملاحظتي
struct LessonSheet: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    let courseId: String
    let num: Int

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            if let c = life.course(courseId) {
                content(c)
            }
        }
    }

    private func content(_ c: Course) -> some View {
        let inf = life.info(c, num)
        let date = life.dateOf(c, num: num)
        var parts: [String] = []
        if let date { parts.append(DateKit.long(date)) }
        for i in c.stageNames.indices {
            let done = num <= (i == 0 ? c.stageA : c.stageB)
            parts.append(c.stageNames[i] + (done ? " تم" : " باقي"))
        }
        let metaLine = parts.joined(separator: " · ")
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: ([c.title, inf.section].compactMap { $0 } + ["درس \(num)"]).joined(separator: " · ")).font(T.f(14)).foregroundStyle(T.muted)
                        Text(inf.topic ?? "درس \(num)").font(T.f(28, .bold)).foregroundStyle(T.ink)
                        Text(metaLine).font(T.f(14)).foregroundStyle(T.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.muted)
                            .frame(width: 40, height: 40).background(Circle().fill(T.card2))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("سكّر")
                }
                if let cov = inf.coverage {
                    SecLabel(text: "من المتن")
                    Text(cov).font(T.f(17)).lineSpacing(5).foregroundStyle(T.ink).card()
                }
                if let det = inf.details {
                    SecLabel(text: "شنو فيه")
                    Text(det).font(T.f(18)).lineSpacing(7).foregroundStyle(T.ink).card()
                }
                SecLabel(text: "الملخص")
                Text(inf.summary ?? "ما في ملخص للحين. ينضاف من المحادثة اللي نرتب فيها الدرس.")
                    .font(T.f(18)).lineSpacing(6)
                    .foregroundStyle(inf.summary == nil ? T.faint : T.ink)
                    .card()
                if !inf.points.isEmpty {
                    SecLabel(text: "النقاط")
                    Card {
                        ForEach(inf.points.indices, id: \.self) { i in
                            if i > 0 { RowLine() }
                            HStack(alignment: .firstTextBaseline, spacing: T.s3) {
                                Text(verbatim: "\(i + 1)").font(T.f(14)).monospacedDigit().foregroundStyle(T.muted).frame(width: 20)
                                Text(inf.points[i]).font(T.f(17)).foregroundStyle(T.ink).lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 12)
                        }
                    }
                }
                SecLabel(text: "ملاحظتي")
                NoteField(initial: inf.note ?? "", placeholder: "اكتب أي شي عن هالدرس…") {
                    life.setLessonNote(c.id, num, $0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, T.s5)
            .padding(.bottom, 40)
        }
    }
}
