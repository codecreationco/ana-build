import SwiftUI

/// تاب اليوم: اليوم، الأسبوع، الشبكة، المواعيد، الصلاة.
struct TodayTab: View {
    @EnvironmentObject var life: LifeStore
    @Binding var seg: Int
    @State private var weekOffset = 0
    @State private var dayOffset = 0

    var body: some View {
        TabPage {
            PageHead(title: "اليوم", sub: subtitle)
            SegText(items: ["اليوم", "الأسبوع", "الشبكة", "المواعيد", "الصلاة"], sel: $seg)
            switch seg {
            case 0:
                DayNav(offset: $dayOffset)
                if dayOffset == 0 { TodayList() } else { OtherDay(day: DateKit.add(dayOffset, to: life.today)) }
            case 1: WeekAgenda(offset: $weekOffset)
            case 2: GridBoard()
            case 3: SpecialList()
            default: PrayerView()
            }
        }
        .onReceive(Snap.shared.$index) { i in
            let st = Snap.steps[min(i, Snap.steps.count - 1)]
            if Snap.on, st.tab == 1 { dayOffset = st.day }
        }
    }

    private var subtitle: String {
        switch seg {
        case 1:
            let a = DateKit.add(weekOffset * 7, to: DateKit.weekStart(life.today)), b = DateKit.add(6, to: a)
            return "\(DateKit.dayNum(a)) \(DateKit.monthName(a)) – \(DateKit.dayNum(b)) \(DateKit.monthName(b))"
        case 3:
            return "المواعيد الخاصة"
        default:
            let k = seg == 0 ? DateKit.add(dayOffset, to: life.today) : life.today
            return "\(DateKit.dayName(k))، \(DateKit.dayNum(k)) \(DateKit.monthName(k))"
        }
    }
}

// MARK: - التنقل بين الأيام

/// ‹ اليوم › مثل التنقل بين الأسابيع
private struct DayNav: View {
    @Binding var offset: Int

    private var label: String {
        switch offset {
        case 0: return "اليوم"
        case 1: return "باجر"
        case -1: return "أمس"
        case 2: return "بعد باجر"
        default: return offset > 0 ? "بعد \(offset) أيام" : "قبل \(-offset) أيام"
        }
    }

