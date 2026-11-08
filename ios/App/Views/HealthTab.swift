import SwiftUI
import UIKit
import UserNotifications

/// تاب الصحة: النادي، التقدم، الأكل، النوم
struct HealthTab: View {
    @Binding var seg: Int

    var body: some View {
        TabPage {
            PageHead(title: "الصحة")
            SegText(items: ["النادي", "التقدم", "الأكل", "النوم"], sel: $seg)
            switch seg {
            case 0: GymView()
            case 1: GymProgress()
            case 2: NutritionView()
            default: SleepView()
            }
        }
    }
}

// MARK: - عداد الراحة

/// يشتغل لحاله بعد كل جولة، ويرن إشعار لما يخلص حتى لو التلفون مقفول
final class RestTimer: ObservableObject {
    static let shared = RestTimer()

    @Published var end: Date?
    @Published var next: String?
    @Published var shown = false

    func start(_ seconds: Int, next: String?) {
        self.next = next
        shown = true
        guard next != nil else { end = nil; cancelNote(); return }
        end = Date().addingTimeInterval(TimeInterval(seconds))
        note()
    }

    func add(_ s: Int) {
        guard let e = end, e > Date() else { return }
        end = e.addingTimeInterval(TimeInterval(s))
        note()
    }

    func skip() {
        end = nil
        shown = false
        cancelNote()
    }

    private func note() {
        guard let e = end else { return }
        let c = UNMutableNotificationContent()
        c.title = "خلصت الراحة"
        c.body = next.map { "الجاي: " + $0 } ?? "يلا"
        c.sound = .default
        let t = UNTimeIntervalNotificationTrigger(timeInterval: max(1, e.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rest", content: c, trigger: t))
    }

    private func cancelNote() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
    }
}

// MARK: - النادي

private struct GymView: View {
    @EnvironmentObject var life: LifeStore
    @ObservedObject private var timer = RestTimer.shared
    @State private var picked: String? = nil

    private var week: String { DateKit.weekStart(life.today) }

    private var gymDays: [String] {
        (0..<7).map { DateKit.add($0, to: week) }.filter { life.workout(on: $0) != nil }
    }

    private var selected: String {
        if let p = picked { return p }
        if life.workout(on: life.today) != nil { return life.today }
        return gymDays.first { $0 > life.today } ?? gymDays.last ?? life.today
    }

    var body: some View {
        dayStrip.padding(.top, T.s4)
            .onAppear {
                // وضع التصوير: نوري العداد شغال
                if Snap.on, let w = life.workout(on: selected), let ex = w.exercises.first {
                    RestTimer.shared.start(ex.restSec, next: "\u{2067}\(ex.name)\u{2069} · الجولة 2")
                }
            }
        if let w = life.workout(on: selected) {
            let day = selected
            let s = life.setsDone(day, w)
            let exDone = w.exercises.filter { ex in ex.sets.indices.allSatisfy { life.isSetDone(day, ex, $0) } }.count
            let g = life.gymLog(day)
            Section {
                if let c = w.coach {
                    Text(c).font(T.f(14)).foregroundStyle(T.muted)
                        .padding(.horizontal, 2).padding(.vertical, T.s3)
                }
                if !w.walk.isEmpty { WalkCard(day: day, w: w) }
                Card {
                    ForEach(Array(w.exercises.enumerated()), id: \.element.id) { i, ex in
                        if i > 0 { RowLine() }
                        ExerciseBlock(day: day, w: w, ex: ex)
                    }
                }
                .padding(.top, T.s3)
                if w.pool { poolRow(day, g).padding(.top, T.s3) }
                NoteField(initial: g.dayNote, placeholder: "اليوم بشكل عام: الطاقة، النوم، أي ألم…") { t in
                    life.updateGym(day) { $0.dayNote = t }
                }
                .padding(.top, T.s3)
                Foot(text: "كل اللي تسجله هني ينحفظ، ومحادثة التمرين تقراه وتعدل اليوم الجاي")
            } header: {
                gymBar(s.done, s.total, exDone, w.exercises.count)
            }
        } else {
            EmptyNote(text: "برنامج الأسبوع ينضاف من محادثة النادي. لما تدخّله يطلع هني.")
                .padding(.top, T.s4)
        }
    }

