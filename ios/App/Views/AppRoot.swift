import SwiftUI
import UIKit

/// أول شي يطلع: شاشة الشعار، وبعدها التبويبات.
struct AppRoot: View {
    @EnvironmentObject var life: LifeStore
    @Environment(\.scenePhase) private var phase
    @State private var splash = !Snap.on

    var body: some View {
        ZStack {
            MainTabs()
            if splash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeOut(duration: 0.35)) { splash = false }
        }
        .task {
            life.writeWidget()
            await life.pull()
            life.writeWidget()
        }
        .onChange(of: phase) { _, p in
            if p == .active {
                life.advance()
                LifeNotifier.schedule(life)
                life.writeWidget()
                Task { await life.pull(); life.writeWidget() }
            }
            if p == .background { life.writeWidget() }
        }
    }
}

struct SplashView: View {
    @State private var show = false

    var body: some View {
        ZStack {
            Color("LaunchBG").ignoresSafeArea()
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .overlay(alignment: .bottom) {
                    Text("حسن")
                        .font(T.f(40, .bold))
                        .foregroundStyle(T.ink)
                        .opacity(show ? 1 : 0)
                        .offset(y: show ? 78 : 90)
                }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4).delay(0.1)) { show = true } }
    }
}

/// لما تضغط التاب اللي إنت فيه: يصعد لأول الصفحة (ويرجع لأول شاشة بالدروس)
final class ScrollTop: ObservableObject {
    static let shared = ScrollTop()
    @Published var signal: (tab: Int, n: Int) = (-1, 0)
    func fire(_ tab: Int) { signal = (tab, signal.n + 1) }
}

struct TabIndexKey: EnvironmentKey { static let defaultValue = -1 }

extension EnvironmentValues {
    var tabIndex: Int {
        get { self[TabIndexKey.self] }
        set { self[TabIndexKey.self] = newValue }
    }
}

/// يروح لتاب ثاني (والقسم اللي فوق إذا اليوم أو الصحة)
struct GoKey: EnvironmentKey {
    static let defaultValue: (Int, Int?) -> Void = { _, _ in }
}

extension EnvironmentValues {
    var go: (Int, Int?) -> Void {
        get { self[GoKey.self] }
        set { self[GoKey.self] = newValue }
    }
}

/// الشريط اللي تحت: الرئيسية واليوم، وبعدها المساحات المثبتة (الدروس، الشغل، الصحة)
struct MainTabs: View {
    @EnvironmentObject var life: LifeStore
    @State private var tab = 0
    @State private var todaySeg = 0
    @State private var healthSeg = 0
    @ObservedObject private var snap = Snap.shared
    @State private var keyboard = false

    private let items: [(String, String)] = [
        ("الرئيسية", "house"),
        ("اليوم", "calendar"),
        ("الدروس", "book"),
        ("الشغل", "briefcase"),
        ("الصحة", "heart"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                page(0) { HomeTab() }
                page(1) { TodayTab(seg: $todaySeg) }
                page(2) { LessonsTab() }
                page(3) { WorkTab() }
                page(4) { HealthTab(seg: $healthSeg) }
                UndoBar()
            }
            .animation(.easeOut(duration: 0.25), value: life.toast)
            if !keyboard { bar }
        }
        .background(T.bg.ignoresSafeArea())
        .environment(\.go, { t, s in
            if let s {
                if t == 1 { todaySeg = s }
                if t == 4 { healthSeg = s }
            }
            tab = t
        })
        .onOpenURL { _ in tab = 1; todaySeg = 0 }
        .onAppear {
            if Snap.on { snap.start() }
            DispatchQueue.main.async { KeyboardTap.shared.install() }
        }
        .onReceive(snap.$index) { i in
            let st = Snap.steps[min(i, Snap.steps.count - 1)]
            guard Snap.on else { return }
            tab = st.tab
            if tab == 1 { todaySeg = st.seg }
            if tab == 4 { healthSeg = st.seg }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboard = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboard = false }
    }

    private func page<V: View>(_ i: Int, @ViewBuilder _ v: () -> V) -> some View {
        v()
            .environment(\.tabIndex, i)
            .opacity(tab == i ? 1 : 0)
            .allowsHitTesting(tab == i)
            .accessibilityHidden(tab != i)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    if tab == i { ScrollTop.shared.fire(i) } else { tab = i }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: items[i].1).font(.system(size: 20, weight: .regular))
                        Text(items[i].0).font(T.f(11, tab == i ? .bold : .regular)).lineLimit(1)
                    }
                    .foregroundStyle(tab == i ? T.accent : T.faint)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(tab == i ? .isSelected : [])
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 12)
        .background(T.bg.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
    }
}

/// مثل البرامج العادية: أي ضغطة برا خانة الكتابة تسكّر الكيبورد
final class KeyboardTap: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardTap()
    private weak var window: UIWindow?

    func install() {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let w = windows.first(where: \.isKeyWindow) ?? windows.first, w !== window else { return }
        let g = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        g.cancelsTouchesInView = false
        g.delegate = self
        w.addGestureRecognizer(g)
        window = w
    }

    @objc private func tap(_ g: UITapGestureRecognizer) {
        g.view?.endEditing(true)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // الضغط على خانة كتابة ثانية ما يسكّر، ينقل لها بس
        var v = touch.view
        while let x = v {
            if x is UITextField || x is UITextView { return false }
            v = x.superview
        }
        return true
    }
}

/// شاشة بأرضية التطبيق وتمرير. العناصر تحط مسافاتها بنفسها (من سلم T.s1…T.s6)،
/// و`Section` بداخلها رأسه يثبت فوق لما تنزل.
struct TabPage<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.tabIndex) private var tabIndex

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            if Snap.on {
                // وضع التصوير: نفس الصفحة بدون تمرير، منزّلة لمكان معين
                SnapPage {
                    VStack(alignment: .leading, spacing: 0) { content() }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, T.s5)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear.frame(height: 0).id("top")
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) { content() }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 40)
                    }
                    .onReceive(ScrollTop.shared.$signal) { s in
                        guard s.tab == tabIndex, s.n > 0 else { return }
                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                // خلفية تحت ساعة التلفون، عشان الكلام ما يطلع تحتها لما تنزل
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 0).background(T.bg)
                }
            }
        }
    }
}

/// صفحة بوضع التصوير: تنزل لمكان الخطوة الحالية
private struct SnapPage<C: View>: View {
    @ObservedObject private var snap = Snap.shared
    @ViewBuilder var content: () -> C

    var body: some View {
        GeometryReader { _ in
            content()
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -CGFloat(snap.step.y))
        }
        .clipped()
    }
}
