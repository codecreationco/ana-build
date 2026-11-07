import SwiftUI

/// الرئيسية: صورتي بالنص وحواليها مدارين، التحية واسمي، التاريخ والأسبوع،
/// سطر واحد يتغير على حسب الوقت، ملخص اليوم، ومساحاتي. مو قائمة مهام.
struct HomeTab: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.go) private var go

    private var greeting: String {
        DateKit.cal.component(.hour, from: Date()) < 12 ? "صباح الخير" : "مساء الخير"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        let items = life.todayItems
        TabPage {
            HStack {
                Spacer()
                InboxButton()
            }
            OrbitHero(items: items)
                .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                Text(greeting).font(T.f(17)).foregroundStyle(T.muted)
                Text("حسن").font(T.f(38, .bold)).foregroundStyle(T.ink)
                    .padding(.top, -2)
                Text(verbatim: "\(DateKit.dayName(life.today))، \(DateKit.dayNum(life.today)) \(DateKit.monthName(life.today)) · \(DateKit.hijri(life.today))")
                    .font(T.f(16)).foregroundStyle(T.muted)
                    .padding(.top, T.s2)
            }
            .frame(maxWidth: .infinity)
            if !life.sync.isEmpty {
                Text(life.sync).font(T.f(12)).foregroundStyle(T.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, T.s1)
            }
            WeekStrip()
                .padding(.top, T.s4)
            StatusLineView()
                .padding(.top, T.s4)
            SummaryCard(items: items) { go(1, 0) }
                .padding(.top, T.s3)
            SecLabel(text: "مساحاتي", center: true)
            Card {
                LinkRow(icon: "book", title: "الدروس", sub: lessonsLine) { go(2, nil) }
                RowLine()
                LinkRow(icon: "briefcase", title: "الشغل", sub: workLine) { go(3, nil) }
                RowLine()
                LinkRow(icon: "heart", title: "الصحة", sub: healthLine) { go(4, nil) }
                RowLine()
                LinkRow(icon: "calendar", title: "الجدول", sub: scheduleLine) { go(1, 3) }
            }
            Foot(text: "+ مساحة جديدة")
            Text(version).font(T.f(11)).foregroundStyle(T.dim)
                .frame(maxWidth: .infinity)
                .padding(.top, T.s4)
        }
    }

    private var lessonsLine: String {
        guard let t = life.todayItems.first(where: { if case .lesson = $0.kind { return !$0.done }; return false }) else {
            return "خلصت دروس اليوم"
        }
        return t.title + " · " + (t.sub ?? "")
    }

    private var workLine: String {
        guard let s = life.remainingSteps.first(where: { $0.waitingOn != nil }) ?? life.remainingSteps.first else {
            return "كل الخطوات خلصت"
        }
        if let w = s.waitingOn {
            return "الخطوة \(s.num) تنتظر " + (w.contains("قعدة") ? "قعدتك" : w)
        }
        return "الخطوة \(s.num): \(s.title)"
    }

    private var healthLine: String {
        if let w = life.workout(on: life.today), !life.gymDoneToday { return "اليوم نادي · \(w.kind)" }
        return "البروتين \(life.protein(life.today)) من \(life.d.proteinTarget) غ"
    }

    private var scheduleLine: String {
        if let a = life.specialSorted.first(where: { ($0.day ?? "") >= life.today }), let k = a.day {
            return a.title + " · " + (a.status == .confirmed ? DateKit.countdown(from: life.today, to: k) : a.status.label)
        }
        return "الأسبوع والشبكة والمواعيد"
    }
}

// MARK: - الصورة والمدارين

private struct OrbitHero: View {
    let items: [TodayItem]
    @EnvironmentObject var life: LifeStore
    @Environment(\.accessibilityReduceMotion) private var reduce

    private let r0: CGFloat = 75, r1: CGFloat = 104

