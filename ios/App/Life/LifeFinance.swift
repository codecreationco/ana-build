import Foundation
import AppIntents
import SwiftUI

// MARK: - البيانات (من fin_get)

struct FinCat: Decodable, Equatable, Hashable {
    var category: String?
    var limit: Double?
    var color: String?
    var pace: Bool?
    var note: String?
    var spent: Double?

    var name: String { category ?? "بدون بند" }
    var lim: Double { limit ?? 0 }
    var used: Double { spent ?? 0 }
}

struct FinTx: Decodable, Equatable, Identifiable, Hashable {
    var id: Int
    var at: String?
    var account: String?
    var card: String?
    var dir: String?
    var kind: String?
    var amount: Double?
    var approx: Bool?
    var currencyOriginal: String?
    var amountOriginal: Double?
    var merchant: String?
    var label: String?
    var category: String?
    var inBudget: Bool?
    var details: String?
    var note: String?
    var balance: Double?
    var raw: String?
    var fromBuild: Bool?
    var pairId: Int?
    var refundOf: Int?

    var date: Date? { RecSession.date(at) }
    var isIn: Bool { dir == "in" }
    /// تحويل بين حساباته أو سداد الفيزا: ما ينحسب
    var neutral: Bool { kind == "transfer" || kind == "visa_payment" }
    var unknown: Bool { kind == "unknown" }
    var needsInfo: Bool { unknown || ((kind == "expense" || kind == "refund") && category == nil) }

    var title: String {
        if let l = label, !l.isEmpty, merchant == nil || merchant == "ومض" || neutral || kind == "income" { return l }
        return merchant ?? label ?? (isIn ? "إيداع" : "خصم")
    }

    static let kinds: [(String, String)] = [
        ("expense", "مصروف"), ("income", "دخل"), ("refund", "استرجاع"),
        ("transfer", "تحويل داخلي"), ("visa_payment", "سداد الفيزا"), ("ignored", "تجاهلها"),
    ]
    var kindName: String {
        if kind == "unknown" { return "ما انفهمت" }
        return Self.kinds.first { $0.0 == kind }?.1 ?? ""
    }

    var accountName: String {
        switch account {
        case "build": return "حساب البناء"
        case "visa": return "الفيزا"
        case "loan": return "حساب القرض"
        default: return "الحساب الأساسي"
        }
    }
}

struct FinCommit: Decodable, Equatable, Identifiable {
    var id: Int
    var name: String
    var amount: Double?
    var dayFrom: Int?
    var dayTo: Int?
    var freq: String?
    var dueMonth: Int?
    var note: String?
    var paid: Bool?
    var paidAt: String?
    var paidAmount: Double?

    var when: String {
        if freq == "yearly" {
            let m = dueMonth.map { DateKit.months[max(0, min(11, $0 - 1))] }
            return ["سنوي", m].compactMap { $0 }.joined(separator: " · ")
        }
        switch (dayFrom, dayTo) {
        case let (a?, b?) where a != b: return "يوم \(a)–\(b)"
        case let (a?, _): return "يوم \(a)"
        default: return "شهري"
        }
    }
}

struct FinGoal: Decodable, Equatable, Identifiable {
    var id: Int
    var name: String
    var target: Double?
    var value: Double?
    var note: String?
}

struct FinWish: Decodable, Equatable, Identifiable {
    var id: Int
    var title: String
    var price: Double?
    var note: String?
    var done: Bool?
}

struct FinNote: Decodable, Equatable, Identifiable {
    var id: Int
    var kind: String?
    var title: String?
    var body: String
    var at: String?
    var pinned: Bool?
}

struct FinState: Decodable, Equatable {
    var monthStart: String?
    var monthEnd: String?
    var income: Double?
    var budget: [FinCat]?
    var tx: [FinTx]?
    var commitments: [FinCommit]?
    var goals: [FinGoal]?
    var wishlist: [FinWish]?
    var notes: [FinNote]?

    var start: Date? { RecSession.date(monthStart) }
    var end: Date? { RecSession.date(monthEnd) }
    var cats: [FinCat] { (budget ?? []).filter { $0.category != nil } }
    var other: FinCat? { (budget ?? []).first { $0.category == nil } }
    var spent: Double { (budget ?? []).reduce(0) { $0 + $1.used } }
    var limit: Double { cats.reduce(0) { $0 + $1.lim } }
    var monthTx: [FinTx] {
        guard let s = start else { return tx ?? [] }
        return (tx ?? []).filter { ($0.date ?? .distantPast) >= s }
    }

    /// كم يوم مر من الشهر المالي (من 1) ومن كم
    func days(_ now: Date = Date()) -> (Int, Int) {
        guard let s = start else { return (1, 30) }
        let e = end ?? DateKit.cal.date(byAdding: .month, value: 1, to: s) ?? s
        let total = max(1, DateKit.cal.dateComponents([.day], from: s, to: e).day ?? 30)
        let n = max(1, min(total, (DateKit.cal.dateComponents([.day], from: s, to: now).day ?? 0) + 1))
        return (n, total)
    }