    private var dayStrip: some View {
        HStack(spacing: T.s2) {
            ForEach(gymDays, id: \.self) { d in
                let w = life.workout(on: d)
                let sel = d == selected
                Button { picked = d } label: {
                    VStack(spacing: 0) {
                        Text(DateKit.dayShortName(d)).font(T.f(14)).foregroundStyle(sel ? T.accent : T.muted)
                        Text(w?.kind ?? "").font(T.f(15, sel ? .bold : .regular)).foregroundStyle(sel ? T.accent : T.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, T.s2)
                    .background(RoundedRectangle(cornerRadius: 12).fill(T.card))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? T.accent : Color.clear, lineWidth: 1))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(sel ? .isSelected : [])
            }
        }
    }

    private func gymBar(_ done: Int, _ total: Int, _ exDone: Int, _ exTotal: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                count("\(done) من \(total)", "جولة")
                Spacer()
                count("\(exDone) من \(exTotal)", "تمارين")
            }
            Bar(value: Double(done) / Double(max(total, 1))).padding(.top, T.s2)
            if timer.shown { RestCard().padding(.top, T.s3) }
        }
        .padding(.vertical, T.s3)
        .padding(.horizontal, 20)
        .background(T.bg)
        .overlay(alignment: .bottom) { RowLine() }
        .padding(.horizontal, -20)
        .padding(.top, T.s3)
    }

    private func count(_ v: String, _ l: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(v).font(T.f(20, .bold)).monospacedDigit().foregroundStyle(T.ink)
            Text(l).font(T.f(14)).foregroundStyle(T.muted)
        }
    }

    private func poolRow(_ day: String, _ g: GymLog) -> some View {
        Card {
            ValueRow(title: "الحوض", sub: "كم دقيقة سبحت؟") {
                Menu {
                    Button("ما سبحت") { life.setPool(day, nil) }
                    ForEach([10, 15, 20, 25, 30, 35, 40, 45], id: \.self) { m in
                        Button("\(m) د") { life.act("تم: الحوض \(m) د") { life.setPool(day, m) } }
                    }
                } label: {
                    Text(g.poolMin.map { "\($0) د" } ?? "—")
                        .font(T.f(17)).monospacedDigit().foregroundStyle(g.poolMin == nil ? T.muted : T.ink)
                        .frame(minWidth: 58, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("كم دقيقة سبحت")
            }
        }
    }
}

/// المشي: عداد لكل مقطع، والنبض بالبداية وعند كل تحويل سرعة، وإشعار وقت التحويل
private struct WalkCard: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    let w: WorkoutDay

    private var segs: [WalkSeg] { w.walk }
    /// بداية المقطع بالثواني من أول المشي
    private func startOf(_ i: Int) -> Int { segs.prefix(i).reduce(0) { $0 + $1.min } * 60 }
    private var total: Int { startOf(segs.count) }
    private func index(at e: Int) -> Int { (0..<segs.count).last { startOf($0) <= e } ?? 0 }
    private func speed(_ v: Double) -> String { "\u{2066}" + LFmt.weight(v) + "\u{2069}" }

    var body: some View {
        let g = life.gymLog(day)
        Card {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let el = g.walkStart.map { max(0, Int(ctx.date.timeIntervalSince1970 - $0)) }
                let over = (el ?? 0) >= total
                let running = el != nil && !over && !g.walk
                let cur = el.map { index(at: $0) }
                VStack(spacing: 0) {
                    if running, let e = el, let i = cur {
                        live(e, i)
                    } else {
                        idle(g, started: el != nil)
                    }
                    ForEach(segs.indices, id: \.self) { i in
                        RowLine()
                        segRow(i, g, active: running && cur == i)
                    }
                }
                .onChange(of: over) { _, o in
                    // خلص الوقت والتطبيق مفتوح: نسجل المشي
                    if o, !g.walk, let e = el, e < total + 5 {
                        life.act("تم: المشي") { life.updateGym(day) { $0.walk = true } }
                    }
                }
            }
        }
    }

    private func idle(_ g: GymLog, started: Bool) -> some View {
        HStack(spacing: T.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("المشي").font(T.f(17)).foregroundStyle(g.walk ? T.faint : T.ink)
                Text(verbatim: g.walk ? "خلص · \(total / 60) د" : "\(total / 60) د · \(segs.count) مقاطع")
                    .font(T.f(14)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !g.walk {
                SmallButton(text: started ? "من جديد" : "ابدأ") { start() }
            }
            Check(on: g.walk, label: "خلصت المشي") {
                life.act(g.walk ? "رجعت: المشي" : "تم: المشي") { life.toggleWalk(day) }
                if !g.walk { cancel() }
            }
        }
        .padding(.leading, 18).padding(.trailing, 8)
        .padding(.vertical, 10)
    }

    private func live(_ e: Int, _ i: Int) -> some View {
        let left = startOf(i + 1) - e
        let next = i + 1 < segs.count ? "بعدها زيد لـ " + speed(segs[i + 1].speed) : "بعدها تخلص"
        return HStack(alignment: .center, spacing: T.s3) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "المقطع \(i + 1) من \(segs.count) · على " + speed(segs[i].speed))
                    .font(T.f(13)).foregroundStyle(T.muted)
                Text(verbatim: RestTimes.label(left))
                    .font(T.f(30, .bold)).monospacedDigit().foregroundStyle(T.accent)
                Text(verbatim: next + " · مضى " + RestTimes.label(e))
                    .font(T.f(13)).foregroundStyle(T.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SmallButton(text: "وقّف") { stop() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, T.s3)
        .sensoryFeedback(.impact, trigger: i)
    }

    private func segRow(_ i: Int, _ g: GymLog, active: Bool) -> some View {
        let hr = g.walkHR?[String(i)]
        return HStack(spacing: T.s3) {
            Circle().fill(active ? T.accent : Color.clear).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(segs[i].min) د على " + speed(segs[i].speed))
                    .font(T.f(15, active ? .bold : .regular)).foregroundStyle(T.ink)
                Text(i == 0 ? "نبضك بالبداية" : "نبضك عند التحويل")
                    .font(T.f(13)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CellField(initial: hr.map(String.init) ?? "", decimal: false,
                      label: i == 0 ? "النبض بالبداية" : "النبض عند التحويل \(i)") { v in
                life.updateGym(day) { g in
                    var m = g.walkHR ?? [:]
                    m[String(i)] = NumParse.int(v)
                    g.walkHR = m.isEmpty ? nil : m
                }
            }
            .frame(width: 64)
        }
        .padding(.leading, 12).padding(.trailing, 18)
        .padding(.vertical, 8)
    }

    // MARK: - الإشعارات

    private func start() {
        life.updateGym(day) {
            $0.walkStart = Date().timeIntervalSince1970
            $0.walk = false
        }
        cancel()
        let center = UNUserNotificationCenter.current()
        for i in 1..<max(1, segs.count) {
            let c = UNMutableNotificationContent()
            c.title = "زيد السرعة لـ " + LFmt.weight(segs[i].speed)
            c.body = "المقطع \(i + 1) · \(segs[i].min) د · سجّل نبضك"
            c.sound = .default
            c.interruptionLevel = .timeSensitive
            let t = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(startOf(i)), repeats: false)
            center.add(UNNotificationRequest(identifier: "walk-\(i)", content: c, trigger: t))
        }
        let c = UNMutableNotificationContent()
        c.title = "خلص المشي"
        c.body = "\(total / 60) د"
        c.sound = .default
        let t = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, total)), repeats: false)
        center.add(UNNotificationRequest(identifier: "walk-end", content: c, trigger: t))
    }

    private func stop() {
        cancel()
        life.act("تم: المشي") { life.updateGym(day) { $0.walk = true } }
    }

    private func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (1..<max(2, segs.count + 1)).map { "walk-\($0)" } + ["walk-end"])
    }
}

