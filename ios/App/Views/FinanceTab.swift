import SwiftUI

/// تاب المصاريف: الحركات توصل من رسائل البنك، والميزانية والبنود والملخصات من محادثة المالية.
struct FinanceTab: View {
    @EnvironmentObject var life: LifeStore
    @State private var open: FinTx?
    @State private var showAll = false
    @State private var wish = ""
    @State private var pending = 0
    @FocusState private var wishFocus: Bool

    static let buildColor = Color(hex: "#E5A33B")
    static let goalColor = Color(hex: "#5DB38C")
    private static let palette = ["#E39B3F", "#5FA8D3", "#9C8CF0", "#62B58F", "#D7727E", "#C9B458", "#4FB6B0", "#B07CC6"]

    static func color(_ c: FinCat, _ i: Int) -> Color {
        if c.category == nil { return T.dim }
        if let h = c.color, !h.isEmpty { return Color(hex: h) }
        return Color(hex: palette[i % palette.count])
    }

    var body: some View {
        TabPage {
            if let s = life.fin {
                PageHead(title: "المصاريف", sub: monthLine(s))
                hero(s)
                status(s)
                needs(s)
                cats(s)
                txList(s)
                wishlist(s)
                notes(s)
                if pending > 0 {
                    Foot(text: pending == 1 ? "رسالة وحدة من البنك تنتظر النت" : "\(pending) رسائل من البنك تنتظر النت")
                }
            } else {
                PageHead(title: "المصاريف")
                EmptyNote(text: life.finError ? "ما قدرت أوصل لقاعدة البيانات. تأكد من النت." : "يجيب المصاريف…")
                    .padding(.top, T.s5)
            }
        }
        .task {
            life.finLoadCache()
            pending = FinQueue.count
            await life.finRefresh()
            pending = FinQueue.count
        }
        .onReceive(NotificationCenter.default.publisher(for: FinQueue.changed)) { _ in
            Task { await life.finRefresh(); pending = FinQueue.count }
        }
        .sheet(item: $open) { t in
            FinTxSheet(tx: t, cats: life.fin?.cats ?? [])
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(T.bg)
        }
    }

    // MARK: - فوق

    private func monthLine(_ s: FinState) -> String {
        guard let d = s.start else { return "الشهر المالي" }
        let c = DateKit.cal.dateComponents([.day, .month], from: d)
        let (n, total) = s.days()
        return "من \(c.day ?? 1) \(DateKit.months[max(0, (c.month ?? 1) - 1)]) · يوم \(n) من \(total)"
    }

