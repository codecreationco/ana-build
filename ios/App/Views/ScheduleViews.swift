import SwiftUI

// أجزاء الجدول داخل تاب «اليوم»: الأسبوع، والشبكة، والمواعيد الخاصة

// MARK: - الأسبوع يوم بيوم

struct WeekAgenda: View {
    @EnvironmentObject var life: LifeStore
    @Binding var offset: Int

    private var week: String { DateKit.add(offset * 7, to: DateKit.weekStart(life.today)) }

    private var label: String {
        switch offset {
        case 0: return "هالأسبوع"
        case 1: return "الأسبوع الجاي"
        case -1: return "الأسبوع اللي طاف"
        default: return offset > 0 ? "بعد \(offset) أسابيع" : "قبل \(-offset) أسابيع"
        }
    }

    var body: some View {
        HStack {
            nav("chevron.right", "الأسبوع اللي قبل") { offset -= 1 }
            Spacer()
            Button { offset = 0 } label: {
                Text(label).font(T.f(15)).foregroundStyle(T.muted).frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            nav("chevron.left", "الأسبوع اللي بعد") { offset += 1 }
        }
        .padding(.top, T.s2)
        ForEach(0..<7, id: \.self) { i in
            DayBlock(day: DateKit.add(i, to: week))
        }
    }

    private func nav(_ icon: String, _ a11y: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(T.muted)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}

private struct DayBlock: View {
    @EnvironmentObject var life: LifeStore
    let day: String

    var body: some View {
        let list = life.events(on: day)
        let today = day == life.today
        HStack {
            Text(verbatim: "\(DateKit.dayName(day)) \(DateKit.dayNum(day)) \(DateKit.monthName(day))")
                .foregroundStyle(today ? T.accent : T.muted)
            Spacer()
            if today { Text("اليوم").foregroundStyle(T.muted) }
        }
        .font(T.f(14))
        .padding(.horizontal, 2)
        .padding(.top, T.s5)
        .padding(.bottom, T.s3)
        Card {
            if list.isEmpty {
                Text("ما في شي").font(T.f(15)).foregroundStyle(T.faint)
                    .padding(.horizontal, 18).frame(minHeight: 52)
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                if i > 0 { RowLine() }
                HStack(spacing: T.s3) {
                    Text(e.when).font(T.f(14)).monospacedDigit().foregroundStyle(T.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(width: 58, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.title).font(T.f(18)).foregroundStyle(T.ink)
                        if let s = e.status, s != .confirmed {
                            Text(s.label).font(T.f(14)).foregroundStyle(T.muted)
                        } else if let det = e.detail {
                            Text(det).font(T.f(14)).foregroundStyle(T.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .frame(minHeight: 52)
            }
        }
    }
}

// MARK: - الشبكة: من اليوم لين شهرين جدام، أو لين نهاية الكورس

private enum CellState { case done, planned, missed, none }

private struct GridCell {
    var text: String
    var state: CellState
}

/// سطر بالشبكة: عنوان شهر، أو فاصل أسبوع، أو يوم
private enum GridLine: Identifiable {
    case month(String, String)
    case week(String, String)
    case day(String)

    var id: String {
        switch self {
        case .month(let k, _): return "m" + k
        case .week(let k, _): return "w" + k
        case .day(let k): return k
        }
    }
}

struct GridBoard: View {
    @EnvironmentObject var life: LifeStore
    @State private var toEnd = false

    private let cols = ["منطق", "متاجر", "فرائد", "تقرير", "وزان", "نادي", "طلعة"]
    private let initials = ["ح", "ن", "ث", "ر", "خ", "ج", "س"]
    private let dayW: CGFloat = 40
    private let apptW: CGFloat = 58
    private let gap: CGFloat = 3

    private var courseEnd: String? { life.d.courses.compactMap(\.endsOn).max() }

    private var endDay: String {
        if toEnd, let e = courseEnd { return e }
        return DateKit.add(60, to: life.today)
    }

    private var lines: [GridLine] {
        var out: [GridLine] = []
        let start = life.today
        var day = start
        var weekN = 0
        while day <= endDay {
            if day != start && DateKit.weekday(day) == 7 { weekN += 1 }
            if day == start || DateKit.dayNum(day) == 1 {
                out.append(.month(day, "\(DateKit.monthName(day)) \(year(day))"))
            } else if DateKit.weekday(day) == 7 {
                out.append(.week(day, weekN == 1 ? "الأسبوع الجاي" : "أسبوع \(DateKit.dayNum(day)) \(DateKit.monthName(day))"))
            }
            out.append(.day(day))
            day = DateKit.add(1, to: day)
        }
        return out
    }

    private func year(_ k: String) -> Int {
        guard let d = DateKit.date(k) else { return 0 }
        return DateKit.cal.component(.year, from: d)
    }

    var body: some View {
        rangeBar
            .padding(.top, T.s3)
            .padding(.bottom, T.s2)
        Section {
            ForEach(lines) { l in
                switch l {
                case .month(_, let t):
                    VStack(spacing: 0) {
                        Text(t).font(T.f(14)).foregroundStyle(T.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2).padding(.top, 10).padding(.bottom, 4)
                        RowLine()
                    }
                    .padding(.bottom, 4)
                case .week(_, let t):
                    Text(t).font(T.f(12)).foregroundStyle(T.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2).padding(.top, 8).padding(.bottom, 2)
                case .day(let k):
                    row(k).padding(.vertical, gap / 2)
                }
            }
            Foot(text: "الأرقام رقم الدرس اللي عليك ذاك اليوم · U وL نوع التمرين · وزان بالساعات · انزل تحت والعناوين تبقى فوق", center: false)
        } header: {
            HStack(spacing: gap) {
                head("اليوم").frame(width: dayW)
                head("خاصة").frame(width: apptW)
                ForEach(cols, id: \.self) { c in head(c).frame(maxWidth: .infinity) }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .background(T.bg)
            .overlay(alignment: .bottom) { RowLine() }
            .padding(.horizontal, -20)
        }
    }

    private func head(_ t: String) -> some View {
        Text(t).font(T.f(12)).foregroundStyle(T.muted).lineLimit(1).minimumScaleFactor(0.7)
            .padding(.vertical, 4)
    }

    private var rangeBar: some View {
        HStack(spacing: T.s2) {
            rangeButton("شهرين", on: !toEnd) { toEnd = false }
            if courseEnd != nil {
                rangeButton("لين نهاية الكورس", on: toEnd) { toEnd = true }
            }
            Spacer()
            Text(verbatim: "لين \(DateKit.dayNum(endDay)) \(DateKit.monthName(endDay))")
                .font(T.f(13)).foregroundStyle(T.muted)
        }
    }

    private func rangeButton(_ t: String, on: Bool, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            Text(t)
                .font(T.f(14))
                .foregroundStyle(on ? T.pillInk : T.muted)
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
                .background(Capsule().fill(on ? T.pill : Color.clear))
                .overlay(Capsule().stroke(on ? Color.clear : T.line, lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func row(_ day: String) -> some View {
        let isToday = day == life.today
        let wd = DateKit.weekday(day)
        return HStack(spacing: gap) {
            Text(verbatim: "\(initials[wd - 1]) \(DateKit.dayNum(day))")
                .font(T.f(13)).monospacedDigit()
                .foregroundStyle(isToday ? T.accent : T.muted)
                .frame(width: dayW, height: 32)
            apptCell(day)
            ForEach(cols, id: \.self) { c in cellView(cell(c, day)) }
        }
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(isToday ? T.accent : Color.clear, lineWidth: 1.5).padding(-2.5))
        .accessibilityElement(children: .combine)
    }

    private func apptCell(_ day: String) -> some View {
        let list = life.d.special.filter { $0.day == day }
        let fam = life.d.weekly.filter { $0.kind == .family && life.isOn($0, day: day) }
            .filter { e in !list.contains { $0.title == e.title } }
        let titles = list.map { a -> String in
            let clean = a.title.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            var short = clean.split(separator: " ").first.map(String.init) ?? clean
            if clean.contains("إخوان") { short = "إخوان" }
            if clean.contains("ملكة") { short = "الملكة" }
            if let t = DateKit.timeLabel(a.time) { short = "موعد " + t.replacingOccurrences(of: " ص", with: "").replacingOccurrences(of: " م", with: "") }
            return a.status == .postponed ? short + " · تأجل" : short
        } + fam.map(\.short)
        return Text(titles.joined(separator: "، "))
            .font(T.f(11))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.center)
            .foregroundStyle(T.muted)
            .frame(width: apptW, height: 32)
            .background(RoundedRectangle(cornerRadius: 8).fill(titles.isEmpty ? T.cellEmpty : T.card))
    }

    @ViewBuilder
    private func cellView(_ c: GridCell) -> some View {
        switch c.state {
        case .none:
            RoundedRectangle(cornerRadius: 8).fill(T.cellEmpty)
                .frame(maxWidth: .infinity).frame(height: 32)
        case .missed:
            Text(c.text).font(T.f(12)).monospacedDigit().foregroundStyle(T.muted)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity).frame(height: 32)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(T.dim, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        default:
            Text(c.text).font(T.f(12)).monospacedDigit()
                .foregroundStyle(c.state == .done ? T.faint : T.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity).frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(T.card))
        }
    }

    private func passed(_ day: String, time: String?) -> Bool {
        if day < life.today { return true }
        if day > life.today { return false }
        guard let t = LFmt.minutesOf(time) else { return false }
        return LifeStore.nowMinutes() > t + 60
    }

    private func nums(_ v: [Int]) -> String {
        guard let a = v.last else { return "" }
        return v.count > 1 ? "\(a)+" : "\(a)"
    }

    /// أول يوم بالخطة الجاية: اليوم، وإذا خلصت اليوم شي فمن باجر
    private func planStart(_ id: String, stage: Int) -> String {
        life.logs(on: life.today, course: id, stage: stage).isEmpty ? life.today : DateKit.add(1, to: life.today)
    }

    private func cell(_ col: String, _ day: String) -> GridCell {
        let wd = DateKit.weekday(day)
        switch col {
        case "منطق":
            guard let c = life.course("mantiq") else { return GridCell(text: "", state: .none) }
            let taught = life.logs(on: day, course: c.id, stage: 1)
            if !taught.isEmpty { return GridCell(text: nums(taught), state: .done) }
            guard c.days.contains(wd) else { return GridCell(text: "", state: .none) }
            if day == life.today && passed(day, time: c.time) { return GridCell(text: "؟", state: .missed) }
            return GridCell(text: life.teachNumber(c, on: day).map(String.init) ?? "", state: .planned)
        case "متاجر":
            guard let c = life.course("matajir") else { return GridCell(text: "", state: .none) }
            let v = life.logs(on: day, course: c.id, stage: 0)
            if !v.isEmpty { return GridCell(text: nums(v), state: .done) }
            let s = planStart(c.id, stage: 0)
            guard day >= s else { return GridCell(text: "", state: .none) }
            return GridCell(text: "\(c.stageA + 1 + DateKit.diff(s, day))", state: .planned)
        case "فرائد":
            guard let c = life.course("faraid"), c.days.contains(wd) else { return GridCell(text: "", state: .none) }
            let v = life.logs(on: day, course: c.id, stage: 0)
            if !v.isEmpty { return GridCell(text: nums(v), state: .done) }
            let n = life.lessonNumber(c, on: day).map(String.init) ?? ""
            return GridCell(text: n, state: passed(day, time: c.time) ? .missed : .planned)
        case "تقرير":
            guard let c = life.course("faraid") else { return GridCell(text: "", state: .none) }
            let v = life.logs(on: day, course: c.id, stage: 1)
            if !v.isEmpty { return GridCell(text: nums(v), state: .done) }
            let s = planStart(c.id, stage: 1)
            guard day >= s, wd != 6 else { return GridCell(text: "", state: .none) }
            // تقرير واحد كل يوم ما عدا الجمعة
            var n = c.stageB + 1
            var k = s
            while k < day { if DateKit.weekday(k) != 6 { n += 1 }; k = DateKit.add(1, to: k) }
            return GridCell(text: "\(n)", state: .planned)
        case "وزان":
            let m = life.d.work.first?.logs[day] ?? 0
            if m > 0 { return GridCell(text: LFmt.hours(m), state: .done) }
            if (1...5).contains(wd) { return GridCell(text: "·", state: .planned) }
            return GridCell(text: "", state: .none)
        case "نادي":
            guard let w = life.workout(on: day) else { return GridCell(text: "", state: .none) }
            let s = life.setsDone(day, w)
            let k = String(w.kind.prefix(1))
            if s.total > 0 && s.done == s.total { return GridCell(text: k, state: .done) }
            return GridCell(text: k, state: .planned)
        default:
            let ev = life.d.weekly.filter { $0.kind == .social && life.isOn($0, day: day) }
            guard let e = ev.first else { return GridCell(text: "", state: .none) }
            return GridCell(text: e.short, state: .planned)
        }
    }
}

// MARK: - المواعيد الخاصة

struct SpecialList: View {
    @EnvironmentObject var life: LifeStore

    var body: some View {
        let all = life.specialSorted
        let up = all.filter { ($0.day ?? "") >= life.today }
        let noDay = all.filter { $0.day == nil }
        let past = all.filter { if let k = $0.day { return k < life.today } else { return false } }
        if !up.isEmpty {
            SecLabel(text: "الجاية", trailing: "\(up.count)")
            apptCard(up)
        }
        if !noDay.isEmpty {
            SecLabel(text: "بدون يوم")
            apptCard(noDay)
        }
        if !past.isEmpty {
            SecLabel(text: "اللي طافت")
            apptCard(past).opacity(0.6)
        }
        Foot(text: "موعد جديد؟ اكتبه بالدفتر وأنا أضيفه")
    }

    private func apptCard(_ list: [SpecialAppt]) -> some View {
        Card {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, a in
                if i > 0 { RowLine() }
                ApptRow(appt: a)
            }
        }
    }
}

private struct ApptRow: View {
    @EnvironmentObject var life: LifeStore
    let appt: SpecialAppt

    var body: some View {
        HStack(alignment: .top, spacing: T.s4) {
            VStack(spacing: 0) {
                if let k = appt.day {
                    Text(verbatim: "\(DateKit.dayNum(k))").font(T.f(26, .bold)).monospacedDigit().foregroundStyle(T.ink)
                    Text(DateKit.dayShortName(k)).font(T.f(13)).foregroundStyle(T.muted)
                } else {
                    Text("؟").font(T.f(26, .bold)).foregroundStyle(T.ink)
                    Text("بدون يوم").font(T.f(13)).foregroundStyle(T.muted)
                }
            }
            .frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(appt.title).font(T.f(18)).foregroundStyle(T.ink)
                    .strikethrough(appt.status == .cancelled)
                Text(whenText).font(T.f(14)).foregroundStyle(T.muted)
                NoteField(initial: appt.note ?? "", placeholder: "ملاحظة…", boxed: false, size: 14, color: T.muted) {
                    life.setApptNote(appt.id, $0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach(ApptStatus.allCases, id: \.self) { s in
                    Button(s.label) { life.act("الحالة: \(s.label)") { life.setStatus(appt.id, s) } }
                }
            } label: {
                StatusChip(status: appt.status)
                    .frame(minHeight: 44, alignment: .top)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("الحالة: \(appt.status.label)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, T.s4)
    }

    private var whenText: String {
        guard let k = appt.day else { return "الموعد ما انعرف" }
        var s = DateKit.countdown(from: life.today, to: k)
        if let t = DateKit.timeLabel(appt.time) { s += " · " + t }
        return s
    }
}