/// العداد تحت الشريط اللي فوق
private struct RestCard: View {
    @ObservedObject private var timer = RestTimer.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let left = timer.end.map { max(0, Int(ceil($0.timeIntervalSince(ctx.date)))) } ?? 0
            let over = timer.next == nil
            let go = !over && left == 0
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(over ? "خلصت تمارين اليوم" : (go ? "ابدأ: " : "راحة · الجاي: ") + (timer.next ?? ""))
                        .font(T.f(13)).foregroundStyle(T.muted).lineLimit(1)
                    Text(over ? "✓" : (go ? "يلا" : RestTimes.label(left)))
                        .font(T.f(30, .bold)).monospacedDigit()
                        .foregroundStyle(go || over ? T.ink : T.accent)
                }
                Spacer(minLength: T.s2)
                HStack(spacing: T.s2) {
                    if !go && !over { timerButton("+15 ث") { timer.add(15) } }
                    timerButton(go || over ? "سكّر" : "تخطّي") { timer.skip() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
            .sensoryFeedback(.success, trigger: go)
        }
    }

    private func timerButton(_ t: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text(t).font(T.f(14, .bold)).foregroundStyle(T.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Capsule().fill(T.card2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ExerciseBlock: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    let w: WorkoutDay
    let ex: Exercise

    var body: some View {
        let complete = ex.sets.indices.allSatisfy { life.isSetDone(day, ex, $0) }
        let prev = life.previous(ex, before: day)
        let rest = RestTimes.label(ex.restSec)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: T.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("\u{200F}" + ex.name).font(T.f(18)).foregroundStyle(complete ? T.faint : T.ink)
                        + Text(" · " + ex.ar).font(T.f(14)).foregroundStyle(T.muted))
                    if let p = ex.sets.first {
                        Text(verbatim: "الهدف \(p.reps) عدة · خل باقي \(p.rir)").font(T.f(14)).foregroundStyle(T.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                OutlineChip(text: (complete ? "خلص · " : "") + "راحة " + rest)
            }
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    head("الجولة").frame(width: 30)
                    head("السابق").frame(maxWidth: .infinity)
                    head("كغ").frame(width: 60)
                    head("عدات").frame(width: 52)
                    head("باقي").frame(width: 52)
                    Color.clear.frame(width: 40, height: 1)
                }
                ForEach(ex.sets.indices, id: \.self) { i in
                    SetRow(day: day, w: w, ex: ex, i: i, prev: prev.flatMap { $0.sets.indices.contains(i) ? $0.sets[i] : nil })
                }
            }
            .padding(.top, T.s3)
            RowLine().padding(.top, T.s3)
            NoteField(initial: life.gymLog(day).notes[ex.id] ?? "", placeholder: "ملاحظة على التمرين…",
                      boxed: false, size: 14, color: T.muted) { t in
                life.updateGym(day) { $0.notes[ex.id] = t.isEmpty ? nil : t }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, T.s4)
    }

    private func head(_ t: String) -> some View {
        Text(t).font(T.f(12)).foregroundStyle(T.muted).lineLimit(1).minimumScaleFactor(0.8)
    }
}

