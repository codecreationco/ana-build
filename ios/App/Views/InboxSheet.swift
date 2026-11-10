import SwiftUI
import UIKit

/// زر الدفتر فوق بكل تاب، وعليه عدد الملاحظات اللي ما انرسلت
struct InboxButton: View {
    @EnvironmentObject var life: LifeStore
    @State private var open = false
    @State private var record = false

    var body: some View {
        Menu {
            Button { open = true } label: { Label("ملاحظة", systemImage: "square.and.pencil") }
            Button { record = true } label: { Label("سجّل درس من رابط", systemImage: "record.circle") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(T.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(T.card2))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    let n = life.unsent.count
                    if n > 0 {
                        Text(verbatim: "\(n)")
                            .font(T.f(11, .bold))
                            .foregroundStyle(T.pillInk)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Circle().fill(T.pill))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .accessibilityLabel("إضافة")
        .sheet(isPresented: $open) {
            InboxSheet()
                .environmentObject(life)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $record) {
            LinkRecordSheet()
                .environmentObject(life)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// تسجيل أي درس من رابط: «التسجيل» يدخل وياك، والملف ينحفظ بأول مجلد الدروب بوكس
struct LinkRecordSheet: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var name = ""
    @State private var startNow = true

    private var url: URL? {
        let t = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: t), let h = u.host, u.scheme?.hasPrefix("http") == true, !h.isEmpty else { return nil }
        return u
    }
    private var isMeet: Bool { url?.host?.contains("meet.google") == true }

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("سجّل درس").font(T.f(28, .bold)).foregroundStyle(T.ink)
                            Text("أي رابط زوم أو ميت، والملف ينحفظ بالدروب بوكس").font(T.f(13)).foregroundStyle(T.muted)
                        }
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

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("الرابط", text: $link)
                                .font(T.f(15))
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .environment(\.layoutDirection, .leftToRight)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(T.card2))
                            SmallButton(text: "الصق") {
                                if let s = UIPasteboard.general.string { link = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                            }
                        }
                        TextField("اسم الملف (اختياري)", text: $name)
                            .font(T.f(15))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(T.card2))
                        if url != nil {
                            Text(isMeet ? "ميت: دخّل «التسجيل» من كروم اللابتوب، والبرنامج يسجل الصوت"
                                        : "التسجيل يدخل بروحه، وإذا فيه غرفة انتظار لازم أحد يقبله")
                                .font(T.f(13)).foregroundStyle(T.muted)
                        }
                    }
                    .card()

                    Card {
                        ValueRow(title: "يبدأ يسجل على طول", sub: startNow ? "من أول ما يدخل" : "تبدأه إنت من الكرت بالرئيسية") {
                            Switch(on: startNow, label: "يبدأ يسجل على طول") { startNow.toggle() }
                        }
                    }

                    HStack(spacing: 10) {
                        Button { go(open: true) } label: {
                            Text("ادخل وسجّل")
                                .font(T.f(15, .semibold))
                                .foregroundStyle(T.pillInk)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Capsule().fill(T.pill))
                        }
                        .buttonStyle(.plain)
                        Button { go(open: false) } label: {
                            Text("سجّل بس")
                                .font(T.f(15, .semibold))
                                .foregroundStyle(T.ink)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Capsule().fill(T.card2))
                        }
                        .buttonStyle(.plain)
                    }
                    .disabled(url == nil)
                    .opacity(url == nil ? 0.5 : 1)
                }
                .padding(16)
            }
        }
    }

    private func go(open: Bool) {
        guard let u = url else { return }
        life.recAdhoc(url: u.absoluteString, title: name, start: startNow)
        if open { UIApplication.shared.open(u) }
        dismiss()
    }
}

/// الدفتر: أكتب أي شي، وبعدين أدزه لـClaude وهو يرتبه
struct InboxSheet: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var copied = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    composer
                    if !life.unsent.isEmpty { sendCard }
                    list
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("الدفتر").font(T.f(28, .bold)).foregroundStyle(T.ink)
                Text("اكتب أي شي، وبعدين دزه لـClaude يعدل الجدول").font(T.f(13)).foregroundStyle(T.muted)
            }
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
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("مثلاً: الموعد صار الخميس الجاي الساعة 8", text: $text, axis: .vertical)
                .font(T.f(15))
                .lineLimit(3...8)
                .focused($focused)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(T.card2))
            HStack {
                Spacer()
                Button {
                    life.addNote(text)
                    text = ""
                    focused = false
                } label: {
                    Text("حفظ")
                        .font(T.f(15, .semibold))
                        .foregroundStyle(T.pillInk)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(T.pill))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
        }
        .card()
    }

    private var sendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            BlockTitle(title: "دزها لـClaude", trailing: "\(life.unsent.count) ملاحظة")
            Text("لين نربط قاعدة البيانات: انسخها والصقها بالمحادثة. بعد الربط بتوصلني بروحها.")
                .font(T.f(13)).foregroundStyle(T.muted)
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = life.exportText
                    copied = true
                    life.markAllSent()
                } label: {
                    Label(copied ? "انتسخت" : "انسخ", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(T.f(14, .semibold))
                        .foregroundStyle(T.pillInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(T.pill))
                }
                .buttonStyle(.plain)
                ShareLink(item: life.exportText) {
                    Label("شارك", systemImage: "square.and.arrow.up")
                        .font(T.f(14, .semibold))
                        .foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(T.surface2))
                }
            }
        }
        .card()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !life.d.inbox.isEmpty {
                Text("الملاحظات").font(T.f(13, .semibold)).foregroundStyle(T.muted)
            }
            ForEach(life.d.inbox.sorted { $0.created > $1.created }) { n in
                NoteRow(note: n) { life.deleteNote(n.id) }
            }
            if life.d.inbox.isEmpty {
                EmptyNote(text: "ما في ملاحظات. اكتب أي شي يخص جدولك، مثل موعد جديد أو درس انلغى.")
            }
        }
    }
}

private struct NoteRow: View {
    let note: InboxNote
    let onDelete: () -> Void

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar@numbers=latn")
        f.timeZone = DateKit.tz
        f.dateFormat = "EEEE، h:mm a"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.text).font(T.f(14)).foregroundStyle(T.ink)
                HStack(spacing: 6) {
                    Text(Self.fmt.string(from: note.created)).font(T.f(11)).foregroundStyle(T.muted)
                    Text(note.sent ? "انرسلت" : "ما انرسلت")
                        .font(T.f(11, .medium))
                        .foregroundStyle(note.sent ? T.faint : T.ink)
                }
            }
            Spacer(minLength: 4)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(T.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("احذف الملاحظة")
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
    }
}
