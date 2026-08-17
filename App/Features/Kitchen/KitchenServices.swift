import Core
import Data
import Foundation

/// Everything sharing needs, built from this build's Info.plist — one call, so the wiring in
/// `BaggedApp` cannot drift from what the screens expect.
///
/// A build with no `SupabaseURL` is a normal build, not a broken one: the app is local-first
/// and every screen says "on this phone only" rather than pretending a server exists.
enum KitchenServices {
    struct Services: Sendable {
        let auth: KitchenAuth
        let backend: KitchenClient
        let transport: SupabaseTransport
    }

    static func configuration() -> SupabaseConfig? {
        guard let urlText = value("SupabaseURL"), let url = URL(string: urlText),
              let key = value("SupabaseAnonKey") else { return nil }
        return SupabaseConfig(projectURL: url, anonKey: key)
    }

    static func make(config: SupabaseConfig? = configuration()) -> Services? {
        guard let config else { return nil }
        let auth = KitchenAuth(config: config)
        // The token is read per request from the one session; no credential is copied around.
        let transport = SupabaseTransport(config: config,
                                          accessToken: { await auth.accessToken() })
        return Services(auth: auth, backend: KitchenClient(config: config, auth: auth),
                        transport: transport)
    }

    private static func value(_ key: String) -> String? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }
}