    var body: some View {
        HStack {
            nav("chevron.right", "اليوم اللي قبل") { offset -= 1 }
            Spacer()
            Button { offset = 0 } label: {
                Text(label).font(T.f(15)).foregroundStyle(offset == 0 ? T.muted : T.accent).frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityHint("يرجع لليوم")
            Spacer()
            nav("chevron.left", "اليوم اللي بعد") { offset += 1 }
        }
        .padding(.top, T.s2)
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

/// يوم غير اليوم: اللي بالجدول، والمشاوير، والدروس اللي عليك (أو اللي سجلتها إذا طاف)
private struct OtherDay: View {
    @EnvironmentObject var life: LifeStore
    let day: String

    private struct Row: Identifiable {
        let id: String
        var time: Int?
        var when: String?
        var title: String
        var sub: String?
        var done = false
        var chore: String? = nil
    }

    var body: some View {
        let rows = build()
        let groups: [(String, [Row])] = [
            ("الصبح", rows.filter { ($0.time ?? 9999) < 720 }),
            ("بليل", rows.filter { if let t = $0.time { return t >= 720 } else { return false } }),
            ("بأي وقت", rows.filter { $0.time == nil }),
        ]
        let past = day < life.today
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: past ? "\(Count.things(rows.count)) · خلصت \(rows.filter(\.done).count)" : Count.things(rows.count))
                .font(T.f(15)).foregroundStyle(T.muted)
                .padding(.top, T.s2)
                .padding(.horizontal, 2)
            if rows.isEmpty {
                EmptyNote(text: "ما في شي بهاليوم").padding(.top, T.s4)
            }
            ForEach(groups.indices, id: \.self) { gi in
                let g = groups[gi]
                if !g.1.isEmpty {
                    SecHead(title: g.0, trailing: "\(g.1.count)")
                    Card {
                        ForEach(Array(g.1.enumerated()), id: \.element.id) { i, r in
                            if i > 0 { RowLine() }
                            if let c = r.chore {
                                ItemRow(time: r.when, timeCol: g.0 != "بأي وقت", title: r.title, sub: r.sub, done: r.done) {
                                    life.act((r.done ? "رجعت: " : "تم: ") + r.title) { life.toggleChore(c, day) }
                                }
                            } else {
                                ItemRow(time: r.when, timeCol: g.0 != "بأي وقت", title: r.title, sub: r.sub, done: r.done)
                            }
                        }
                    }
                }
            }
            NoteField(initial: life.dayNote(day), placeholder: "ملاحظة على \(DateKit.dayName(day))…") {
                life.setDayNote(day, $0)
            }
            .padding(.top, T.s5)
        }
    }

    private func build() -> [Row] {
        var out: [Row] = []
        // قبل لا أطلع: القهوة مع الكرياتين، والمطارة (وفيها الإلكترولايت أيام النادي)
        let gym = life.workout(on: day) != nil
        let h = life.d.health[day]
        out.append(Row(id: "leave", time: 400, when: "قبل الطلعة", title: "قبل لا أطلع",
                       sub: gym ? "القهوة مع الكرياتين، والمطارة مع الإلكترولايت" : "القهوة مع الكرياتين، والمطارة",
                       done: day < life.today && (h?.creatine ?? false) && (h?.bottle ?? false)))
        // الجدول: الدروس والنادي والمواعيد والطلعات
        for e in life.events(on: day) {
            // موعد بدون وقت: ما نكتب «اليوم» جنبه
            let when = e.kind == .special && !e.when.contains(":") ? "—" : e.when
            out.append(Row(id: e.id, time: e.sortMin, when: when,
                           title: e.title, sub: e.status.map { $0 == .confirmed ? (e.detail ?? "") : $0.label } ?? e.detail))
        }
        // المشاوير
        for c in life.choresOn(day) {
            out.append(Row(id: "c-" + c.id, time: LFmt.minutesOf(c.time), when: DateKit.timeLabel(c.time), title: c.title,
                           sub: c.sub ?? (c.routine ? nil : "مو روتيني"), done: life.isChoreDone(c.id, day), chore: c.id))
        }
        if day < life.today {
            // اللي سجلته ذاك اليوم
            for l in life.d.lessonLogs.filter({ $0.day == day }) {
                guard let c = life.course(l.course) else { continue }
                let t: String
                switch (c.mode, l.stage) {
                case (.teach, 0): t = "تحضير \(c.title)"
                case (.teach, _): continue   // التدريس طالع فوق بالجدول
                case (.online, 0): continue  // الحضور طالع فوق بالجدول
                case (.online, _): t = "تقرير \(c.shortName)"
                case (.recording, _): t = "تقرير \(c.shortName)"
                }
                out.append(Row(id: "l-\(l.course)-\(l.stage)-\(l.num)", title: t, sub: "درس \(l.num)", done: true))
            }
            for b in life.d.books {
                if let p = b.logs[day] { out.append(Row(id: "b-" + b.id, title: "قراءة \(b.title)", sub: "وصلت صفحة \(p)", done: true)) }
            }
        } else {
            // اللي عليك ذاك اليوم بالخطة
            for c in life.d.courses {
                switch c.mode {
                case .recording:
                    if let n = life.planned(c, stage: 0, on: day) {
                        out.append(Row(id: "p-\(c.id)", title: "تقرير \(c.shortName)", sub: "درس \(n)"))
                    }
                case .online:
                    if let n = life.planned(c, stage: 1, on: day) {
                        out.append(Row(id: "p-\(c.id)", title: "تقرير \(c.shortName)", sub: "درس \(n)"))
                    }
                case .teach:
                    let tomorrow = DateKit.add(1, to: day)
                    if let n = life.teachNumber(c, on: tomorrow), n > c.stageA {
                        out.append(Row(id: "p-\(c.id)", title: "تحضير \(c.title)", sub: "درس \(n) · لدرس باجر"))
                    }
                }
            }
            for b in life.d.books {
                out.append(Row(id: "b-" + b.id, title: "قراءة \(b.title)", sub: "من صفحة \(b.page)"))
            }
        }
        return out.sorted { ($0.time ?? 9999) < ($1.time ?? 9999) }
    }
}

// MARK: - اليوم: الصبح، المسا، بأي وقت

private struct TodayList: View {
    @EnvironmentObject var life: LifeStore
    @State private var asking: Book?
    @State private var pageText = ""

