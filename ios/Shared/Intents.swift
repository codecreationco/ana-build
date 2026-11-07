import AppIntents
import WidgetKit

/// زر الصح في الويدجت: يعلّم المهمة خلصت أو يرجعها.
struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "علّم المهمة"
    static var isDiscoverable: Bool = false

    @Parameter(title: "المهمة")
    var itemId: String

    @Parameter(title: "خلصت")
    var done: Bool

    init() {}

    init(itemId: String, done: Bool) {
        self.itemId = itemId
        self.done = done
    }

    func perform() async throws -> some IntentResult {
        try await API.setItem(id: itemId, status: done ? "done" : "planned", note: nil)
        if var f = FeedCache.load(), let i = f.items.firstIndex(where: { $0.id == itemId }) {
            f.items[i].status = done ? "done" : "planned"
            FeedCache.save(f)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
