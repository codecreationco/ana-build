import Foundation

enum APIError: LocalizedError {
    case status(Int, String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case let .status(code, body): return "خطأ من السيرفر (\(code)): \(body.prefix(120))"
        case .notConfigured: return "إعدادات الاتصال ناقصة"
        }
    }
}

enum API {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    /// قبل ما نربط قاعدة البيانات يشتغل التطبيق على بيانات تجريبية
    static var isConfigured: Bool { !Secrets.supabaseURL.isEmpty && !Secrets.supabaseKey.isEmpty }

    static func rpc(_ name: String, _ body: [String: Any?]) async throws -> Data {
        guard let url = URL(string: Secrets.supabaseURL + "/rest/v1/rpc/" + name),
              !Secrets.supabaseKey.isEmpty else { throw APIError.notConfigured }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue(Secrets.supabaseKey, forHTTPHeaderField: "apikey")
        if Secrets.supabaseKey.hasPrefix("eyJ") {
            req.setValue("Bearer " + Secrets.supabaseKey, forHTTPHeaderField: "Authorization")
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var dict: [String: Any] = ["p_key": Secrets.appKey]
        for (k, v) in body { dict[k] = v ?? NSNull() }
        req.httpBody = try JSONSerialization.data(withJSONObject: dict)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw APIError.status(code, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func feed(from: String, to: String) async throws -> Feed {
        let data = try await rpc("ana_feed", ["p_from": from, "p_to": to])
        return try decoder.decode(Feed.self, from: data)
    }

    static func setItem(id: String, status: String?, note: String?) async throws {
        guard isConfigured else { return }
        _ = try await rpc("ana_set_item", ["p_id": id, "p_status": status, "p_note": note])
    }

    static func flexDone(id: String, undo: Bool) async throws {
        guard isConfigured else { return }
        _ = try await rpc("ana_flex_done", ["p_id": id, "p_undo": undo])
    }

    static func setDay(day: String, note: String?, finished: Bool?) async throws {
        guard isConfigured else { return }
        _ = try await rpc("ana_set_day", ["p_day": day, "p_note": note, "p_finished": finished])
    }
}

/// نسخة محلية من آخر بيانات، عشان التطبيق والويدجت يفتحون فوراً وبدون نت.
enum FeedCache {
    private static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ana-feed.json")
    }

    static func load() -> Feed? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return try? API.decoder.decode(Feed.self, from: d)
    }

    static func save(_ f: Feed) {
        if let d = try? API.encoder.encode(f) { try? d.write(to: url, options: .atomic) }
    }
}