private struct SetRow: View {
    @EnvironmentObject var life: LifeStore
    let day: String
    let w: WorkoutDay
    let ex: Exercise
    let i: Int
    let prev: SetLog?

    private static let rirOrder = ["", "0", "1", "2", "3+"]

    var body: some View {
        let plan = ex.sets[i]
        let s = life.setLog(day, ex, i)
        let done = life.isSetDone(day, ex, i)
        HStack(spacing: 6) {
            Text(verbatim: "\(i + 1)").font(T.f(15)).monospacedDigit().foregroundStyle(T.muted).frame(width: 30)
            Text(prevText(plan))
                .font(T.f(13)).monospacedDigit().foregroundStyle(T.faint)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            CellField(initial: LFmt.weight(s.w ?? plan.weight), dimmed: done, label: "وزن الجولة \(i + 1) بالكيلو") { t in
                life.updateSet(day, ex, i) { $0.w = NumParse.double(t) }
            }
            .frame(width: 60)
            CellField(initial: s.r.map(String.init) ?? "", decimal: false, dimmed: done, label: "عدات الجولة \(i + 1)") { t in
                life.updateSet(day, ex, i) { x in
                    x.r = NumParse.int(t)
                    if x.r != nil, x.w == nil { x.w = plan.weight }
                }
            }
            .frame(width: 52)
            Button {
                let cur = s.rir ?? ""
                let k = Self.rirOrder.firstIndex(of: cur) ?? 0
                let nx = Self.rirOrder[(k + 1) % Self.rirOrder.count]
                life.updateSet(day, ex, i) { $0.rir = nx.isEmpty ? nil : nx }
            } label: {
                Text(s.rir ?? "—")
                    .font(T.f(17, s.rir == nil ? .regular : .bold)).monospacedDigit()
                    .foregroundStyle(s.rir == nil ? T.faint : (done ? T.muted : T.ink))
                    .frame(width: 52, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(done ? T.cellDoneBg : T.card2))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("كم عدة باقي بالجولة \(i + 1): \(s.rir ?? "ما انكتب")")
            Check(on: done, label: "خلصت الجولة \(i + 1)", hit: 40) {
                let was = done
                life.act(was ? "رجعت: \(ex.name) \(i + 1)" : "تم: \(ex.name) · الجولة \(i + 1)") { life.toggleSet(day, ex, i) }
                if !was {
                    RestTimer.shared.start(ex.restSec, next: nextLabel())
                }
            }
            .frame(width: 40)
        }
    }

    private func prevText(_ plan: SetPlan) -> String {
        guard let p = prev else { return "—" }
        let r = p.r.map(String.init) ?? plan.reps
        return "\u{2066}" + LFmt.weight(p.w ?? plan.weight) + "×" + r + "\u{2069}"
    }

    /// أول جولة ما خلصت بتمارين اليوم
    private func nextLabel() -> String? {
        for e in w.exercises {
            for k in e.sets.indices where !life.isSetDone(day, e, k) {
                return "\u{2067}\(e.name)\u{2069} · الجولة \(k + 1)"
            }
        }
        return nil
    }
}

// MARK: - التقدم والأرشيف

private struct GymProgress: View {
    @EnvironmentObject var life: LifeStore
    @State private var open: Set<String> = []