    var body: some View {
        let inner = items.filter { $0.slot == 0 }
        let outer = items.filter { $0.slot != 0 }
        let nextId = life.nextItem(items)?.id
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduce || Snap.on)) { ctx in
            let t = (reduce || Snap.on) ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let a0 = t / 80 * 2 * .pi
            let a1 = -t / 120 * 2 * .pi
            let breath = 1 + 0.0125 * (1 - cos(t * 2 * .pi / 6))
            ZStack {
                ring(r0)
                ring(r1)
                ForEach(Array(inner.enumerated()), id: \.element.id) { i, it in
                    dot(it, next: it.id == nextId)
                        .offset(at(a0 - 150 * .pi / 180 + Double(i) * 2 * .pi / Double(max(inner.count, 1)), r0))
                }
                ForEach(Array(outer.enumerated()), id: \.element.id) { i, it in
                    dot(it, next: it.id == nextId)
                        .offset(at(a1 + 160 * .pi / 180 + Double(i) * 2 * .pi / Double(max(outer.count, 1)), r1))
                }
                Image("LaunchLogo")
                    .resizable().scaledToFill()
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())
                    .scaleEffect(breath)
            }
            .frame(width: 230, height: 230)
        }
        .frame(height: 230)
        .accessibilityElement()
        .accessibilityLabel("أشياء اليوم: \(items.count)، خلصت \(items.filter(\.done).count)")
    }

    private func at(_ a: Double, _ r: CGFloat) -> CGSize {
        CGSize(width: CGFloat(Foundation.cos(a)) * r, height: CGFloat(Foundation.sin(a)) * r)
    }

    private func ring(_ r: CGFloat) -> some View {
        Circle()
            .stroke(T.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(width: r * 2, height: r * 2)
    }

    @ViewBuilder
    private func dot(_ it: TodayItem, next: Bool) -> some View {
        if it.done {
            Circle().fill(T.ink.opacity(0.8)).frame(width: 7, height: 7)
        } else if next {
            Circle().fill(T.bg).overlay(Circle().strokeBorder(T.accent, lineWidth: 2)).frame(width: 10, height: 10)
        } else {
            Circle().fill(T.bg).overlay(Circle().strokeBorder(T.dim, lineWidth: 1.6)).frame(width: 8, height: 8)
        }
    }
}

// MARK: - أيام الأسبوع

private struct WeekStrip: View {
    @EnvironmentObject var life: LifeStore
    private let initials = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]

    var body: some View {
        let week = DateKit.weekStart(life.today)
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = DateKit.add(i, to: week)
                let wd = DateKit.weekday(day)
                let today = day == life.today
                if i > 0 { Spacer(minLength: 0) }
                VStack(spacing: 0) {
                    Text(initials[wd - 1]).font(T.f(13)).foregroundStyle(today ? T.accent : T.faint)
                    Text(verbatim: "\(DateKit.dayNum(day))")
                        .font(T.f(16, today ? .bold : .regular)).monospacedDigit()
                        .foregroundStyle(today ? T.accent : (wd == 6 ? T.faint : T.muted))
                }
                .frame(width: 42, height: 52)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(today ? T.accent : Color.clear, lineWidth: 1))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(DateKit.dayName(day) + " \(DateKit.dayNum(day))" + (today ? "، اليوم" : ""))
            }
        }
    }
}

// MARK: - السطر اللي يتغير على حسب الوقت

struct StatusLineView: View {
    @EnvironmentObject var life: LifeStore
    @State private var sheet: StatusSheet?
    @State private var napMin = 40
    @State private var tick = Date()

    private enum StatusSheet: String, Identifiable {
        case wake, nap, bed
        var id: String { rawValue }
    }

    private var usualSleep: String {
        life.nightsSorted.first(where: { $0.day != life.today })?.sleep ?? "21:00"
    }

