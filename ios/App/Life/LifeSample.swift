import Foundation

/// نسخة البناء العامة: بدون بيانات تجريبية
enum LifeSample {
    static func make(today: String = DateKit.todayKey) -> LifeData { .empty }
}