    var body: some View {
        SecLabel(text: "تطور الأوزان", trailing: "أعلى وزن بكل أسبوع")
        Card {
            let list = life.allExercises.filter { life.weeklyTop($0).count > 0 }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, ex in
                if i > 0 { RowLine() }
                let tops = Array(life.weeklyTop(ex).suffix(5))
                let diff = (tops.last?.top ?? 0) - (tops.first?.top ?? 0)
                ValueRow(title: "\u{200F}" + ex.name,
                         sub: "\u{2066}" + tops.reversed().map { LFmt.weight($0.top) }.joined(separator: " ← ") + "\u{2069}",
                         value: diff == 0 ? "ثابت" : "\u{2066}" + (diff > 0 ? "+" : "") + LFmt.weight(diff) + "\u{2069} كغ", valueDim: diff <= 0)
            }
        }
        SecLabel(text: "جولات هالأسبوع لكل عضلة")
        Card {
            let rows = life.muscleVolume(week: DateKit.weekStart(life.today))
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                if i > 0 { RowLine() }
                HStack(spacing: T.s3) {
                    Text(r.muscle).font(T.f(16)).foregroundStyle(T.ink).frame(width: 110, alignment: .leading)
                    Bar(value: Double(r.done) / Double(max(r.plan, 1)))
                    Text(verbatim: "\(r.done) من \(r.plan)").font(T.f(14)).monospacedDigit().foregroundStyle(T.muted)
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.horizontal, 18).frame(minHeight: 48)
            }
        }
        SecLabel(text: "الأرشيف")
        if life.gymWeeks.isEmpty {
            EmptyNote(text: "الأرشيف يتعبى أسبوع ورا أسبوع من اللي تسجله بالنادي.")
        }
        ForEach(life.gymWeeks) { wk in
            weekCard(wk).padding(.bottom, T.s3)
        }
    }

    private func weekLabel(_ start: String) -> String {
        let end = DateKit.add(6, to: start)
        if start == DateKit.weekStart(life.today) { return "هالأسبوع" }
        return "\(DateKit.dayNum(start)) \(DateKit.monthName(start)) – \(DateKit.dayNum(end)) \(DateKit.monthName(end))"
    }

    private func weekCard(_ wk: GymWeek) -> some View {
        let isOpen = open.contains(wk.id)
        return Card {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if isOpen { open.remove(wk.id) } else { open.insert(wk.id) }
                }
            } label: {
                HStack(spacing: T.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekLabel(wk.start)).font(T.f(18)).foregroundStyle(T.ink)
                        Text(verbatim: "\(wk.sessions) حصص · \(wk.setsDone) من \(wk.setsTotal) جولة").font(T.f(14)).foregroundStyle(T.muted)
                        Bar(value: Double(wk.setsDone) / Double(max(wk.setsTotal, 1))).padding(.top, 6)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(T.dim)
                }
                .padding(.horizontal, 18).padding(.vertical, T.s3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                ForEach(wk.days, id: \.self) { day in
                    if let w = life.workout(on: day) {
                        RowLine()
                        dayLog(day, w)
                    }
                }
            }
        }
    }

    private func dayLog(_ day: String, _ w: WorkoutDay) -> some View {
        let g = life.gymLog(day)
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(DateKit.dayName(day)) \(DateKit.dayNum(day)) · \(w.kind)").font(T.f(14)).foregroundStyle(T.muted)
            ForEach(w.exercises) { ex in
                let parts = ex.sets.indices.compactMap { i -> String? in
                    guard let s = g.sets["\(ex.id)#\(i)"], s.done || (s.r ?? 0) > 0 else { return nil }
                    return LFmt.weight(s.w ?? ex.sets[i].weight) + "×" + (s.r.map(String.init) ?? ex.sets[i].reps)
                }
                HStack(alignment: .firstTextBaseline, spacing: T.s2) {
                    Text("\u{200F}" + ex.name).font(T.f(14)).foregroundStyle(T.ink).frame(width: 118, alignment: .leading)
                    Text(parts.isEmpty ? "—" : "\u{2066}" + parts.joined(separator: " · ") + "\u{2069}")
                        .font(T.f(13)).monospacedDigit().foregroundStyle(T.faint)
                }
                if let n = g.notes[ex.id], !n.isEmpty {
                    Text(n).font(T.f(13)).foregroundStyle(T.muted)
                }
            }
            if !g.dayNote.isEmpty { Text(g.dayNote).font(T.f(13)).foregroundStyle(T.muted) }
        }
        .padding(.horizontal, 18).padding(.vertical, T.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - الأكل

private struct NutritionView: View {
    @EnvironmentObject var life: LifeStore
    @State private var asking = false
    @State private var gText = ""
    @State private var nameText = ""

    var body: some View {
        let h = life.health(life.today)
        let p = life.protein(life.today)
        let target = life.d.proteinTarget, minP = life.d.proteinMin
        let gym = life.workout(on: life.today) != nil
        let list = life.foods(life.today)
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(p)").font(T.f(44, .bold)).monospacedDigit().foregroundStyle(T.ink)
                Text(verbatim: "من \(target) غ بروتين").font(T.f(16)).foregroundStyle(T.muted)
            }
            Bar(value: Double(p) / Double(max(target, 1))).padding(.top, T.s3)
            Text(p >= minP ? (p >= target ? "وصلت الهدف" : "وصلت الحد الأدنى · باقي \(target - p) غ للهدف")
                           : "باقي \(minP - p) غ للحد الأدنى (\(minP))")
                .font(T.f(14)).foregroundStyle(T.muted).padding(.top, T.s2)
            HStack(spacing: T.s2) {
                PillButton(text: "+ سكوب 24") { life.act("تم: سكوب 24 غ") { life.addFood("سكوب بروتين", 24) } }
                PillButton(text: "+ 30", ghost: true) { life.act("تم: 30 غ") { life.addFood("بروتين", 30) } }
                PillButton(text: "رقم بيدي", ghost: true) { gText = ""; nameText = ""; asking = true }
            }
            .padding(.top, T.s4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, T.s5)
        .padding(.bottom, T.s4)
        .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
        .padding(.top, T.s5)
        .alert("كم غرام بروتين؟", isPresented: $asking) {
            TextField("شنو أكلت؟ (اختياري)", text: $nameText)
            TextField("الغرامات", text: $gText).keyboardType(.numberPad)
            Button("سجّل") {
                if let g = NumParse.int(gText), g > 0 {
                    let n = nameText.trimmingCharacters(in: .whitespaces)
                    life.act("تم: \(g) غ") { life.addFood(n.isEmpty ? "بروتين" : n, g) }
                }
            }
            Button("إلغاء", role: .cancel) {}
        }

        SecLabel(text: "اللي سجلته اليوم", trailing: "\(list.count)")
        Card {
            if list.isEmpty {
                Text("ما سجلت شي للحين").font(T.f(15)).foregroundStyle(T.faint)
                    .padding(.horizontal, 18).frame(minHeight: 52)
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, f in
                if i > 0 { RowLine() }
                HStack(spacing: T.s3) {
                    Text(LFmt.clock(LFmt.minutesOf(f.at) ?? 0)).font(T.f(14)).monospacedDigit().foregroundStyle(T.muted)
                        .frame(width: 58, alignment: .leading)
                    Text(verbatim: "\(f.title) · \(f.grams) غ").font(T.f(18)).foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { life.act("شلت: \(f.title)") { life.removeFood(f.id) } } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundStyle(T.muted)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("احذف \(f.title)")
                    .padding(.horizontal, -8)
                }
                .padding(.horizontal, 18).frame(minHeight: 52)
            }
        }

        SecLabel(text: "المكملات")
        Card {
            ItemRow(title: "الكرياتين", sub: "مع قهوة الصبح", done: h.creatine) {
                life.act(h.creatine ? "رجعت: الكرياتين" : "تم: الكرياتين") { life.toggleHealth(\.creatine) }
            }
            RowLine()
            ItemRow(title: "الإلكترولايت", sub: gym ? "بمطارة النادي" : "أيام النادي بس", done: h.electrolyte) {
                life.act(h.electrolyte ? "رجعت: الإلكترولايت" : "تم: الإلكترولايت") { life.toggleHealth(\.electrolyte) }
            }
        }
        NoteField(initial: h.note, placeholder: "ملاحظة على الأكل…") { life.setHealthNote(life.today, $0) }
            .padding(.top, T.s3)
    }
}

