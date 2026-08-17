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

    /// ONE per process, forever. `KitchenAuth`'s invariant — "one actor owns the tokens, so a
    /// refresh can never race itself" — is a claim about the whole app, not about an instance,
    /// and a second `make()` breaks it: the two actors share one keychain item and one
    /// single-use refresh token, the loser gets a 400, and a 400 signs out. For a guest the
    /// anonymous session IS the membership, so signing out loses the kitchen with no way back
    /// in but asking the owner for a new link.
    @MainActor private static var shared: Services??

    @MainActor
    static func make(config: SupabaseConfig? = configuration()) -> Services? {
        if let shared { return shared }
        let made = build(config)
        shared = .some(made)
        return made
    }

    private static func build(_ config: SupabaseConfig?) -> Services? {
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