    static func decode(_ o: Any) -> FinState? {
        guard let data = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        return decode(data)
    }

    static func decode(_ data: Data) -> FinState? {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(FinState.self, from: data)
    }
}

enum Money {
    /// 17.750 → «17.750»، و12 → «12»
    static func kd(_ v: Double, decimals: Bool = true) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        let whole = abs(v - v.rounded()) < 0.0005
        f.minimumFractionDigits = (decimals && !whole) ? 3 : 0
        f.maximumFractionDigits = decimals ? 3 : 0
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.3f", v)
    }

    static func pct(_ part: Double, _ whole: Double) -> Int {
        whole > 0 ? Int((part / whole * 100).rounded()) : 0
    }
}

// MARK: - رسائل البنك من الاختصارات (تنحفظ بالتلفون لين توصل)

enum FinQueue {
    private static let key = "fin.queue"
    private static let lock = NSLock()
    static let changed = Notification.Name("fin.changed")

    struct Item: Codable { var text: String; var at: Date }

    private static func load() -> [Item] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: d)) ?? []
    }

    private static func store(_ list: [Item]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: key)
    }

    static var count: Int { lock.lock(); defer { lock.unlock() }; return load().count }

    static func add(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        var l = load()
        l.append(Item(text: text, at: Date()))
        store(l)
    }

    /// يرسل اللي ينتظر. اللي وصل (أو انرفض كمكرر/متجاهل) ينشال، واللي ما وصل يبقى للمرة الجاية
    @discardableResult
    static func flush() async -> Int {
        let pending: [Item] = { lock.lock(); defer { lock.unlock() }; return load() }()
        guard !pending.isEmpty, let key = DeviceKey.existing() else { return 0 }
        let iso = ISO8601DateFormatter()
        var sent: [Item] = []
        for it in pending {
            do {
                _ = try await LifeSync.rpc("fin_sms", ["p_key": key, "p_text": it.text, "p_at": iso.string(from: it.at)])
                sent.append(it)
            } catch SyncError.http(let code, _) where code >= 400 && code < 500 && code != 408 && code != 429 {
                sent.append(it)   // الرسالة نفسها فيها مشكلة: لا نعيدها للأبد
            } catch {
                break             // ماكو نت: نكمل بعدين
            }
        }
        lock.lock()
        var l = load()
        l.removeAll { a in sent.contains { $0.text == a.text && $0.at == a.at } }
        store(l)
        lock.unlock()
        if !sent.isEmpty {
            await MainActor.run { NotificationCenter.default.post(name: changed, object: nil) }
        }
        return sent.count
    }
}

/// الأمر اللي تشغله أتمتة الاختصارات لما توصل رسالة من البنك
struct LogBankSMS: AppIntent {
    static var title: LocalizedStringResource = "سجّل حركة"
    static var description = IntentDescription("يسجل رسالة البنك بتاب المصاريف بتطبيق حسن")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "نص الرسالة")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("سجّل \(\.$text)")
    }

    func perform() async throws -> some IntentResult {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            FinQueue.add(t)
            await FinQueue.flush()
        }
        return .result()
    }
}

// MARK: - الكلام مع قاعدة البيانات

extension LifeStore {
    private static let finCacheKey = "fin.cache"

    func finLoadCache() {
        if Snap.on { if fin == nil { fin = FinSample.state }; return }
        guard fin == nil, let d = UserDefaults.standard.data(forKey: Self.finCacheKey) else { return }
        fin = FinState.decode(d)
    }

    private func finSet(_ o: Any) {
        guard let s = FinState.decode(o) else { return }
        if s != fin { fin = s }
        if let d = try? JSONSerialization.data(withJSONObject: o) {
            UserDefaults.standard.set(d, forKey: Self.finCacheKey)
        }
    }

    func finRefresh() async {
        guard !Snap.on else { return }
        await FinQueue.flush()
        do {
            let o = try await LifeSync.rpc("fin_get", ["p_key": DeviceKey.get()])
            finSet(o)
            finError = false
        } catch {
            finError = true
        }
    }

    func finEdit(_ t: FinTx, category: String?, details: String, note: String, kind: String?, rule: Bool) {
        guard !Snap.on else { return }
        // يبين على طول
        if var s = fin, let i = s.tx?.firstIndex(where: { $0.id == t.id }) {
            s.tx?[i].category = category
            s.tx?[i].details = details.isEmpty ? nil : details
            s.tx?[i].note = note.isEmpty ? nil : note
            if let kind { s.tx?[i].kind = kind }
            fin = s
        }
        Task {
            do {
                let o = try await LifeSync.rpc("fin_tx_edit", [
                    "p_key": DeviceKey.get(), "p_id": t.id, "p_category": category ?? "",
                    "p_details": details, "p_note": note, "p_kind": kind ?? "", "p_rule": rule,
                ])
                finSet(o)
            } catch {
                toast = UndoToast(text: "ما انحفظ التعديل، جرب مرة ثانية")
                await finRefresh()
            }
        }
    }

