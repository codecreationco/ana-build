import Foundation
import Combine

/// وضع التصوير: GitHub يفتح التطبيق مرة وحدة بـ -snapAuto 1،
/// والتطبيق يقلب بين الشاشات، وGitHub يصور كل وحدة ويقول له «صورتها».
struct SnapStep {
    let name: String
    let tab: Int
    var seg: Int = 0
    var y: Int = 0
    var course: String? = nil
    var day = 0
}

final class Snap: ObservableObject {
    static let shared = Snap()

    static let on = UserDefaults.standard.string(forKey: "snapAuto") != nil
    static let firstDelay: TimeInterval = 6
    static let interval: TimeInterval = 4

    /// نفس الترتيب اللي يصور فيه GitHub (الملفات: 00.png، 01.png …)
    static let steps: [SnapStep] = {
        var s: [SnapStep] = []
        func add(_ n: String, _ t: Int, seg: Int = 0, course: String? = nil, day: Int = 0, ys: [Int]) {
            for y in ys { s.append(SnapStep(name: "\(n)-\(y)", tab: t, seg: seg, y: y, course: course, day: day)) }
        }
        add("home", 0, ys: [0, 600])
        add("today", 1, seg: 0, ys: [0, 600])
        add("tomorrow", 1, seg: 0, day: 1, ys: [0])
        add("yesterday", 1, seg: 0, day: -1, ys: [0])
        add("week", 1, seg: 1, ys: [0, 600])
        add("grid", 1, seg: 2, ys: [0, 700])
        add("appts", 1, seg: 3, ys: [0])
        add("prayer", 1, seg: 4, ys: [0, 500])
        add("lessons", 2, ys: [0, 600])
        add("course", 2, course: "matajir", ys: [0, 600])
        add("work", 3, ys: [0, 600])
        add("gym", 4, seg: 0, ys: [0, 600, 1200, 1800])
        add("progress", 4, seg: 1, ys: [0])
        add("food", 4, seg: 2, ys: [0, 500])
        add("sleep", 4, seg: 3, ys: [0, 500])
        add("wakesheet", 0, ys: [0])
        return s
    }()

    @Published var index = 0 {
        didSet { Snap.write("snap.txt", String(index)) }
    }

    /// ملاحظة: $index ينادي قبل ما تتغير القيمة، فالشاشات تاخذ الرقم الجديد من اللي يوصلها
    /// GitHub يقرا هالملفات عشان يعرف أي شاشة طالعة الحين
    static func write(_ name: String, _ text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
    var step: SnapStep { Snap.steps[min(index, Snap.steps.count - 1)] }

    private var timer: AnyCancellable?

    /// كل شاشة تستنى لين GitHub يصورها (يكتب ملف done-N)، وبعدها ننقل للي بعدها
    func start() {
        guard Snap.on, timer == nil else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for f in (try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? [] where f.hasPrefix("done-") {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(f))
        }
        Snap.write("snapcount.txt", String(Snap.steps.count))
        Snap.write("snapnames.txt", Snap.steps.map(\.name).joined(separator: "\n"))
        Snap.write("snap.txt", "0")
        timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, self.index < Snap.steps.count - 1 else { return }
                let done = docs.appendingPathComponent("done-\(self.index).txt")
                if FileManager.default.fileExists(atPath: done.path) { self.index += 1 }
            }
    }

    static var y: CGFloat { CGFloat(shared.step.y) }
}
