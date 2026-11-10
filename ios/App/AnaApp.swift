import SwiftUI
import UIKit
import UserNotifications
import BackgroundTasks
import WidgetKit

/// الإشعارات: تطلع حتى لو التطبيق مفتوح، وإشعار الدرس يفتح رابطه
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let s = response.notification.request.content.userInfo["link"] as? String, let url = URL(string: s) {
            DispatchQueue.main.async {
                // يفتح الدرس، ويرسل «التسجيل» يدخل وياك
                if let life = LifeStore.current, let c = life.d.courses.first(where: { $0.link == s }) {
                    life.enterLesson(c)
                } else {
                    UIApplication.shared.open(url)
                }
            }
        }
        completionHandler()
    }
}

@main
struct AnaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var life = LifeStore()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environmentObject(life)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .preferredColorScheme(.dark)
                // الخط يتبع إعداد حجم النص بالتلفون، لحد معين عشان الجدول ما يخترب
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .task {
                    guard !Snap.on else { return }
                    await LifeNotifier.requestAuth()
                    LifeNotifier.schedule(life)
                }
        }
        .backgroundTask(.appRefresh(Refresher.id)) {
            await Refresher.run()
        }
    }
}

/// تحديث بالخلفية: يسحب الجدول ويضبط التنبيهات حتى لو ما فتحت التطبيق.
enum Refresher {
    static let id = "com.ana.refresh"

    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 3 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    static func run() async {
        schedule()
        guard let life = await LifeStore.current else { return }
        await life.pull()
        await MainActor.run {
            life.advance()
            LifeNotifier.schedule(life)
            life.writeWidget()
        }
    }
}
