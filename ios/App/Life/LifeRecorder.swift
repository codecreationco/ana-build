import Foundation
import UIKit

/// جلسة تسجيل الدرس: التطبيق يرسل الأمر، وبرنامج «التسجيل» على اللابتوب يكتب الحالة.
struct RecSession: Decodable, Equatable {
    var id: Int?
    var course: String?
    var num: Int?
    var cmd: String?
    var state: String?
    var stateAt: String?
    var recSec: Int?
    var file: String?
    var error: String?
    var recorderSeen: String?

    static let finals: Set<String> = ["done", "failed", "cancelled"]
    var active: Bool { id != nil && !Self.finals.contains(state ?? "") }

    static func date(_ s: String?) -> Date? {
        guard var s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        // أجزاء الثانية أطول من المتوقع
        if let dot = s.firstIndex(of: "."), let end = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            s.removeSubrange(dot..<end)
        }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// اللابتوب شاف القاعدة آخر ٣٠ ثانية
    var recorderAlive: Bool { (Self.date(recorderSeen).map { Date().timeIntervalSince($0) < 30 }) ?? false }

    /// الثواني المسجلة لين الحين
    func seconds(at now: Date) -> Int {
        let base = recSec ?? 0
        guard state == "recording", let at = Self.date(stateAt) else { return base }
        return base + max(0, Int(now.timeIntervalSince(at)))
    }

    /// تنعرض بعد ما تخلص بنص ساعة بس
    var recent: Bool {
        if active { return true }
        guard let at = Self.date(stateAt) else { return false }
        return Date().timeIntervalSince(at) < 30 * 60
    }
}

extension LifeSync {
    static func recDecode(_ o: Any) -> RecSession? {
        guard let data = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(RecSession.self, from: data)
    }
}

extension LifeStore {
    /// رقم درس اليوم للمادة
    func todayNumber(_ c: Course) -> Int? {
        c.mode == .teach ? teachNumber(c, on: today) : lessonNumber(c, on: today)
    }

    /// يفتح رابط الدرس ويرسل «التسجيل» يدخل وياك
    func enterLesson(_ c: Course) {
        if let s = c.link, let url = URL(string: s) { UIApplication.shared.open(url) }
        recJoin(c)
    }

    func recJoin(_ c: Course) {
        guard !Snap.on, let link = c.link else { return }
        let num: Any = todayNumber(c).map { $0 as Any } ?? NSNull()
        Task {
            await recRefresh()
            // داخل أصلاً لنفس المادة: لا نعيده
            if let r = rec, r.active, r.course == c.id { return }
            await recCall(["p_course": c.id, "p_num": num, "p_url": link, "p_cmd": "join"])
        }
    }

    func recSend(_ cmd: String) {
        guard !Snap.on else { return }
        rec?.cmd = cmd
        Task { await recCall(["p_course": rec?.course ?? "", "p_num": NSNull(), "p_url": "", "p_cmd": cmd]) }
    }

    private func recCall(_ body: [String: Any]) async {
        var b = body
        b["p_key"] = DeviceKey.get()
        do {
            let o = try await LifeSync.rpc("rec_send", b)
            if let r = LifeSync.recDecode(o), r.id != nil { rec = r } else { await recRefresh() }
        } catch {
            toast = UndoToast(text: "ما وصل الأمر للتسجيل")
        }
    }

    func recRefresh() async {
        guard !Snap.on else { return }
        if let o = try? await LifeSync.rpc("rec_get", ["p_key": DeviceKey.get()]) {
            let r = LifeSync.recDecode(o)
            if r != rec { rec = r }
        }
    }
}
