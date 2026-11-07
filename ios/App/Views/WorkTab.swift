import SwiftUI

/// تاب الشغل: وزان ماث، كم خطوة خلصت، اللي ينتظرني، والباقي
struct WorkTab: View {
    @EnvironmentObject var life: LifeStore
    @State private var showDone = false
    @State private var open: WorkStep?

    var body: some View {
        let total = life.d.workSteps.count
        let done = life.doneSteps.count
        // تنتظرني: أي خطوة فيها شي بيدي أو قعدة معي (حتى لو الشغل نفسه خلص)
        let waiting = life.d.workSteps.filter { $0.waitingOn != nil }.sorted { $0.num < $1.num }
        let rest = life.remainingSteps.filter { s in !waiting.contains { $0.id == s.id } }
        let nextId = life.remainingSteps.first(where: { $0.status == .waiting || $0.status == .doing })?.id
        TabPage {
            PageHead(title: "الشغل", sub: "وزان ماث")
            if total == 0 {
                EmptyNote(text: "خطوات وزان ماث تنضاف من محادثة وزان ماث.").padding(.top, T.s5)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "\(done) من \(total) خطوات خلصت").font(T.f(20, .bold)).foregroundStyle(T.ink)
                    Spacer()
                    Text(verbatim: "\(waiting.count) تنتظرك").font(T.f(14)).foregroundStyle(T.muted)
                }
                Bar(value: Double(done) / Double(max(total, 1))).padding(.top, T.s2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, T.s4)
            .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
            .padding(.top, T.s5)

            if !waiting.isEmpty {
                SecLabel(text: "تنتظرك")
                steps(waiting, nextId: nextId)
            }
            if !rest.isEmpty {
                SecLabel(text: "الباقي")
                steps(rest, nextId: nextId)
            }
            Card {
                Button { withAnimation(.easeOut(duration: 0.15)) { showDone.toggle() } } label: {
                    HStack(spacing: T.s3) {
                        Text("اللي خلص").font(T.f(18)).foregroundStyle(T.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: "\(done)").font(T.f(17)).monospacedDigit().foregroundStyle(T.muted)
                        Image(systemName: showDone ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(T.dim)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showDone {
                    ForEach(life.doneSteps) { s in
                        RowLine()
                        LinkRow(num: "\(s.num)", title: s.title, sub: s.why, done: true) { open = s }
                    }
                }
            }
            .padding(.top, T.s3)
            NoteField(initial: life.dayNote("work-" + life.today), placeholder: "ملاحظة الشغل: وين وقفت، شي تبي تتذكره…") {
                life.setDayNote("work-" + life.today, $0)
            }
            .padding(.top, T.s3)
        }
        .sheet(item: $open) { s in
            StepSheet(step: s)
                .sheetStyle(420)
        }
    }

    private func steps(_ list: [WorkStep], nextId: String?) -> some View {
        Card {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                if i > 0 { RowLine() }
                LinkRow(num: "\(s.num)", title: s.title, sub: line(s), next: s.id == nextId) { open = s }
            }
        }
    }

    private func line(_ s: WorkStep) -> String {
        if let w = s.waitingOn, let d = s.decision { return w + " · " + d }
        if let w = s.waitingOn { return w }
        if let d = s.decision { return d }
        return s.why
    }
}

private struct StepSheet: View {
    let step: WorkStep
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "الخطوة \(step.num) · \(step.status.label)").font(T.f(14)).foregroundStyle(T.muted)
                    Text(step.title).font(T.f(26, .bold)).foregroundStyle(T.ink)
                    SecLabel(text: "شنو هي")
                    Text(step.why).font(T.f(17)).foregroundStyle(T.ink).card()
                    if let w = step.waitingOn {
                        SecLabel(text: "تنتظر")
                        Text(w).font(T.f(17)).foregroundStyle(T.ink).card()
                    }
                    if let d = step.decision {
                        SecLabel(text: "القرار اللي يحتاجك")
                        Text(d).font(T.f(17)).foregroundStyle(T.ink).card()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, T.s5)
                .padding(.bottom, 40)
            }
        }
    }
}