    var body: some View {
        let items = life.todayItems
        let next = life.nextItem(items)
        let groups: [(String, [TodayItem])] = [
            ("الصبح", items.filter { $0.slot == 0 }),
            ("بليل", items.filter { $0.slot == 1 }),
            ("بأي وقت", items.filter { $0.slot == 2 }),
        ]
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "\(Count.things(items.count)) · خلصت \(items.filter(\.done).count)")
                .font(T.f(15)).foregroundStyle(T.muted)
                .padding(.top, T.s4)
                .padding(.horizontal, 2)
            ForEach(groups.indices, id: \.self) { gi in
                let g = groups[gi]
                if !g.1.isEmpty {
                    SecHead(title: g.0, trailing: trailing(g.0, g.1))
                    Card {
                        ForEach(Array(g.1.enumerated()), id: \.element.id) { i, it in
                            if i > 0 { RowLine() }
                            ItemRow(time: it.timeText, timeCol: g.0 != "بأي وقت", title: it.title, sub: it.sub,
                                    tag: it.id == next?.id ? nextTag(it) : nil,
                                    done: it.done, next: it.id == next?.id) { tap(it) }
                                .contextMenu {
                                    if let c = life.course(of: it), it.time != nil {
                                        if c.link != nil {
                                            Button { life.enterLesson(c) } label: { Label("ادخل الدرس", systemImage: "video") }
                                        }
                                        Button { life.act("ماكو درس اليوم: \(c.shortName)") { life.toggleNoLesson(c, life.today) } } label: {
                                            Label("اليوم ماكو درس", systemImage: "xmark.circle")
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            if let f = tomorrowLine { Foot(text: f) }
            NoteField(initial: life.dayNote(life.today), placeholder: "ملاحظة اليوم…") {
                life.setDayNote(life.today, $0)
            }
            .padding(.top, T.s3)
        }
        .alert("وصلت صفحة كم؟", isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } })) {
            TextField("الصفحة", text: $pageText).keyboardType(.numberPad)
            Button("حفظ") {
                if let b = asking, let p = NumParse.int(pageText) {
                    life.act("تم: وصلت صفحة \(p)") { life.savePage(b.id, p) }
                }
                asking = nil
            }
            Button("إلغاء", role: .cancel) { asking = nil }
        } message: {
            if let b = asking { Text(verbatim: "\(b.title) · كنت بصفحة \(b.page)") }
        }
    }

    private func trailing(_ name: String, _ list: [TodayItem]) -> String {
        let d = list.filter(\.done).count
        let base = "\(list.count)" + (d > 0 ? " · خلصت \(d)" : "")
        return name == "بأي وقت" && d == 0 ? base + " · بدون وقت محدد" : base
    }

    private func nextTag(_ it: TodayItem) -> String {
        guard let t = it.time else { return "الجاي" }
        return "الجاي · " + LFmt.until(t - LifeStore.nowMinutes())
    }

    private func tap(_ it: TodayItem) {
        if case .book(let id) = it.kind, !it.done {
            if let b = life.d.books.first(where: { $0.id == id }) {
                pageText = ""
                asking = b
            }
            return
        }
        if case .book(let id) = it.kind, it.done {
            // نشيل قراءة اليوم
            life.act("رجعت: \(it.title)") {
                if let i = life.d.books.firstIndex(where: { $0.id == id }) {
                    life.d.books[i].logs[life.today] = nil
                    let prev = life.d.books[i].logs.keys.sorted().last.flatMap { life.d.books[i].logs[$0] }
                    life.d.books[i].page = prev ?? life.d.books[i].page
                    life.save()
                }
            }
            return
        }
        life.act((it.done ? "رجعت: " : "تم: ") + it.title) { life.toggle(it) }
    }

    private var tomorrowLine: String? {
        let k = life.tomorrow
        if let a = life.d.special.first(where: { $0.day == k }) {
            return "باجر: " + a.title + (a.status == .confirmed ? "" : " · " + a.status.label)
        }
        if let e = life.events(on: k).first { return "باجر: " + e.title + " · " + e.when }
        return nil
    }
}

// MARK: - شريط «تم · تراجع»

struct UndoBar: View {
    @EnvironmentObject var life: LifeStore

    var body: some View {
        if let t = life.toast {
            HStack(spacing: T.s2) {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(T.muted)
                Text(t.text).font(T.f(15)).foregroundStyle(T.ink).lineLimit(1)
                Spacer(minLength: T.s2)
                Button { withAnimation(.easeOut(duration: 0.2)) { life.undo() } } label: {
                    Text("تراجع").font(T.f(15, .bold)).foregroundStyle(T.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(T.card3))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card2))
            .shadow(color: .black.opacity(0.6), radius: 16, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: t.id) {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeOut(duration: 0.25)) { if life.toast?.id == t.id { life.toast = nil } }
            }
        }
    }
}

// MARK: - الصلاة

struct PrayerView: View {
    @EnvironmentObject var life: LifeStore

