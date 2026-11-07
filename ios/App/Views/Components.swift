import SwiftUI
import UIKit

// أجزاء الاتجاه الهادي: بطاقة رمادية، صفوف بينها خط، ودائرة إنجاز وحدة بكل التطبيق.

// MARK: - البطاقة

struct CardBox: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
    }
}

extension View {
    func card(_ padding: CGFloat = 18) -> some View { modifier(CardBox(padding: padding)) }
}

/// بطاقة فيها صفوف (الصفوف تحط بينها RowLine)
struct Card<C: View>: View {
    @ViewBuilder var content: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct RowLine: View {
    var body: some View { Rectangle().fill(T.line).frame(height: 1) }
}

// MARK: - رأس الصفحة

/// العنوان، وعلى اليسار الدفتر وصورتي الصغيرة
struct PageHead: View {
    let title: String
    var sub: String? = nil
    var back: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: T.s2) {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(T.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(T.card2))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("رجوع")
                .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(T.f(34, .bold)).foregroundStyle(T.ink)
                if let sub {
                    Text(sub).font(T.f(15)).foregroundStyle(T.muted)
                }
            }
            Spacer(minLength: T.s2)
            HStack(spacing: T.s2) {
                InboxButton()
                MiniAvatar()
            }
            .padding(.top, 2)
        }
        .frame(minHeight: 44)
    }
}

/// صورتي صغيرة فوق بكل الصفحات، تودي للرئيسية
struct MiniAvatar: View {
    @Environment(\.go) private var go

    var body: some View {
        Button { go(0, nil) } label: {
            Image("LaunchLogo")
                .resizable().scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("الرئيسية")
    }
}

/// أقسام بالكلام: المختار فيروزي وتحته خط
struct SegText: View {
    let items: [String]
    @Binding var sel: Int

