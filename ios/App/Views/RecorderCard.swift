import SwiftUI

/// كرت «التسجيل»: حالة البوت اللي بالدرس، وأزرار ابدأ ووقّف مؤقت وكمّل وخلّص.
struct RecorderCard: View {
    @EnvironmentObject var life: LifeStore
    /// إذا انعطى: يطلع بس لجلسات هالمادة
    var course: String? = nil

    private static let red = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        Group {
            if let r = life.rec, r.id != nil, r.recent, course == nil || r.course == course {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Card { content(r, ctx.date) }
                }
                .padding(.top, T.s3)
            }
        }
        .task(id: life.rec?.active ?? false) {
            // وهو شغال: نحدث كل ٣ ثواني
            await life.recRefresh()
            while !Task.isCancelled, life.rec?.active == true {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await life.recRefresh()
            }
        }
    }

    private func title(_ r: RecSession) -> String {
        let c = r.course.flatMap { life.course($0) }
        let name = c?.shortName ?? r.course ?? ""
        return r.num.map { "\(name) · \($0)" } ?? name
    }

    @ViewBuilder
    private func content(_ r: RecSession, _ now: Date) -> some View {
        let st = r.state ?? ""
        let cmd = r.cmd ?? ""
        let secs = RestTimes.label(r.seconds(at: now))
        HStack(alignment: .center, spacing: T.s3) {
            if st == "recording" {
                Circle().fill(Self.red).frame(width: 10, height: 10)
                    .opacity(Int(now.timeIntervalSince1970) % 2 == 0 ? 1 : 0.35)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: headline(r, secs)).font(T.f(17, st == "recording" ? .bold : .regular))
                    .foregroundStyle(T.ink).monospacedDigit()
                Text(verbatim: detail(r)).font(T.f(13)).foregroundStyle(T.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            buttons(st, cmd)
        }
        .padding(.leading, 18).padding(.trailing, 12)
        .padding(.vertical, 12)
    }

    private func headline(_ r: RecSession, _ secs: String) -> String {
        let st = r.state ?? "", cmd = r.cmd ?? ""
        if r.active && !r.recorderAlive { return "اللابتوب مو شغال" }
        switch st {
        case "requested", "joining": return "التسجيل يدخل الدرس…"
        case "waiting": return "التسجيل ينطر يدخلونه"
        case "in_call": return cmd == "record" ? "يبدأ التسجيل…" : "التسجيل داخل · ما يسجل"
        case "recording": return cmd == "pause" ? "يوقف…" : (cmd == "stop" ? "يخلص…" : "يسجل " + secs)
        case "paused": return cmd == "record" ? "يكمل…" : (cmd == "stop" ? "يخلص…" : "موقف · " + secs)
        case "saving": return "يحفظ الملف…"
        case "done": return "انحفظ · " + secs
        case "failed": return "ما انسجل"
        case "cancelled": return "طلع بدون تسجيل"
        default: return "التسجيل"
        }
    }

    private func detail(_ r: RecSession) -> String {
        let st = r.state ?? ""
        if r.active && !r.recorderAlive { return "شغّل اللابتوب، والبرنامج يدخل بروحه" }
        switch st {
        case "waiting":
            let meet = (r.course.flatMap { life.course($0) }?.link ?? "").contains("meet.google")
            return title(r) + (meet ? " · اقبله من الاجتماع" : " · الأستاذ يدخّله")
        case "done": return r.file ?? title(r)
        case "failed": return r.error ?? title(r)
        default: return title(r)
        }
    }

    @ViewBuilder
    private func buttons(_ st: String, _ cmd: String) -> some View {
        switch st {
        case "requested", "joining", "waiting":
            SmallButton(text: "طلّعه") { life.recSend("cancel") }
        case "in_call":
            if cmd != "record" {
                HStack(spacing: 6) {
                    SmallButton(text: "طلّعه") { life.recSend("cancel") }
                    PillButton(text: "ابدأ") { life.recSend("record") }
                }
            }
        case "recording":
            HStack(spacing: 6) {
                SmallButton(text: "وقّف مؤقت") { life.recSend("pause") }
                PillButton(text: "خلّص") { life.recSend("stop") }
            }
        case "paused":
            HStack(spacing: 6) {
                SmallButton(text: "كمّل") { life.recSend("record") }
                PillButton(text: "خلّص") { life.recSend("stop") }
            }
        default:
            EmptyView()
        }
    }
}