// MARK: - النوم

private struct SleepView: View {
    @EnvironmentObject var life: LifeStore
    @State private var sheet: SleepSheet?

    private enum SleepSheet: Identifiable {
        case plan, weekend, nap, night(String)
        var id: String {
            switch self {
            case .plan: return "plan"
            case .weekend: return "weekend"
            case .nap: return "nap"
            case .night(let d): return "n" + d
            }
        }
    }

    var body: some View {
        // كل الشاشة بصندوق واحد عشان الأوراق تفتح من أي مكان (حتى لو نزلت تحت)
        VStack(alignment: .leading, spacing: 0) { content }
            .sheet(item: $sheet) { s in
                switch s {
                case .plan:
                    TimeSheet(title: "وقت القعدة", note: "المنبه يرن من الأحد لين الخميس", label: "أقعد",
                              initial: life.wakePlanMin) { m in
                        life.act("تم: القعدة \(LFmt.clock(m))") { life.setWakePlan(m) }
                    }
                    .sheetStyle(440)
                case .weekend:
                    let day = life.tomorrow
                    TimeSheet(title: "منبه باجر (\(DateKit.dayName(day)))", note: "يرن باجر بس، وبعدها يرجع بدون منبه",
                              label: "أقعد", initial: life.d.sleep.weekendTimes?[day].flatMap { LFmt.minutesOf($0) } ?? life.weekendDefault,
                              clearText: life.alarmOn(day) ? "طفّه" : nil,
                              onClear: { life.act("طفيت منبه باجر") { life.setWeekendAlarm(day, nil) } }) { m in
                        life.act("تم: منبه باجر \(LFmt.clock(m))") { life.setWeekendAlarm(day, m) }
                    }
                    .sheetStyle(470)
                case .nap:
                    NapSheet(day: life.today, initial: life.napToday?.min ?? 40) { _ in }
                        .environmentObject(life).sheetStyle(470)
                case .night(let d):
                    let n = life.night(d)
                    WakeSheet(day: d, wake: n?.wake ?? LFmt.hhmm(LifeStore.nowMinutes()),
                              sleep: n?.sleep ?? LFmt.hhmm(life.bedtime(DateKit.add(-1, to: d))))
                        .environmentObject(life).sheetStyle(380)
                }
            }
    }

