import Foundation

/// أوقات الصلاة لمدينة الكويت، محسوبة بنفس طريقة تقويم الصايغ (طابقناها مع جدوله لـ 7–9 نوفمبر 2026، الفرق دقيقة بالأكثر):
/// - أذان الفجر: الشمس 18° تحت الأفق، وصلاة الصبح بعده بـ 14 دقيقة
/// - الظهر: الزوال + دقيقتين
/// - المغرب: الغروب + 15 دقيقة
/// - منتصف الليل: بين الغروب وفجر اليوم اللي بعده
enum PrayerCalc {
    static let lat = 29.3833
    static let lon = 48.0
    static let tz = 3.0

    struct Day {
        var fajrAdhan: Int
        var subh: Int
        var sunrise: Int
        var zawal: Int
        var dhuhr: Int
        var sunset: Int
        var maghrib: Int
        var midnight: Int
    }

    private static func julian(_ y: Int, _ m: Int, _ d: Int) -> Double {
        var y = y, m = m
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100
        let b = 2 - a + a / 4
        return Double(Int(365.25 * Double(y + 4716))) + Double(Int(30.6001 * Double(m + 1))) + Double(d) + Double(b) - 1524.5
    }

    private static func sun(_ jd: Double) -> (decl: Double, eqt: Double) {
        let d = jd - 2451545.0
        let g = (357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360) * .pi / 180
        let q = (280.459 + 0.98564736 * d).truncatingRemainder(dividingBy: 360)
        let l = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)).truncatingRemainder(dividingBy: 360) * .pi / 180
        let e = (23.439 - 0.00000036 * d) * .pi / 180
        var ra = atan2(cos(e) * sin(l), cos(l)) * 180 / .pi / 15
        ra = (ra + 24).truncatingRemainder(dividingBy: 24)
        var eqt = q / 15 - ra
        eqt = ((eqt + 12).truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24) - 12
        return (asin(sin(e) * sin(l)), eqt)
    }

    /// ساعات من الظهر لين ما تكون الشمس بزاوية معينة تحت الأفق
    private static func span(_ angle: Double, _ decl: Double) -> Double {
        let a = angle * .pi / 180, la = lat * .pi / 180
        let c = (-sin(a) - sin(la) * sin(decl)) / (cos(la) * cos(decl))
        return acos(max(-1, min(1, c))) * 180 / .pi / 15
    }

    private static func raw(_ key: String) -> (fajr: Int, sunrise: Int, noon: Int, sunset: Int)? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        let s = sun(julian(p[0], p[1], p[2]) + 0.5 - tz / 24)
        let noon = 12 + tz - lon / 15 - s.eqt
        func m(_ h: Double) -> Int { Int(floor(h * 60)) }
        return (m(noon - span(18, s.decl)), m(noon - span(0.833, s.decl)), m(noon), m(noon + span(0.833, s.decl)))
    }

    static func day(_ key: String) -> Day? {
        guard let r = raw(key), let n = raw(DateKit.add(1, to: key)) else { return nil }
        let midnight = (r.sunset + 1440 + n.fajr) / 2
        return Day(fajrAdhan: r.fajr, subh: r.fajr + 14, sunrise: r.sunrise, zawal: r.noon, dhuhr: r.noon + 2,
                   sunset: r.sunset, maghrib: r.sunset + 15, midnight: midnight)
    }
}