    /// عداد واحد: كم صرفت من المصروف، وخط صغير وين وصل الشهر
    private func hero(_ s: FinState) -> some View {
        let spent = s.spent
        let base = s.spendBase ?? 0
        let (n, total) = s.days()
        let monthPart = Double(n) / Double(total)
        let spentPart = base > 0 ? spent / base : 0
        let fast = spentPart > monthPart + 0.005
        return VStack(alignment: .leading, spacing: 0) {
            Text("صرفت").font(T.f(15)).foregroundStyle(T.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: Money.kd(spent)).font(T.f(44, .bold)).monospacedDigit().foregroundStyle(T.ink)
                Text("د.ك").font(T.f(17)).foregroundStyle(T.muted)
                Spacer(minLength: 0)
                if base > 0 {
                    Text(verbatim: "\(Money.pct(spent, base))٪")
                        .font(T.f(24, .bold)).monospacedDigit()
                        .foregroundStyle(spent > base ? RecorderCard.red : T.ink)
                }
            }
            if base > 0 {
                Text(verbatim: "من \(Money.kd(base)) · باقي \(Money.kd(max(0, base - spent)))")
                    .font(T.f(15)).foregroundStyle(T.muted)
                PaceBar(value: spentPart, mark: monthPart, color: fast ? FinanceTab.buildColor : FinanceTab.goalColor, height: 10)
                    .padding(.top, T.s3)
                HStack(spacing: 6) {
                    Image(systemName: fast ? "hare" : "tortoise").font(.system(size: 13)).foregroundStyle(fast ? FinanceTab.buildColor : T.muted)
                    Text(verbatim: "صرفت \(Money.pct(spent, base))٪ وطاف \(Int((monthPart * 100).rounded()))٪ من الشهر"
                         + (fast ? " · أسرع من الشهر" : " · ماشي زين"))
                        .font(T.f(14)).foregroundStyle(fast ? T.ink : T.muted)
                }
                .padding(.top, T.s3)
            } else {
                Text("المصروف الشهري ينضاف من محادثة المالية.")
                    .font(T.f(15)).foregroundStyle(T.muted)
                    .padding(.top, T.s1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, T.s4)
        .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
        .padding(.top, T.s5)
        .accessibilityElement(children: .combine)
    }

    // MARK: - حالة الشهر

    /// العلاوة وبدل السكن نزلوا؟ والالتزامات انخصمت؟
    private func status(_ s: FinState) -> some View {
        var rows: [(String, Bool, String)] = []
        func line(_ x: FinIn?, wait: String) -> String {
            guard let x else { return wait }
            return [x.amount.map { Money.kd($0) }, x.date.map(TxRow.when)].compactMap { $0 }.joined(separator: " · ")
        }
        rows.append(("العلاوة", s.allowance != nil, line(s.allowance, wait: "للحين ما نزلت")))
        rows.append(("بدل السكن", s.housing != nil, line(s.housing, wait: "للحين ما نزل · ينزل يوم 1 أو 2")))
        for c in s.commitments ?? [] {
            let paid = c.paid == true
            let sub = paid
                ? [c.paidAmount.map { Money.kd($0) }, RecSession.date(c.paidAt).map(TxRow.when)].compactMap { $0 }.joined(separator: " · ")
                : "للحين ما انخصم · " + c.when
            rows.append((c.name, paid, sub))
        }
        return Group {
            SecLabel(text: "حالة الشهر")
            Card {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    if i > 0 { RowLine() }
                    HStack(spacing: T.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.0).font(T.f(17)).foregroundStyle(T.ink)
                            Text(verbatim: r.2).font(T.f(13)).monospacedDigit().foregroundStyle(T.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        CheckMark(on: r.1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(minHeight: 56)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(r.1 ? "تم" : "للحين")
                }
            }
        }
    }

    // MARK: - البنود

    /// كل بند كم صرفت عليه، بس
    @ViewBuilder
    private func cats(_ s: FinState) -> some View {
        let list = (s.budget ?? []).filter { $0.category != nil || $0.used != 0 }
        if !list.isEmpty {
            SecLabel(text: "وين راحت")
            Card {
                ForEach(Array(list.enumerated()), id: \.offset) { i, c in
                    if i > 0 { RowLine() }
                    HStack(spacing: T.s2) {
                        Circle().fill(Self.color(c, i)).frame(width: 10, height: 10)
                        Text(c.name).font(T.f(17)).foregroundStyle(c.category == nil ? T.muted : T.ink)
                        Spacer(minLength: T.s2)
                        Text(verbatim: Money.kd(c.used)).font(T.f(17, c.used > 0 ? .bold : .regular)).monospacedDigit()
                            .foregroundStyle(c.used > 0 ? T.ink : T.faint)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: - تحتاج تفاصيل

    @ViewBuilder
    private func needs(_ s: FinState) -> some View {
        let list = s.monthTx.filter(\.needsInfo)
        if !list.isEmpty {
            SecLabel(text: "تحتاج منك", trailing: "\(list.count)")
            Card {
                ForEach(Array(list.prefix(5).enumerated()), id: \.element.id) { i, t in
                    if i > 0 { RowLine() }
                    TxRow(tx: t, hint: t.unknown ? "شنو هذي؟" : "أي بند؟") { open = t }
                }
            }
        }
    }

    // MARK: - الحركات

    @ViewBuilder
    private func txList(_ s: FinState) -> some View {
        let all = s.tx ?? []
        if all.isEmpty {
            SecLabel(text: "الحركات")
            EmptyNote(text: "أول ما توصل رسالة من البنك تطلع هني.")
        } else {
            let shown = showAll ? all : Array(all.prefix(12))
            SecLabel(text: "الحركات", trailing: "هالشهر \(s.monthTx.count)")
            Card {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { RowLine() }
                    TxRow(tx: t) { open = t }
                }
                if all.count > 12 {
                    RowLine()
                    Button { withAnimation(.easeOut(duration: 0.15)) { showAll.toggle() } } label: {
                        HStack {
                            Text(showAll ? "أقل" : "كل الحركات").font(T.f(16)).foregroundStyle(T.muted)
                            Spacer()
                            Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(T.dim)
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - أبيه بعدين

    private func wishlist(_ s: FinState) -> some View {
        let list = s.wishlist ?? []
        return Group {
            SecLabel(text: "أبيه بعدين")
            Card {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, w in
                    if i > 0 { RowLine() }
                    HStack(spacing: T.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.title).font(T.f(17)).foregroundStyle(w.done == true ? T.faint : T.ink)
                            if let n = w.note, !n.isEmpty { Text(n).font(T.f(13)).foregroundStyle(T.muted) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let p = w.price {
                            Text(verbatim: Money.kd(p)).font(T.f(16)).monospacedDigit().foregroundStyle(T.muted)
                        }
                        Check(on: w.done == true, label: "اشتريته") {
                            life.finWish(w.done == true ? "undo" : "done", id: w.id)
                        }
                        .padding(.horizontal, -9)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .frame(minHeight: 52)
                    .contextMenu {
                        Button(role: .destructive) { life.finWish("delete", id: w.id) } label: { Label("احذفه", systemImage: "trash") }
                    }
                }
                if !list.isEmpty { RowLine() }
                HStack(spacing: T.s2) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundStyle(T.muted)
                    TextField("", text: $wish, prompt: Text("شي تبيه؟ مثلاً: سماعة 45").foregroundStyle(T.faint))
                        .font(T.f(16)).foregroundStyle(T.ink)
                        .focused($wishFocus)
                        .submitLabel(.done)
                        .onSubmit(addWish)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
            }
        }
    }

    /// «سماعة 45» → سماعة بسعر 45
    private func addWish() {
        var t = wish.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        var price: Double?
        if let last = t.split(separator: " ").last, t.split(separator: " ").count > 1, let p = NumParse.double(String(last)),
           String(last).allSatisfy({ "0123456789٠١٢٣٤٥٦٧٨٩.,٫".contains($0) }) {
            price = p
            t = String(t.dropLast(last.count)).trimmingCharacters(in: .whitespaces)
        }
        life.finWish("add", title: t, price: price)
        wish = ""
    }

    // MARK: - من المالية

    @ViewBuilder
    private func notes(_ s: FinState) -> some View {
        let list = s.notes ?? []
        if !list.isEmpty {
            SecLabel(text: "من محادثة المالية")
            VStack(spacing: T.s3) {
                ForEach(list) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(n.title ?? (n.kind == "weekly" ? "ملخص الأسبوع" : n.kind == "monthly" ? "ملخص الشهر" : "ملاحظة"))
                                .font(T.f(17, .bold)).foregroundStyle(T.ink)
                            Spacer()
                            if let d = RecSession.date(n.at) {
                                Text(verbatim: TxRow.when(d)).font(T.f(13)).foregroundStyle(T.faint)
                            }
                        }
                        PrepText(text: n.body)
                    }
                    .card()
                }
            }
        }
    }
}

// MARK: - الأشرطة

/// شريط، وعليه خط صغير (مثلاً وين وصل الشهر)
private struct PaceBar: View {
    let value: Double
    let mark: Double?
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(T.card2)
                Capsule().fill(color).frame(width: g.size.width * CGFloat(min(max(value, 0), 1)))
                if let mark {
                    RoundedRectangle(cornerRadius: 1).fill(T.ink)
                        .frame(width: 3, height: height + 8)
                        .offset(x: g.size.width * CGFloat(min(max(mark, 0), 1)) - 1.5)
                }
            }
        }
        .frame(height: height)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

// MARK: - صف حركة

struct TxRow: View {
    let tx: FinTx
    var hint: String? = nil
    let action: () -> Void

    static func when(_ d: Date) -> String {
        let k = DateKit.key(d), today = DateKit.todayKey
        let c = DateKit.cal.dateComponents([.hour, .minute, .day, .month], from: d)
        let time = DateKit.timeLabel(String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)) ?? ""
        if k == today { return "اليوم " + time }
        if k == DateKit.add(-1, to: today) { return "أمس " + time }
        return "\(c.day ?? 1) \(DateKit.months[max(0, (c.month ?? 1) - 1)])"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: T.s3) {
                if tx.fromBuild == true {
                    RoundedRectangle(cornerRadius: 2).fill(FinanceTab.buildColor).frame(width: 4, height: 34)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: tx.title)
                        .font(T.f(17)).foregroundStyle(tx.neutral ? T.muted : T.ink)
                        .lineLimit(1)
                    Text(verbatim: sub).font(T.f(13)).foregroundStyle(hint != nil ? T.accent : T.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: amountText)
                        .font(T.f(17, .bold)).monospacedDigit()
                        .foregroundStyle(tx.neutral ? T.faint : (tx.isIn ? FinanceTab.goalColor : T.ink))
                    if tx.approx == true, let o = tx.amountOriginal {
                        Text(verbatim: "≈ " + Money.orig(o, tx.currencyOriginal)).font(T.f(12)).monospacedDigit().foregroundStyle(T.faint)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var amountText: String {
        guard let a = tx.amount else { return "—" }
        let s = Money.kd(a)
        if tx.neutral { return s }
        return (tx.isIn ? "+" : "−") + s
    }

    private var sub: String {
        if let hint { return [tx.date.map(Self.when), hint].compactMap { $0 }.joined(separator: " · ") }
        var parts: [String] = []
        if let d = tx.date { parts.append(Self.when(d)) }
        if let det = tx.details, !det.isEmpty { parts.append(det) }
        else if tx.neutral { parts.append(tx.kindName) }
        else if let c = tx.category { parts.append(c) }
        else if tx.kind == "income" { parts.append(tx.inBudget == true ? "دخل الميزانية" : "دخل برا الميزانية") }
        if tx.fromBuild == true { parts.append("حساب البناء") }
        else if tx.account == "visa" { parts.append("الفيزا") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - ورقة الحركة

struct FinTxSheet: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    let tx: FinTx
    let cats: [FinCat]
    @State private var category: String?
    @State private var details = ""
    @State private var note = ""
    @State private var kind: String?
    @State private var rule = true

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        if tx.fromBuild == true {
                            Circle().fill(FinanceTab.buildColor).frame(width: 8, height: 8)
                        }
                        Text(verbatim: [tx.kindName, tx.accountName, tx.card.map { "•" + $0 }].compactMap { $0 }.joined(separator: " · "))
                            .font(T.f(14)).foregroundStyle(tx.fromBuild == true ? FinanceTab.buildColor : T.muted)
                    }
                    Text(verbatim: tx.title).font(T.f(26, .bold)).foregroundStyle(T.ink).padding(.top, 2)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: (tx.approx == true ? "≈ " : "") + (tx.amount.map { Money.kd($0) } ?? "—"))
                            .font(T.f(34, .bold)).monospacedDigit().foregroundStyle(T.ink)
                        Text("د.ك").font(T.f(16)).foregroundStyle(T.muted)
                    }
                    .padding(.top, T.s2)
                    VStack(alignment: .leading, spacing: 2) {
                        if let d = tx.date { Text(verbatim: TxRow.when(d)) }
                        if tx.approx == true, let o = tx.amountOriginal {
                            Text(verbatim: "تقريبي، من \(Money.orig(o, tx.currencyOriginal)). المبلغ الصح يطلع بالكشف")
                        }
                        if let b = tx.balance { Text(verbatim: "رصيدك بعدها \(Money.kd(b))") }
                    }
                    .font(T.f(14)).foregroundStyle(T.muted)
                    .padding(.top, T.s1)

                    SecLabel(text: "شنو كان؟")
                    field($details, "مثلاً: مطعم كذا، وشنو طلبت")

                    if !cats.isEmpty && (kind ?? tx.kind) != "transfer" && (kind ?? tx.kind) != "visa_payment" {
                        SecLabel(text: "البند")
                        FlowChips(items: cats.compactMap(\.category), sel: $category)
                        if let m = tx.merchant, category != tx.category, category != nil {
                            Toggle(isOn: $rule) {
                                Text(verbatim: "كل حركات \(m) بنفس البند").font(T.f(15)).foregroundStyle(T.ink)
                            }
                            .tint(T.accent)
                            .padding(.top, T.s3)
                            .padding(.horizontal, 2)
                        }
                    }

                    SecLabel(text: "النوع")
                    Menu {
                        ForEach(FinTx.kinds, id: \.0) { k in
                            Button { kind = k.0 } label: {
                                if (kind ?? tx.kind) == k.0 { Label(k.1, systemImage: "checkmark") } else { Text(k.1) }
                            }
                        }
                    } label: {
                        HStack {
                            Text(verbatim: FinTx.kinds.first { $0.0 == (kind ?? tx.kind) }?.1 ?? "ما انفهمت")
                                .font(T.f(17)).foregroundStyle(T.ink)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.muted)
                        }
                        .padding(.horizontal, 18)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
                    }

                    SecLabel(text: "ملاحظة")
                    field($note, "أي شي تبي المالية تعرفه")

                    if let raw = tx.raw, !raw.isEmpty {
                        SecLabel(text: "رسالة البنك")
                        Text(verbatim: raw).font(T.f(14)).foregroundStyle(T.muted)
                            .textSelection(.enabled)
                            .card()
                    }

                    PillButton(text: "احفظ", wide: true) {
                        let changedCat = category != tx.category
                        life.finEdit(tx, category: category, details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                                     note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                     kind: kind != tx.kind ? kind : nil, rule: changedCat && rule)
                        dismiss()
                    }
                    .padding(.top, T.s5)
                }
                .padding(.horizontal, 20)
                .padding(.top, T.s5)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            category = tx.category
            details = tx.details ?? ""
            note = tx.note ?? ""
            kind = tx.kind
        }
    }

    private func field(_ b: Binding<String>, _ placeholder: String) -> some View {
        TextField("", text: b, prompt: Text(placeholder).foregroundStyle(T.faint), axis: .vertical)
            .font(T.f(16)).foregroundStyle(T.ink)
            .lineLimit(1...5)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
    }
}

/// حبات تختار منها وحدة (البند). الضغط على المختار يشيله
private struct FlowChips: View {
    let items: [String]
    @Binding var sel: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { it in
                    let on = sel == it
                    Button { sel = on ? nil : it } label: {
                        Text(it)
                            .font(T.f(15, on ? .bold : .regular))
                            .foregroundStyle(on ? T.accentInk : T.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(on ? T.accent : T.card2))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