    @ViewBuilder private var content: some View {
        let today = life.today
        let bed = life.bedtime(today)
        let nap = life.napToday
        let tn = life.todayNight
        let wkOn = life.tomorrowIsWeekend && life.alarmOn(life.tomorrow)
        SecHead(title: "الخطة")
        Card {
            ValueRow(title: "القعدة", sub: "من الأحد لين الخميس") {
                TimeChip(text: LFmt.clock(life.wakePlanMin), label: "غيّر وقت القعدة") { sheet = .plan }
                Switch(on: life.d.sleep.alarm, label: "منبه القعدة") { life.act("المنبه") { life.toggleAlarm() } }
            }
            RowLine()
            ValueRow(title: "الجمعة والسبت", sub: weekendSub) {
                if life.tomorrowIsWeekend {
                    if wkOn {
                        TimeChip(text: LFmt.clock(life.wakeFor(life.tomorrow)), label: "غيّر منبه باجر") { sheet = .weekend }
                    } else {
                        PillButton(text: "شغّله لباجر", ghost: true) { sheet = .weekend }
                    }
                }
            }
            RowLine()
            ValueRow(title: "لو نمت الحين",
                     sub: life.sleepHours == nil ? "باجر ماكو وقت قعدة" : "تقعد " + LFmt.clock(life.wakeFor(LifeStore.nowMinutes() < 720 ? today : life.tomorrow)),
                     value: life.sleepHours.map { "بعد " + LFmt.dur($0) } ?? "—", valueDim: life.sleepHours == nil)
        }
        SecHead(title: "اليوم", trailing: "اضغط أي وقت تعدله")
        Card {
            ValueRow(title: "قعدت", sub: "الصبح") {
                TimeChip(text: tn.map { LFmt.clock(LFmt.minutesOf($0.wake) ?? 0) } ?? "سجّل", label: "وقت القعدة") { sheet = .night(today) }
            }
            RowLine()
            ValueRow(title: "قيّلت", sub: napSub(nap, bed)) {
                TimeChip(text: nap.map { LFmt.dur($0.min) } ?? "سجّل", label: "مدة القيلولة") { sheet = .nap }
            }
            RowLine()
            ValueRow(title: "نمت البارحة", sub: tn.map { "نمت " + LFmt.dur($0.minutes) } ?? "مع وقت القعدة") {
                TimeChip(text: tn.map { LFmt.clock(LFmt.minutesOf($0.sleep) ?? 0) } ?? "سجّل", label: "وقت النوم") { sheet = .night(today) }
            }
        }
        SecLabel(text: "الليالي اللي طافت")
        Card {
            let past = Array(life.nightsSorted.filter { $0.day != today }.prefix(10))
            ForEach(Array(past.enumerated()), id: \.element.id) { i, n in
                if i > 0 { RowLine() }
                LinkRow(num: DateKit.dayName(DateKit.add(-1, to: n.day)), title: LFmt.dur(n.minutes),
                        sub: LFmt.clock(LFmt.minutesOf(n.sleep) ?? 0) + " ← " + LFmt.clock(LFmt.minutesOf(n.wake) ?? 0)
                            + (n.note.isEmpty ? "" : " · " + n.note)) { sheet = .night(n.day) }
            }
        }
        Foot(text: "المنبه الحين إشعار عادي بصوت. المنبه الحقيقي (مثل الساعة) يحتاج iOS 26 ونسخة بناء أحدث")
    }

    private var weekendSub: String {
        guard life.tomorrowIsWeekend else { return "بدون منبه، إلا إذا شغّلته قبل لا تنام" }
        return life.alarmOn(life.tomorrow) ? "منبه باجر شغال · اضغط الوقت تغيّره" : "بدون منبه، إلا إذا شغّلته قبل لا تنام"
    }

    private func napSub(_ nap: NapLog?, _ bed: Int) -> String {
        guard nap != nil else { return "العصر" }
        return "العصر"
    }
}

/// ورقة وقت وحدة: + و−، وحفظ
private struct TimeSheet: View {
    let title: String
    var note: String? = nil
    let label: String
    let initial: Int
    var clearText: String? = nil
    var onClear: (() -> Void)? = nil
    let onSave: (Int) -> Void
    @State private var m = 300

    var body: some View {
        EditSheet(title: title, note: note, clearText: clearText, onSave: { onSave(m) }, onClear: onClear) {
            TimeWheel(value: $m)
        }
        .onAppear { m = initial }
    }
}