    var body: some View {
        let list = life.prayers(life.today)
        let prayable = list.filter(\.pray)
        let done = prayable.filter { life.prayed($0.id, life.today) }.count
        let next = life.nextPrayer
        let cur = life.currentPrayer
        VStack(spacing: 0) {
            if let n = next {
                Text("الجاي").font(T.f(14)).foregroundStyle(T.accent)
                Text(verbatim: "\(n.0.name) · \(LFmt.clock(n.0.min))").font(T.f(30, .bold)).foregroundStyle(T.ink)
                Text(LFmt.until(n.1)).font(T.f(15)).foregroundStyle(T.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
        .padding(.top, T.s5)

        SecHead(title: "صلوات اليوم", trailing: "صليت \(done) من \(prayable.count)")
        Card {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, p in
                if i > 0 { RowLine() }
                if p.pray {
                    let isCur = cur?.id == p.id && !life.prayed(p.id, life.today)
                    let isNext = !isCur && next?.0.id == p.id && cur == nil
                    ItemRow(time: LFmt.clock(p.min), title: p.name,
                            sub: [p.note, p.end.map { "القضاء " + LFmt.clock($0) }].compactMap { $0 }.joined(separator: " · "),
                            tag: isCur ? "الحين" : (isNext ? "الجاي" : nil),
                            done: life.prayed(p.id, life.today), next: isCur || isNext, checkLabel: "صليت") {
                        let was = life.prayed(p.id, life.today)
                        life.act((was ? "رجعت: " : "تم: صلاة ") + p.name) { life.togglePrayer(p.id, life.today) }
                    }
                } else {
                    HStack(spacing: T.s3) {
                        Text(LFmt.clock(p.min)).font(T.f(14)).monospacedDigit().foregroundStyle(T.muted)
                            .frame(width: 58, alignment: .leading)
                        Text(p.name).font(T.f(18)).foregroundStyle(T.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(p.id == "sunrise" ? "قضاء الفجر" : "قضاء المغرب").font(T.f(13)).foregroundStyle(T.muted)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .frame(minHeight: 52)
                }
            }
        }

        SecHead(title: "التنبيه")
        Card {
            ValueRow(title: "منبه بوقت كل صلاة", sub: "يرن بوقت الصلاة بالضبط") {
                Switch(on: life.d.prayerAlarm, label: "منبه الصلاة") { life.setPrayerAlarm(!life.d.prayerAlarm) }
            }
            RowLine()
            ValueRow(title: "«صليت؟» تحت اسمك", sub: "بالرئيسية، من وقت الصلاة لين الصلاة اللي بعدها") {
                Switch(on: life.d.prayerAsk, label: "صليت تحت اسمك") { life.setPrayerAsk(!life.d.prayerAsk) }
            }
        }
        Foot(text: "مدينة الكويت، على طريقة تقويم الصايغ (الفرق دقيقة بالأكثر). إذا ما سجلت إنك صليت، يجيك تنبيه قبل القضاء بـ 20 دقيقة")
    }
}
