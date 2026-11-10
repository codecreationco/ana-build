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
        case "in_call": return cmd == "record" ? "يبدأ التسجيل…" : (isMeet(r) ? "جاهز يسجل" : "التسجيل داخل · ما يسجل")
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
            return title(r) + (meet ? " · اقبله من الاجتماع" : " · الأستاذ يدخّله")
        case "in_call" where isMeet(r): return "دخّل «التسجيل» من كروم اللابتوب، وبعدين ابدأ"
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

/// الدائرة الحمرا جنب زر «+»: تطلع وقت ما يكون فيه تسجيل، وفيها المدة
struct RecDot: View {
    @EnvironmentObject var life: LifeStore
    @State private var open = false

    var body: some View {
        if let r = life.rec, r.active {
            Button { open = true } label: {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let st = r.state ?? ""
                    let rec = st == "recording"
                    let shown = rec || st == "paused" || st == "saving"
                    HStack(spacing: 6) {
                        if st == "paused" {
                            Image(systemName: "pause.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(RecorderCard.red)
                        } else {
                            Circle()
                                .fill(shown ? RecorderCard.red : Color.clear)
                                .overlay(Circle().stroke(RecorderCard.red, lineWidth: shown ? 0 : 2))
                                .frame(width: 10, height: 10)
                                .opacity(rec && Int(ctx.date.timeIntervalSince1970) % 2 == 1 ? 0.35 : 1)
                        }
                        if shown {
                            Text(verbatim: RestTimes.label(r.seconds(at: ctx.date)))
                                .font(T.f(14, .bold)).monospacedDigit().foregroundStyle(T.ink)
                                .lineLimit(1)
                        }
                    }
                    .fixedSize()
                    .padding(.horizontal, shown ? 12 : 15)
                    .frame(height: 40)
                    .background(Capsule().fill(T.card2))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label(r))
            .sheet(isPresented: $open) {
                RecorderSheet()
                    .environmentObject(life)
                    .environment(\.layoutDirection, .rightToLeft)
                    .preferredColorScheme(.dark)
                    .presentationDetents([.height(260), .medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func label(_ r: RecSession) -> String {
        switch r.state ?? "" {
        case "recording": return "يسجل، اضغط للتحكم"
        case "paused": return "التسجيل موقف، اضغط للتحكم"
        default: return "التسجيل، اضغط للتحكم"
        }
    }
}

/// معلومات التسجيل وأزراره (من الدائرة الحمرا)
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
                RecorderCard()
                if life.rec == nil || life.rec?.recent == false {
                    Text("ماكو تسجيل الحين").font(T.f(15)).foregroundStyle(T.muted).padding(.top, T.s4)
                }
            }
            .padding(16)
        }
    }
}