    func finWish(_ op: String, id: Int? = nil, title: String? = nil, price: Double? = nil) {
        guard !Snap.on else { return }
        if var s = fin, let id {
            switch op {
            case "done": if let i = s.wishlist?.firstIndex(where: { $0.id == id }) { s.wishlist?[i].done = true }
            case "undo": if let i = s.wishlist?.firstIndex(where: { $0.id == id }) { s.wishlist?[i].done = false }
            case "delete": s.wishlist?.removeAll { $0.id == id }
            default: break
            }
            fin = s
        }
        Task {
            var b: [String: Any] = ["p_key": DeviceKey.get(), "p_op": op]
            b["p_id"] = id.map { $0 as Any } ?? NSNull()
            b["p_title"] = title ?? NSNull()
            b["p_price"] = price.map { $0 as Any } ?? NSNull()
            do {
                finSet(try await LifeSync.rpc("fin_wish", b))
            } catch {
                toast = UndoToast(text: "ما انحفظ، جرب مرة ثانية")
            }
        }
    }
}

// MARK: - للتصوير بس (أرقام وهمية)

enum FinSample {
    static var state: FinState {
        let now = Date()
        let iso = ISO8601DateFormatter()
        func ago(_ h: Double) -> String { iso.string(from: now.addingTimeInterval(-h * 3600)) }
        let start = DateKit.cal.date(byAdding: .day, value: -12, to: now) ?? now
        return FinState(
            monthStart: iso.string(from: start),
            monthEnd: iso.string(from: DateKit.cal.date(byAdding: .month, value: 1, to: start) ?? now),
            income: 1018.834,
            budget: [
                FinCat(category: "الأكل", limit: 120, color: "#E39B3F", pace: true, note: nil, spent: 61.35),
                FinCat(category: "البنزين", limit: 40, color: "#5FA8D3", pace: false, note: nil, spent: 15),
                FinCat(category: "الاشتراكات", limit: 35, color: "#9C8CF0", pace: false, note: nil, spent: 21.4),
                FinCat(category: "البيت", limit: 60, color: "#62B58F", pace: false, note: nil, spent: 12.5),
                FinCat(category: "شخصي", limit: 50, color: "#D7727E", pace: false, note: nil, spent: 8),
                FinCat(category: nil, limit: 0, color: nil, pace: false, note: nil, spent: 7),
            ],
            tx: [
                FinTx(id: 9, at: ago(2), account: "main", dir: "out", kind: "expense", amount: 17.75, merchant: "TALABAT GENERAL", category: "الأكل", inBudget: true, details: "مطعم مشاوي"),
                FinTx(id: 8, at: ago(5), account: "main", dir: "out", kind: "expense", amount: 2.6, merchant: "ESPRESSO LAP", category: "الأكل", inBudget: true),
                FinTx(id: 7, at: ago(20), account: "visa", dir: "out", kind: "expense", amount: 3.385, approx: true, currencyOriginal: "USD", amountOriginal: 10.99, merchant: "GOOGLE *YOUTUBEPREMIUM", category: "الاشتراكات", inBudget: true),
                FinTx(id: 6, at: ago(26), account: "main", dir: "out", kind: "expense", amount: 7, merchant: "ومض", label: "ومض", inBudget: true),
                FinTx(id: 5, at: ago(30), account: "main", dir: "in", kind: "transfer", amount: 149.355, label: "تحويل من حساب البناء", fromBuild: true),
                FinTx(id: 4, at: ago(30.1), account: "build", dir: "out", kind: "transfer", amount: 149.355, label: "تحويل إلى الحساب الأساسي", fromBuild: true),
                FinTx(id: 3, at: ago(50), account: "main", dir: "out", kind: "visa_payment", amount: 20, label: "سداد الفيزا"),
                FinTx(id: 2, at: ago(70), account: "main", dir: "in", kind: "income", amount: 800, label: "Code Creation"),
                FinTx(id: 1, at: ago(280), account: "main", dir: "in", kind: "income", amount: 868.834, label: "العلاوة", inBudget: true),
            ],
            commitments: [
                FinCommit(id: 1, name: "القرض", amount: 357.33, dayFrom: 1, dayTo: 3, freq: "monthly", paid: false),
                FinCommit(id: 2, name: "التأمينات", amount: 170, dayFrom: 25, dayTo: 26, freq: "monthly", paid: true),
                FinCommit(id: 3, name: "Zain", amount: 14, dayFrom: 5, dayTo: 5, freq: "monthly", paid: nil),
                FinCommit(id: 4, name: "دروب بوكس", amount: 36, freq: "yearly", dueMonth: 3, paid: nil),
            ],
            goals: [
                FinGoal(id: 1, name: "احتياط الطوارئ", target: 500, value: 120),
                FinGoal(id: 2, name: "رجوع فلوس البيت", target: 600, value: 150),
            ],
            wishlist: [FinWish(id: 1, title: "سماعة جديدة", price: 45, note: nil, done: false)],
            notes: [FinNote(id: 1, kind: "weekly", title: "ملخص الأسبوع", body: "الأكل ماشي أسرع من المفروض بشوي. باقي ٥٨ للأكل لين آخر الشهر.", at: ago(30), pinned: false)]
        )
    }
}
