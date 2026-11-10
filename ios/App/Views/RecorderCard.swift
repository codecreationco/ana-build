import SwiftUI

/// كرت «التسجيل»: حالة البوت اللي بالدرس، وأزرار ابدأ ووقّف مؤقت وكمّل وخلّص.
struct RecorderCard: View {
    @EnvironmentObject var life: LifeStore
    /// إذا انعطى: يطلع بس لجلسات هالمادة
    var course: String? = nil

    static let red = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        Group {
            if let r = life.rec, r.id != nil, r.recent, course == nil || r.course == course {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Card { content(r, ctx.date) }
                }
                .padding(.top, T.s3)
            }
        }
    }

    private func title(_ r: RecSession) -> String {
        if r.course == "adhoc" { return r.title ?? "تسجيل من رابط" }
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

    /// الميت: حسن يدخّل «التسجيل» بنفسه، والبرنامج يسجل الخط الافتراضي
    private func isMeet(_ r: RecSession) -> Bool {
        (r.url ?? r.course.flatMap { life.course($0) }?.link ?? "").contains("meet.google")
    }

    private func detail(_ r: RecSession) -> String {
        let st = r.state ?? ""
        if r.active && !r.recorderAlive { return "شغّل اللابتوب، والبرنامج يدخل بروحه" }
        switch st {
        case "waiting":
            let meet = isMeet(r)
            return title(r) + (meet ? " · إذا الاجتماع يحتاج قبول، اقبله" : " · الأستاذ يدخّله")
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
            } else {
                SmallButton(text: "طلّعه") { life.recSend("cancel") }
            }
        case "recording":
            HStack(spacing: 6) {
                SmallButton(text: "وقّف") { life.recSend("pause") }
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

/// دائرة التسجيل جنب زر «+»: حمرا وتكبر وتصغر وهو يسجل
struct RecDot: View {
    @EnvironmentObject var life: LifeStore
    @State private var open = false

    var body: some View {
        if let r = life.rec, r.active {
            let st = r.state ?? ""
            Button { open = true } label: {
                RecMark(state: st, size: 40)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(st == "recording" ? "يسجل، اضغط للتحكم" : (st == "paused" ? "التسجيل موقف، اضغط للتحكم" : "التسجيل، اضغط للتحكم"))
            .sheet(isPresented: $open) {
                RecorderSheet()
                    .environmentObject(life)
                    .environment(\.layoutDirection, .rightToLeft)
                    .preferredColorScheme(.dark)
                    .presentationDetents([.height(380)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// علامة التسجيل: حلقة حمرا وداخلها دائرة. وهو يسجل الدائرة تكبر وتصغر، وموقف تصير مربعين ⏸
struct RecMark: View {
    let state: String
    var size: CGFloat = 40

    var body: some View {
        let rec = state == "recording"
        ZStack {
            Circle().fill(T.card2)
            Circle().stroke(RecorderCard.red.opacity(rec ? 0.9 : 0.6), lineWidth: 2).padding(4)
            if state == "paused" {
                HStack(spacing: size * 0.08) {
                    RoundedRectangle(cornerRadius: 1.5).fill(RecorderCard.red).frame(width: size * 0.1, height: size * 0.32)
                    RoundedRectangle(cornerRadius: 1.5).fill(RecorderCard.red).frame(width: size * 0.1, height: size * 0.32)
                }
            } else {
                Circle()
                    .fill(RecorderCard.red.opacity(rec || state == "saving" ? 1 : 0.45))
                    .frame(width: size * 0.42, height: size * 0.42)
                    .phaseAnimator([CGFloat(0.72), CGFloat(1.0)]) { dot, phase in
                        dot.scaleEffect(rec ? phase : 0.8)
                    } animation: { _ in .easeInOut(duration: 0.8) }
            }
        }
        .frame(width: size, height: size)
    }
}

/// معلومات التسجيل وأزراره (من دائرة التسجيل)
struct RecorderSheet: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            T.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("التسجيل").font(T.f(24, .bold)).foregroundStyle(T.ink)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(T.muted)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(T.card2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("سكّر")
                }
                if let r = life.rec, r.id != nil, r.recent {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        info(r, ctx.date)
                    }
                } else {
                    Text("ماكو تسجيل الحين").font(T.f(15)).foregroundStyle(T.muted).padding(.top, T.s4)
                }
            }
            .padding(16)
        }
    }

    private func name(_ r: RecSession) -> String {
        if r.course == "adhoc" { return r.title ?? "تسجيل من رابط" }
        let c = r.course.flatMap { life.course($0) }
        let n = c?.shortName ?? r.course ?? ""
        return r.num.map { "\(n) · درس \($0)" } ?? n
    }

    private func status(_ r: RecSession) -> String {
        let st = r.state ?? "", cmd = r.cmd ?? ""
        if r.active && !r.recorderAlive { return "اللابتوب مو شغال" }
        if cmd == "stop" && r.active { return "يخلص ويحفظ…" }
        switch st {
        case "requested", "joining": return "يدخل الاجتماع…"
        case "waiting": return "ينطر يقبلونه بالاجتماع"
        case "in_call": return cmd == "record" ? "يبدأ يسجل…" : "داخل الاجتماع · ما يسجل"
        case "recording": return cmd == "pause" ? "يوقف…" : "يسجل"
        case "paused": return cmd == "record" ? "يكمل…" : "موقف"
        case "saving": return "يحفظ الملف…"
        case "done": return "انحفظ"
        case "failed": return "ما انسجل"
        case "cancelled": return "طلع بدون تسجيل"
        default: return ""
        }
    }

    @ViewBuilder
    private func info(_ r: RecSession, _ now: Date) -> some View {
        let st = r.state ?? "", cmd = r.cmd ?? ""
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: name(r)).font(T.f(15)).foregroundStyle(T.muted).padding(.top, T.s2)
            HStack(alignment: .center, spacing: T.s3) {
                RecMark(state: st, size: 52)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: RestTimes.label(r.seconds(at: now)))
                        .font(T.f(40, .bold)).monospacedDigit().foregroundStyle(T.ink)
                    Text(verbatim: status(r)).font(T.f(16)).foregroundStyle(st == "recording" ? RecorderCard.red : T.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, T.s4)
            if st == "done", let f = r.file {
                Text(verbatim: "الدروب بوكس: " + f).font(T.f(13)).foregroundStyle(T.muted).padding(.top, T.s2)
            }
            if st == "failed", let e = r.error {
                Text(verbatim: e).font(T.f(13)).foregroundStyle(T.muted).padding(.top, T.s2)
            }
            HStack(spacing: 10) {
                switch st {
                case "requested", "joining", "waiting":
                    big("طلّعه", main: false) { life.recSend("cancel") }
                case "in_call":
                    if cmd == "record" { big("طلّعه", main: false) { life.recSend("cancel") } }
                    else {
                        big("ابدأ", main: true) { life.recSend("record") }
                        big("طلّعه", main: false) { life.recSend("cancel") }
                    }
                case "recording":
                    big("وقّف", main: false) { life.recSend("pause") }
                    big("خلّص واحفظ", main: true) { life.recSend("stop") }
                case "paused":
                    big("كمّل", main: false) { life.recSend("record") }
                    big("خلّص واحفظ", main: true) { life.recSend("stop") }
                default:
                    big("سكّر", main: false) { dismiss() }
                }
            }
            .disabled(cmd == "stop" && r.active)
            .padding(.top, T.s5)
        }
    }

    private func big(_ text: String, main: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(T.f(16, .semibold))
                .foregroundStyle(main ? T.pillInk : T.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(main ? T.pill : T.card2))
        }
        .buttonStyle(.plain)
    }
}
