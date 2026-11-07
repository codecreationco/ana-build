import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: CGFloat
        if s.count == 6 {
            r = CGFloat((v >> 16) & 0xFF) / 255
            g = CGFloat((v >> 8) & 0xFF) / 255
            b = CGFloat(v & 0xFF) / 255
        } else {
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

/// الاتجاه الهادي: كل شي رمادي على أسود، والفيروزي (لون الشعار) بس للمختار وللجاي.
enum T {
    // الأرضيات
    static let bg = Color(hex: "#000000")
    static let card = Color(hex: "#141416")
    static let card2 = Color(hex: "#1C1C1F")
    static let card3 = Color(hex: "#26262A")
    static let rowNext = Color(hex: "#18181B")
    static let cellEmpty = Color(hex: "#0B0B0D")
    static let cellDoneBg = Color(hex: "#19191C")
    static let line = Color(hex: "#222225")
    static let dim = Color(hex: "#3A3A3F")

    // النصوص
    static let ink = Color(hex: "#EDEDEF")
    static let muted = Color(hex: "#8B8B90")
    static let faint = Color(hex: "#828287")

    // الأزرار الفاتحة
    static let pill = Color(hex: "#D9D9DB")
    static let pillInk = Color(hex: "#111113")

    // الفيروزي: المختار والجاي بس
    static let accent = Color(hex: "#14C2CE")
    static let accentInk = Color(hex: "#04262A")

    // أسماء قديمة (الويدجت والدفتر والأخبار)، كلها صارت رمادي
    static let surface = card
    static let surface2 = card2
    static let brand = accent
    static let brandInk = accentInk
    static let brandSoft = card2
    static let good = muted
    static let onGood = pillInk
    static let cream = ink
    static let pin = accent
    static let pinInk = accentInk
    static let plate = card2
    static let plateInk = ink
    static let warn = muted

    // المسافات: سلم واحد بكل الشاشات
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24
    static let s6: CGFloat = 32

    /// الخط: نسيم للعربي، وIBM Plex للأرقام والإنجليزي (يطلع لحاله لأي حرف ما بنسيم).
    /// الملفات معدلة الحجم: نسيم أكبر 16٪ وPlex أصغر 6٪ عشان يتناسقون.
    static func f(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        Font(ui(size, w))
    }

    static func ui(_ size: CGFloat, _ w: Font.Weight = .regular) -> UIFont {
        let bold: Bool
        switch w {
        case .semibold, .bold, .heavy, .black: bold = true
        default: bold = false
        }
        // يكبر مع حجم النص بالتلفون، لحد xLarge عشان الجداول ما تخترب
        var cat = UITraitCollection.current.preferredContentSizeCategory
        if cat == .unspecified { cat = .large }
        if cat > .extraLarge { cat = .extraLarge }
        let s = UIFontMetrics(forTextStyle: .body)
            .scaledValue(for: size, compatibleWith: UITraitCollection(preferredContentSizeCategory: cat))
        let num = UIFontDescriptor(name: bold ? "HasanNum-Bold" : "HasanNum-Regular", size: s)
        let main = UIFontDescriptor(name: bold ? "HasanNassim-Bold" : "HasanNassim-Regular", size: s)
            .addingAttributes([.cascadeList: [num]])
        return UIFont(descriptor: main, size: s)
    }
}