    var body: some View {
        Group {
            switch life.status {
            case .wake:
                line("قعدت الحين؟") {
                    timeButton(LFmt.clock(LifeStore.nowMinutes()), "غيّر وقت القعدة") { sheet = .wake }
                    yes("إي، قعدت الحين") {
                        let now = LFmt.hhmm(LifeStore.nowMinutes())
                        life.act("تم: قعدت \(LFmt.clock(LifeStore.nowMinutes()))") {
                            life.setNight(day: life.today, sleep: usualSleep, wake: now)
                        }
                    }
                }
            case .nap:
                line("قيّلت؟") {
                    timeButton(LFmt.dur(napMin), "غيّر مدة القيلولة") { sheet = .nap }
                    yes("إي، قيّلت") {
                        let m = napMin
                        life.act("تم: قيّلت \(LFmt.dur(m))") { life.setNap(life.today, m) }
                    }
                }
            case .bed:
                line("نومك الليلة") {
                    timeButton(LFmt.clock(life.bedtime(life.today)), "غيّر وقت النوم الليلة") { sheet = .bed }
                    Text(verbatim: "تذكير \(LFmt.clock(life.remindTime(life.today)))")
                        .font(T.f(14)).foregroundStyle(T.muted)
                        .padding(.trailing, T.s2)
                }
            case .prayer(let p):
                line("صليت \(p.name)؟") {
                    Text(LFmt.clock(p.min)).font(T.f(15)).monospacedDigit().foregroundStyle(T.muted)
                    yes("إي، صليت \(p.name)") {
                        life.act("تم: صلاة \(p.name)") { life.togglePrayer(p.id, life.today) }
                    }
                }
            case .lesson(let c):
                let t = LFmt.minutesOf(c.time) ?? 0
                let left = t - LifeStore.nowMinutes()
                line((c.mode == .teach ? "تدريس \(c.title)" : "درس \(c.shortName)") + (left > 0 ? " " + LFmt.until(left) : " الحين")) {
                    Button { life.act("ماكو درس اليوم: \(c.shortName)") { life.toggleNoLesson(c, life.today) } } label: {
                        Text("ماكو درس").font(T.f(14)).foregroundStyle(T.muted)
                            .padding(.horizontal, 6).frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if let s = c.link, let url = URL(string: s) {
                        Link(destination: url) {
                            Text("ادخل")
                                .font(T.f(15, .bold))
                                .foregroundStyle(T.pillInk)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 36)
                                .background(RoundedRectangle(cornerRadius: 10).fill(T.pill))
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("ادخل الدرس")
                    }
                }
            case .none:
                EmptyView()
            }
        }
        .id(tick)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { tick = $0 }
        .sheet(item: $sheet) { s in
            switch s {
            case .wake:
                WakeSheet(day: life.today, wake: life.todayNight?.wake ?? LFmt.hhmm(LifeStore.nowMinutes()),
                          sleep: life.todayNight?.sleep ?? usualSleep)
                    .environmentObject(life)
                    .sheetStyle(380)
            case .nap:
                NapSheet(day: life.today, initial: napMin) { napMin = $0 }
                    .environmentObject(life)
                    .sheetStyle(440)
            case .bed:
                BedSheet(day: life.today)
                    .environmentObject(life)
                    .sheetStyle(470)
            }
        }
        .onReceive(Snap.shared.$index) { i in
            let st = Snap.steps[min(i, Snap.steps.count - 1)]
            if Snap.on { sheet = st.name.hasPrefix("wakesheet") ? .wake : nil }
        }
    }

    private func line<C: View>(_ q: String, @ViewBuilder _ trailing: () -> C) -> some View {
        HStack(spacing: T.s3) {
            Text(q).font(T.f(17)).foregroundStyle(T.ink).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
    }

    private func timeButton(_ text: String, _ a11y: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text(text)
                .font(T.f(16, .bold)).monospacedDigit()
                .foregroundStyle(T.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(T.card2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y + "، " + text)
    }

    private func yes(_ a11y: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text("إي")
                .font(T.f(15, .bold))
                .foregroundStyle(T.pillInk)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(T.pill))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}

// MARK: - تعديل الأوقات

/// وقت القعدة والنوم: لكل وقت + و−، كل ضغطة 5 دقايق
struct WakeSheet: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    @State private var wake: Int
    @State private var sleep: Int

    init(day: String, wake: String, sleep: String) {
        self.day = day
        _wake = State(initialValue: LFmt.minutesOf(wake) ?? 300)
        _sleep = State(initialValue: LFmt.minutesOf(sleep) ?? 1260)
    }

    private var minutes: Int {
        var d = wake - sleep
        if d < 0 { d += 1440 }
        return d
    }

    var body: some View {
        EditSheet(title: day == life.today ? "قعدتك اليوم" : "ليلة \(DateKit.dayName(day))",
                  note: "نمت \(LFmt.dur(minutes)) · اضغط الوقت تغيّره", onSave: {
            life.act("تم: وقت النوم") { life.setNight(day: day, sleep: LFmt.hhmm(sleep), wake: LFmt.hhmm(wake)) }
        }) {
            TimeRow(label: "قعدت", sub: "الصبح", value: $wake)
            TimeRow(label: "نمت", sub: "الليلة اللي قبل", value: $sleep)
        }
    }
}

/// مدة القيلولة
struct NapSheet: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    let onPick: (Int) -> Void
    @State private var m: Int

    init(day: String, initial: Int, onPick: @escaping (Int) -> Void) {
        self.day = day
        self.onPick = onPick
        _m = State(initialValue: initial)
    }

    var body: some View {
        EditSheet(title: "القيلولة", note: "تأخر النوم المقترح الليلة على قدها",
                  clearText: life.d.naps[day] != nil ? "ما قيّلت" : nil, onSave: {
            onPick(m)
            life.act("تم: قيّلت \(LFmt.dur(m))") { life.setNap(day, m) }
        }, onClear: {
            life.act("شلت القيلولة") { life.setNap(day, nil) }
        }) {
            TimeWheel(value: $m, duration: true)
        }
        .onAppear { if let n = life.d.naps[day] { m = n.min } }
    }
}

/// وقت النوم الليلة: المقترح، وتقدر تغيّره لهالليلة بس
struct BedSheet: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    @State private var m = 1260

