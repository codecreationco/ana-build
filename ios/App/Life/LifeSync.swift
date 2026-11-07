import Foundation
import Security

/// قاعدة البيانات (Supabase، مشروع hasan). المفتاح هذا عام عادي:
/// البيانات ما تنفتح إلا بمفتاح الجهاز اللي بالـKeychain.
enum Backend {
    static let url = "https://mujhmwudtgliipiynvjx.supabase.co"
    static let key = "sb_publishable_wKwl-Rqq5AAkuRpJ1du5mw_6y1kXMVO"
}

/// مفتاح سري يتولد مرة وحدة على التلفون، ويبقى بالـKeychain (حتى لو حذفت التطبيق ورجعته)
enum DeviceKey {
    private static let account = "hasan.device-key"

    static func get() -> String {
        if let k = read() { return k }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let k = bytes.map { String(format: "%02x", $0) }.joined()
        write(k)
        return k
    }

    private static func read() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ k: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(k.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }
}

enum SyncError: Error {
    case http(Int, String)
    case bad
}

/// الكلام مع قاعدة البيانات: نجيب الملف، ونحفظه إذا ما تغير بالسيرفر من آخر مرة
enum LifeSync {
    static func rpc(_ name: String, _ body: [String: Any]) async throws -> Any {
        guard let url = URL(string: Backend.url + "/rest/v1/rpc/" + name) else { throw SyncError.bad }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue(Backend.key, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw SyncError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func claim() async throws -> Bool {
        (try await rpc("claim_owner", ["p_key": DeviceKey.get()]) as? Bool) ?? false
    }

    /// (رقم النسخة، الملف إذا موجود)
    static func get() async throws -> (Int, Data?) {
        guard let o = try await rpc("get_life", ["p_key": DeviceKey.get()]) as? [String: Any] else { throw SyncError.bad }
        let v = (o["version"] as? NSNumber)?.intValue ?? 0
        guard let doc = o["doc"], !(doc is NSNull) else { return (v, nil) }
        return (v, try JSONSerialization.data(withJSONObject: doc))
    }

    /// يرجع (تم؟، رقم النسخة، الملف اللي بالسيرفر إذا تغير)
    static func save(_ doc: Data, base: Int) async throws -> (Bool, Int, Data?) {
        let obj = try JSONSerialization.jsonObject(with: doc)
        guard let o = try await rpc("save_life", ["p_key": DeviceKey.get(), "p_doc": obj, "p_base": base]) as? [String: Any]
        else { throw SyncError.bad }
        let ok = (o["ok"] as? Bool) ?? false
        let v = (o["version"] as? NSNumber)?.intValue ?? base
        var server: Data?
        if !ok, let d = o["doc"], !(d is NSNull) { server = try JSONSerialization.data(withJSONObject: d) }
        return (ok, v, server)
    }
}
