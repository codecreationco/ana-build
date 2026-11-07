import SwiftUI

/// تاب الأخبار: مقسمة حسب المواضيع اللي تهمني
struct NewsTab: View {
    @EnvironmentObject var life: LifeStore
    @State private var topic: String? = nil

    var body: some View {
        TabPage {
            TabHeader(title: "الأخبار", subtitle: "من تيليجرام وحسابات معينة في X")
            topicBar
            NoticeCard()
            if let t = topic, let tp = life.d.topics.first(where: { $0.id == t }) {
                TopicSection(topic: tp, showHeader: false)
            } else {
                ForEach(life.d.topics) { tp in
                    TopicSection(topic: tp, showHeader: true)
                }
            }
        }
    }

    private var topicBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(id: nil, name: "الكل", icon: "square.grid.2x2.fill",
                     unread: life.d.news.filter { !$0.read }.count)
                ForEach(life.d.topics) { t in
                    chip(id: t.id, name: t.name, icon: t.icon,
                         unread: life.d.news.filter { $0.topic == t.id && !$0.read }.count)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(id: String?, name: String, icon: String, unread: Int) -> some View {
        let sel = topic == id
        return Button { withAnimation(.easeOut(duration: 0.15)) { topic = id } } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(name).font(T.f(14, .medium))
                if unread > 0 {
                    Text("\(unread)")
                        .font(T.f(11, .bold))
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(sel ? T.brandInk.opacity(0.25) : T.brandSoft))
                }
            }
            .foregroundStyle(sel ? T.brandInk : T.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(sel ? T.brand : T.surface))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }
}

private struct NoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(T.cream)
            Text("الأخبار هني أماكن فاضية. مساعد يراقب القنوات والحسابات أول بأول ويوزع الأخبار على المواضيع، نفصله بعدين. اضغط مطول على أي خبر تقيّم اهتمامك فيه من 10.")
                .font(T.f(13)).foregroundStyle(T.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).stroke(T.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

private struct TopicSection: View {
    @EnvironmentObject var life: LifeStore
    let topic: NewsTopic
    let showHeader: Bool

    var body: some View {
        let items = life.d.news.filter { $0.topic == topic.id }.sorted { $0.minutesAgo < $1.minutesAgo }
        return VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                HStack(spacing: 8) {
                    IconBubble(icon: topic.icon, size: 30)
                    Text(topic.name).font(T.f(17, .bold)).foregroundStyle(T.ink)
                    Spacer()
                    Text("\(items.filter { !$0.read }.count) جديد").font(T.f(12)).foregroundStyle(T.muted)
                }
            }
            VStack(spacing: 0) {
                ForEach(items) { n in
                    NewsRow(item: n)
                    if n.id != items.last?.id {
                        Rectangle().fill(T.line).frame(height: 1).padding(.leading, 40)
                    }
                }
            }
            .card(12)
        }
    }
}

private struct NewsRow: View {
    @EnvironmentObject var life: LifeStore
    let item: NewsItem

    var body: some View {
        Button { life.markRead(item.id) } label: {
            HStack(alignment: .top, spacing: 10) {
                platformIcon
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(T.f(15, item.read ? .medium : .semibold))
                        .foregroundStyle(item.read ? T.muted : T.ink)
                    Text(item.summary).font(T.f(13)).foregroundStyle(T.muted)
                    Text("\(item.source) · \(LFmt.ago(item.minutesAgo))").font(T.f(11)).foregroundStyle(T.muted)
                }
                Spacer(minLength: 4)
                if !item.read {
                    Circle().fill(T.brand).frame(width: 8, height: 8).padding(.top, 6)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Section("اهتمامك بهالخبر") {
                ForEach(Array((1...10).reversed()), id: \.self) { r in
                    Button {
                        life.setRating(item.id, item.rating == r ? nil : r)
                    } label: {
                        if item.rating == r {
                            Label(Self.label(r), systemImage: "checkmark")
                        } else {
                            Text(Self.label(r))
                        }
                    }
                }
            }
        }
    }

    static func label(_ r: Int) -> String {
        switch r {
        case 10: return "10 · وايد مهم"
        case 5: return "5 · متوسط"
        case 1: return "1 · ضعيف"
        default: return "\(r)"
        }
    }

    private var platformIcon: some View {
        Group {
            if item.platform == "telegram" {
                Image(systemName: "paperplane.fill").font(.system(size: 13, weight: .semibold))
            } else {
                Text("X").font(.system(size: 14, weight: .heavy))
            }
        }
        .foregroundStyle(T.ink)
        .frame(width: 30, height: 30)
        .background(Circle().fill(T.surface2))
        .accessibilityLabel(item.platform == "telegram" ? "تيليجرام" : "X")
    }
}
