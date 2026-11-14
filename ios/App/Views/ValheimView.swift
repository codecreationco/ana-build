import SwiftUI
import UIKit

/// سيرفر فالهايم على كمبيوتر حسن: وكيل على الكمبيوتر يكتب الحالة، والتطبيق يرسل تشغيل أو إطفاء.
struct VhState: Decodable, Equatable {
    var state: String?
    var joinCode: String?
    var players: Int?
    var serverName: String?
    var world: String?
    var startedAt: String?
    var stateAt: String?
    var error: String?
    var cmd: String?
    var cmdAt: String?
    var pcOnline: Bool?

    var online: Bool { pcOnline ?? false }
    var running: Bool { state == "running" }
    var busy: Bool { cmd != nil || state == "starting" || state == "stopping" }

    /// سطر قصير للرئيسية
    var line: String {
        if !online { return "الكمبيوتر طافي" }
        switch state ?? "" {
        case "running":
            let p = players ?? 0
            return p == 0 ? "شغال · ماكو أحد" : (p == 1 ? "شغال · لاعب واحد" : "شغال · \(p) لاعبين")
        case "starting": return "يشتغل…"
        case "stopping": return "يطفي…"
        case "error": return "صار خطأ"
        default: return cmd == "start" ? "يشتغل…" : "طافي"
        }
    }
}

extension LifeStore {
    func vhRefresh() async {
        guard !Snap.on else { return }
        guard let o = try? await LifeSync.rpc("vh_get", ["p_key": DeviceKey.get()]) else { return }
        if let s = Self.vhDecode(o), s != vh { vh = s }
    }

    func vhSend(_ cmd: String) {
        guard !Snap.on else { return }
        vh?.cmd = cmd
        Task {
            do {
                let o = try await LifeSync.rpc("vh_send", ["p_key": DeviceKey.get(), "p_cmd": cmd])
                if let s = Self.vhDecode(o) { vh = s }
            } catch {
                toast = UndoToast(text: "ما وصل الأمر للسيرفر")
            }
        }
    }

    static func vhDecode(_ o: Any) -> VhState? {
        guard let data = try? JSONSerialization.data(withJSONObject: o) else { return nil }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try? dec.decode(VhState.self, from: data)
    }
}

/// صفحة فالهايم: تنفتح من «مساحاتي» وتتسكر بـ X
struct ValheimView: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .top) {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("فالهايم").font(T.f(34, .bold)).foregroundStyle(T.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(T.muted)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(T.card2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("سكّر")
                    }
                    .padding(.top, T.s2)

                    if let s = life.vh {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            content(s, ctx.date)
                        }
                    } else {
                        Text("يجيب حالة السيرفر…").font(T.f(16)).foregroundStyle(T.muted).padding(.top, T.s5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .task {
            // والصفحة مفتوحة: كل ثانيتين إذا فيه أمر شغال، وكل ٥ ثواني غير جذي
            while !Task.isCancelled {
                await life.vhRefresh()
                try? await Task.sleep(nanoseconds: (life.vh?.busy == true) ? 2_000_000_000 : 5_000_000_000)
            }
        }
    }

    private func dotColor(_ s: VhState) -> Color {
        if !s.online { return T.dim }
        switch s.state ?? "" {
        case "running": return T.accent
        case "error": return RecorderCard.red
        case "starting", "stopping": return T.muted
        default: return T.dim
        }
    }

    private func headline(_ s: VhState) -> String {
        if !s.online { return "الكمبيوتر طافي" }
        if s.cmd == "start" && s.state != "running" { return "يشتغل…" }
        if s.cmd == "stop" && s.state == "running" { return "يطفي…" }
        switch s.state ?? "" {
        case "running": return "شغال"
        case "starting": return "يشتغل…"
        case "stopping": return "يطفي…"
        case "error": return "صار خطأ"
        default: return "طافي"
        }
    }

    private func since(_ iso: String?, _ now: Date) -> String? {
        guard let d = RecSession.date(iso) else { return nil }
        let m = max(0, Int(now.timeIntervalSince(d)) / 60)
        if m < 1 { return "من شوي" }
        if m < 60 { return "من \(m) د" }
        return "من \(m / 60) س \(m % 60) د"
    }

    @ViewBuilder
    private func content(_ s: VhState, _ now: Date) -> some View {
        VStack(alignment: .leading, spacing: T.s3) {
            // الحالة
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Circle().fill(dotColor(s)).frame(width: 12, height: 12)
                        Text(verbatim: headline(s)).font(T.f(26, .bold)).foregroundStyle(T.ink)
                    }
                    let name = [s.serverName, s.world].compactMap { $0 }.joined(separator: " · ")
                    if !name.isEmpty {
                        Text(verbatim: name).font(T.f(15)).foregroundStyle(T.muted)
                    }
                    if s.online && s.running {
                        let p = s.players ?? 0
                        let who = p == 0 ? "ماكو أحد داخل" : (p == 1 ? "لاعب واحد داخل" : "\(p) لاعبين داخل")
                        Text(verbatim: who + (since(s.startedAt, now).map { " · شغال " + $0 } ?? ""))
                            .font(T.f(15)).foregroundStyle(T.muted)
                    }
                    if !s.online {
                        Text("شغّل الكمبيوتر، والوكيل يرجع يتصل بروحه. لين ذاك ما يصير تشغيل ولا إطفاء.")
                            .font(T.f(14)).foregroundStyle(T.muted)
                    }
                    if let e = s.error, !e.isEmpty {
                        Text(verbatim: e).font(T.f(14)).foregroundStyle(RecorderCard.red)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, T.s4)

            // كود الدخول
            if s.online && s.running, let code = s.joinCode, !code.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("كود الدخول").font(T.f(14)).foregroundStyle(T.muted)
                        HStack {
                            Text(verbatim: code)
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(T.ink)
                                .textSelection(.enabled)
                                .environment(\.layoutDirection, .leftToRight)
                            Spacer()
                            SmallButton(text: copied ? "انتسخ" : "انسخ") {
                                UIPasteboard.general.string = code
                                copied = true
                                Task { try? await Task.sleep(nanoseconds: 2_000_000_000); copied = false }
                            }
                        }
                        Text("يتغير كل ما يعاد تشغيل السيرفر").font(T.f(13)).foregroundStyle(T.faint)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if s.online && (s.state == "starting" || s.cmd == "start") {
                Text("الكود يطلع لما يشتغل السيرفر، عادة بعد دقيقة أو دقيقتين")
                    .font(T.f(14)).foregroundStyle(T.muted)
            }

            // الزر
            let start = !s.running && s.state != "stopping"
            Button {
                life.vhSend(start ? "start" : "stop")
            } label: {
                Text(start ? "شغّل السيرفر" : "طفّ السيرفر")
                    .font(T.f(17, .semibold))
                    .foregroundStyle(start ? T.pillInk : T.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(start ? T.pill : T.card2))
            }
            .buttonStyle(.plain)
            .disabled(!s.online || s.busy)
            .opacity(!s.online || s.busy ? 0.45 : 1)
            .padding(.top, T.s2)
            if !start && s.online && !s.busy {
                Text("الإطفاء يحفظ العالم أول، ويطفي خلال دقيقة تقريباً").font(T.f(13)).foregroundStyle(T.faint)
            }
        }
    }
}