    var body: some View {
        HStack(spacing: 18) {
            ForEach(items.indices, id: \.self) { i in
                Button { withAnimation(.easeOut(duration: 0.15)) { sel = i } } label: {
                    VStack(spacing: 2) {
                        Text(items[i])
                            .font(T.f(16, sel == i ? .bold : .regular))
                            .foregroundStyle(sel == i ? T.accent : T.faint)
                            .lineLimit(1)
                            .fixedSize()
                        Rectangle().fill(sel == i ? T.accent : Color.clear).frame(height: 2)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(sel == i ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.top, T.s2)
    }
}

/// عنوان صغير رمادي فوق بطاقة (مسافة 32 فوق و12 تحت)
struct SecLabel: View {
    let text: String
    var trailing: String? = nil
    var color: Color = T.muted
    var center = false

    var body: some View {
        HStack {
            if center { Spacer() }
            Text(text).foregroundStyle(color)
            Spacer()
            if let trailing { Text(trailing).foregroundStyle(T.muted) }
        }
        .font(T.f(14))
        .padding(.horizontal, 2)
        .padding(.top, T.s6)
        .padding(.bottom, T.s3)
        .accessibilityAddTraits(.isHeader)
    }
}

/// عنوان قسم كبير: «الصبح»، «المسا»، «بأي وقت»
struct SecHead: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(T.f(20, .bold)).foregroundStyle(T.ink)
            Spacer()
            if let trailing { Text(trailing).font(T.f(14)).foregroundStyle(T.muted) }
        }
        .padding(.horizontal, 2)
        .padding(.top, T.s5)
        .padding(.bottom, T.s2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct Foot: View {
    let text: String
    var center = true

    var body: some View {
        Text(text)
            .font(T.f(14)).foregroundStyle(T.faint)
            .multilineTextAlignment(center ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
            .padding(.top, T.s3)
    }
}

// MARK: - دائرة الإنجاز

/// نفس الدائرة بكل التطبيق: فاضية، وإذا خلص تتعبى رمادي وفيها صح
struct Check: View {
    let on: Bool
    var label = "خلصت"
    var hit: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CheckMark(on: on)
                .frame(width: hit, height: hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "رجّعها" : label)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

struct CheckMark: View {
    let on: Bool

    var body: some View {
        ZStack {
            Circle().fill(on ? T.dim : Color.clear)
            Circle().strokeBorder(T.dim, lineWidth: 1.6)
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(T.muted)
            }
        }
        .frame(width: 26, height: 26)
        .animation(.easeOut(duration: 0.15), value: on)
    }
}

// MARK: - الصفوف

/// صف بالقائمة: الوقت، العنوان وتحته سطر، ودائرة الإنجاز
struct ItemRow: View {
    var time: String? = nil
    var timeCol = true
    let title: String
    var sub: String? = nil
    var tag: String? = nil
    var done = false
    var next = false
    var checkLabel = "خلصت"
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: T.s3) {
            if timeCol, let time {
                Text(time)
                    .font(T.f(14)).monospacedDigit()
                    .foregroundStyle(next ? T.accent : T.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: 58, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let tag { Text(tag).font(T.f(12)).foregroundStyle(T.accent) }
                Text(title).font(T.f(18)).foregroundStyle(done ? T.faint : T.ink)
                if let sub { Text(sub).font(T.f(14)).foregroundStyle(T.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onToggle {
                Check(on: done, label: checkLabel, action: onToggle)
                    .padding(.horizontal, -9)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .background(next ? T.rowNext : Color.clear)
    }
}

/// صف فيه عنوان وقيمة على اليسار (وقت، رقم…)، ممكن ينضغط
struct ValueRow<Trailing: View>: View {
    let title: String
    var sub: String? = nil
    var value: String? = nil
    var valueDim = false
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let row = HStack(spacing: T.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(T.f(18)).foregroundStyle(T.ink)
                if let sub { Text(sub).font(T.f(14)).foregroundStyle(T.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value).font(T.f(17)).monospacedDigit()
                    .foregroundStyle(valueDim ? T.muted : T.ink)
            }
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

extension ValueRow where Trailing == EmptyView {
    /// بدون شي على اليسار وبدون ضغط (للضغط استخدم النسخة اللي فيها trailing)
    init(title: String, sub: String? = nil, value: String? = nil, valueDim: Bool = false) {
        self.init(title: title, sub: sub, value: value, valueDim: valueDim, action: nil, trailing: { EmptyView() })
    }
}

/// صف يفتح شي ثاني: أيقونة، عنوان، سطر، وسهم
struct LinkRow: View {
    var icon: String? = nil
    var num: String? = nil
    let title: String
    var sub: String? = nil
    var done = false
    var next = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: T.s3) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 17)).foregroundStyle(T.muted).frame(width: 22)
                }
                if let num {
                    Text(num).font(T.f(14)).monospacedDigit()
                        .foregroundStyle(next ? T.accent : T.muted)
                        .frame(width: 58, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(T.f(18)).foregroundStyle(done ? T.faint : T.ink)
                    if let sub { Text(sub).font(T.f(14)).foregroundStyle(T.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Chevron()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .background(next ? T.rowNext : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.dim)
    }
}

// MARK: - الأزرار

/// زر حبة: فاتح للأساسي، ورمادي للثاني
struct PillButton: View {
    let text: String
    var ghost = false
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(T.f(15, .bold))
                .lineLimit(1)
                .foregroundStyle(ghost ? T.ink : T.pillInk)
                .padding(.horizontal, 18)
                .frame(maxWidth: wide ? .infinity : nil, minHeight: wide ? 50 : 36)
                .background(Capsule().fill(ghost ? T.card2 : T.pill))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// وقت بمربع رمادي ينضغط عشان تغيّره (نفس اللي تحت الاسم بالرئيسية)
struct TimeChip: View {
    let text: String
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(T.f(16, .bold)).monospacedDigit()
                .foregroundStyle(T.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(T.card2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label + "، " + text)
    }
}

/// زر حبة صغيرة بالكلام (للقوائم)
struct SmallButton: View {
    let text: String
    var label: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(T.f(14, .bold))
                .lineLimit(1)
                .foregroundStyle(T.ink)
                .padding(.horizontal, 14)
                .frame(minWidth: 36, minHeight: 36)
                .background(Capsule().fill(T.card2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? text)
    }
}

/// مفتاح تشغيل: فيروزي إذا شغال
struct Switch: View {
    let on: Bool
    var label: String
    let action: () -> Void

    var body: some View {
        Toggle(label, isOn: Binding(get: { on }, set: { _ in action() }))
            .labelsHidden()
            .tint(T.accent)
    }
}

/// شريط تقدم رفيع رمادي
struct Bar: View {
    let value: Double   // 0...1
    var color: Color = T.muted
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(T.card2)
                Capsule().fill(color).frame(width: g.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

struct StatusChip: View {
    let status: ApptStatus

    var body: some View {
        Text(status.label)
            .font(T.f(13))
            .foregroundStyle(T.muted)
            .padding(.horizontal, 10).padding(.vertical, 1)
            .overlay(Capsule().stroke(T.dim, lineWidth: 1))
    }
}

/// حبة صغيرة بإطار (مثل «راحة 2:30»)
struct OutlineChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(T.f(13)).monospacedDigit()
            .foregroundStyle(T.muted)
            .padding(.horizontal, 10).padding(.vertical, 1)
            .overlay(Capsule().stroke(T.dim, lineWidth: 1))
            .fixedSize()
    }
}

// MARK: - الكتابة

/// خانة ملاحظة رمادية تنحفظ لما تطلع منها
struct NoteField: View {
    let initial: String
    let placeholder: String
    var boxed = true
    var size: CGFloat = 15
    var color: Color = T.ink
    let onSave: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(T.faint), axis: .vertical)
            .font(T.f(size))
            .foregroundStyle(color)
            .lineLimit(1...6)
            .focused($focused)
            .submitLabel(.done)
            .padding(.horizontal, boxed ? 18 : 0)
            .padding(.vertical, boxed ? 14 : 0)
            .background {
                if boxed { RoundedRectangle(cornerRadius: 18).fill(T.card) }
            }
            .onAppear { text = initial }
            .onChange(of: initial) { _, v in if !focused { text = v } }
            .onChange(of: focused) { _, f in if !f { onSave(text) } }
            .onSubmit { focused = false }
    }
}

/// خانة رقم بجدول النادي: رمادي، والرقم بالنص
struct CellField: View {
    let initial: String
    var placeholder = "—"
    var decimal = true
    var dimmed = false
    var label: String
    let onChange: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(T.faint).font(T.f(17)))
            .font(T.f(17, .bold)).monospacedDigit()
            .foregroundStyle(dimmed ? T.muted : T.ink)
            .multilineTextAlignment(.center)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .focused($focused)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(dimmed ? T.cellDoneBg : T.card2))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? T.muted : Color.clear, lineWidth: 1))
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityLabel(label)
            .onAppear { text = initial }
            .onChange(of: initial) { _, v in if !focused { text = v } }
            .onChange(of: text) { _, v in if focused { onChange(v) } }
    }
}

enum NumParse {
    /// يقبل الأرقام العربية والفاصلة
    static func double(_ s: String) -> Double? {
        let map: [Character: Character] = ["٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9", "٫": ".", ",": ".", "،": "."]
        let t = String(s.map { map[$0] ?? $0 }).filter { "0123456789.".contains($0) }
        return t.isEmpty ? nil : Double(t)
    }

    static func int(_ s: String) -> Int? {
        double(s).map { Int($0) }
    }
}

// MARK: - اختيار الوقت بعجلة الآيفون

/// يحول دقايق من نص الليل لتاريخ اليوم، عشان عجلة الوقت
func minutesDate(_ m: Binding<Int>) -> Binding<Date> {
    Binding(
        get: {
            DateKit.cal.date(bySettingHour: m.wrappedValue / 60 % 24, minute: m.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        },
        set: { d in
            let c = DateKit.cal.dateComponents([.hour, .minute], from: d)
            m.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
}

/// عجلة الوقت العادية مال الآيفون (أو المدة إذا duration)
struct TimeWheel: View {
    @Binding var value: Int
    var duration = false

    var body: some View {
        Group {
            if duration {
                DurationWheel(minutes: $value)
            } else {
                DatePicker("", selection: minutesDate($value), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
        .environment(\.timeZone, DateKit.tz)
    }
}

/// صف فيه عنوان ووقت ينضغط ويطلع عجلة الآيفون (مثل التقويم)
struct TimeRow: View {
    let label: String
    var sub: String? = nil
    @Binding var value: Int

    var body: some View {
        HStack(spacing: T.s3) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(T.f(17)).foregroundStyle(T.ink)
                if let sub { Text(sub).font(T.f(13)).foregroundStyle(T.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker("", selection: minutesDate($value), displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
                .environment(\.timeZone, DateKit.tz)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
    }
}

/// عجلة المدة (ساعات ودقايق) مثل المؤقت بالآيفون، كل 5 دقايق
struct DurationWheel: UIViewRepresentable {
    @Binding var minutes: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let p = UIDatePicker()
        p.datePickerMode = .countDownTimer
        p.minuteInterval = 5
        p.locale = Locale(identifier: "ar@numbers=latn")
        p.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        let v = TimeInterval(max(minutes, 5) * 60)
        p.countDownDuration = v
        DispatchQueue.main.async { p.countDownDuration = v }
        return p
    }

    func updateUIView(_ p: UIDatePicker, context: Context) {
        if Int(p.countDownDuration / 60) != minutes, minutes >= 5 {
            p.countDownDuration = TimeInterval(minutes * 60)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: DurationWheel
        init(_ p: DurationWheel) { parent = p }
        @objc func changed(_ p: UIDatePicker) { parent.minutes = Int(p.countDownDuration / 60) }
    }
}

/// ورقة صغيرة تحت: عنوان، والمحتوى، وزر حفظ
struct EditSheet<C: View>: View {
    let title: String
    var note: String? = nil
    var saveText = "حفظ"
    var clearText: String? = nil
    let onSave: () -> Void
    var onClear: (() -> Void)? = nil
    @ViewBuilder var content: () -> C
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: T.s3) {
                Text(title).font(T.f(20, .bold)).foregroundStyle(T.ink).padding(.top, T.s5)
                content()
                if let note { Text(note).font(T.f(13)).foregroundStyle(T.muted) }
                Spacer(minLength: 0)
                PillButton(text: saveText, wide: true) { onSave(); dismiss() }
                if let clearText, let onClear {
                    Button { onClear(); dismiss() } label: {
                        Text(clearText).font(T.f(15)).foregroundStyle(T.muted).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, T.s2)
        }
    }
}

extension View {
    /// نفس شكل الأوراق بكل التطبيق
    func sheetStyle(_ height: CGFloat) -> some View {
        self
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.visible)
            .presentationBackground(T.bg)
    }
}

// MARK: - أشياء قديمة تستخدمها شاشة الأخبار والدفتر

struct TabHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View { PageHead(title: title, sub: subtitle) }
}

struct IconBubble: View {
    let icon: String
    var color: Color = T.muted
    var bg: Color = T.card2
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(Circle().fill(bg))
    }
}

struct BlockTitle: View {
    let title: String
    var trailing: String? = nil
    var trailingColor: Color = T.muted

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(T.f(17, .bold)).foregroundStyle(T.ink)
            Spacer(minLength: 8)
            if let trailing { Text(trailing).font(T.f(14)).foregroundStyle(trailingColor) }
        }
    }
}

struct EmptyNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(T.f(15))
            .foregroundStyle(T.faint)
            .multilineTextAlignment(.center)
            .padding(.vertical, 22)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(T.card))
    }
}