    var body: some View {
        EditSheet(title: "نومك الليلة", note: "التذكير قبله بنص ساعة",
                  clearText: life.d.bedOverride[day] != nil ? "رجّعه للمقترح" : nil, onSave: {
            life.act("تم: نومك الليلة \(LFmt.clock(m))") { life.setBedtime(day, m) }
        }, onClear: {
            life.act("رجع للمقترح") { life.setBedtime(day, nil) }
        }) {
            TimeWheel(value: $m)
        }
        .onAppear { m = life.bedtime(day) }
    }
}

// MARK: - ملخص اليوم

private struct SummaryCard: View {
    @EnvironmentObject var life: LifeStore
    let items: [TodayItem]
    let open: () -> Void

    var body: some View {
        let done = items.filter(\.done).count
        let next = life.nextItem(items)
        let odd = items.filter { !$0.routine && !$0.done }
        let soon = life.soonAppt
        let tip = life.suggestion(items)
        Button(action: open) {
            VStack(spacing: 0) {
                Text(verbatim: "عندك اليوم \(Count.things(items.count)) · خلصت \(done)")
                    .font(T.f(20, .bold)).foregroundStyle(T.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, T.s2)
                if let n = next {
                    line("الجاي", accent: true, n.title + (n.timeText.map { " · " + $0 } ?? ""),
                         [n.sub, n.time.map { LFmt.until($0 - LifeStore.nowMinutes()) }].compactMap { $0 }.joined(separator: " · "))
                } else {
                    line("الجاي", accent: true, "خلص جدول اليوم", tomorrowFirst)
                }
                if !odd.isEmpty {
                    line("مو روتيني", odd.map(\.title).joined(separator: "، "), soon.map { "و" + life.apptLine($0) })
                } else if let s = soon {
                    line("مو روتيني", s.title, life.apptLine(s))
                }
                if let tip {
                    line("اقتراح", tip.title, tip.staleText)
                }
                Text("افتح اليوم").font(T.f(15)).foregroundStyle(T.muted)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private var tomorrowFirst: String? {
        life.events(on: life.tomorrow).first.map { "باجر: " + $0.title + " " + $0.when }
    }

    private func line(_ label: String, accent: Bool = false, _ text: String, _ small: String?) -> some View {
        VStack(spacing: 0) {
            RowLine()
            HStack(alignment: .firstTextBaseline, spacing: T.s3) {
                Text(label).font(T.f(13)).foregroundStyle(accent ? T.accent : T.muted)
                    .frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Text(text).font(T.f(16)).foregroundStyle(T.ink)
                    if let small, !small.isEmpty { Text(small).font(T.f(13)).foregroundStyle(T.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
        }
    }
}

enum Count {
    /// «شي واحد»، «3 أشياء»، «12 شي»
    static func things(_ n: Int) -> String {
        switch n {
        case 0: return "ولا شي"
        case 1: return "شي واحد"
        case 2...10: return "\(n) أشياء"
        default: return "\(n) شي"
        }
    }
}
