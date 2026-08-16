import Foundation

/// Open Food Facts at runtime and only at runtime. `DECISIONS.md` and `SOURCING.md` draw the
/// line: querying is use, importing is derivation — so what comes back is a suggestion on
/// screen, and nothing from it is written to `catalog.db`, to a table, or to a file.
struct ProductLookup: Sendable {

    /// The one flag, and its meaning: on, a barcode this kitchen cannot name is sent to Open
    /// Food Facts. Absent means on. Data & privacy (wave 9) writes it; off, no code ever leaves
    /// the phone.
    static let settingKey = "barcode.lookup.openFoodFacts"

    /// A person standing in a shop out-waits nothing, and there is no retry: the question this
    /// answers is already on screen and already answerable without it.
    static let timeout: TimeInterval = 2
    /// A product name, not an essay. Longer than this is junk, and a truncated one is a name
    /// nobody wrote — so it is refused rather than shown.
    static let maxNameCharacters = 60

    private static let root = "https://world.openfoodfacts.org"
    /// Ephemeral because a URL cache is a file: their data on our disk is the ODbL question we
    /// do not open.
    static let ephemeralSession = URLSession(configuration: .ephemeral)

    private let session: URLSession

    init(session: URLSession = ProductLookup.ephemeralSession) {
        self.session = session
    }

    @MainActor static func isEnabled(_ defaults: UserDefaults = .appGroup()) -> Bool {
        defaults.object(forKey: settingKey) as? Bool ?? true
    }

    /// The name Open Food Facts has for this code, or nil for every other outcome there is —
    /// off, offline, timeout, 404, junk JSON, a product with no name. The screen behaves
    /// identically for all of them, so one answer is its whole vocabulary.
    func name(for code: String) async -> String? {
        guard let url = Self.url(for: code) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: Self.timeout)
        // They are a nonprofit, they ask reusers to say who they are, and they block generic
        // agents. One request per unknown code — never a batch, never a sweep, never a retry.
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpShouldHandleCookies = false
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return Self.name(in: data, code: code)
        } catch {
            return nil
        }
    }

    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        return "Bagged/\(version as? String ?? "1.0") (https://bagged.app)"
    }

    /// Field selection, because asking a free service for a whole product record to read one
    /// string out of it is not being a good guest.
    static func url(for code: String) -> URL? {
        guard isProductCode(code) else { return nil }
        return URL(string: "\(root)/api/v2/product/\(code).json?fields=product_name")
    }

    /// EAN-8 through GTIN-14, digits only. This is the guard that a Code 128 payload — a shop's
    /// own shelf label, a parcel number, whatever else is printed on a packet — is never handed
    /// to a third party.
    static func isProductCode(_ code: String) -> Bool {
        (8 ... 14).contains(code.count) && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Untrusted third-party text on its way to a `Text`: no control or format characters, one
    /// space between words, and never the barcode's own digits wearing a name's clothes.
    static func suggestedName(_ raw: String?, code: String) -> String? {
        guard let raw else { return nil }
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                scalars.append(" ")
            } else if !CharacterSet.controlCharacters.contains(scalar) {
                scalars.append(scalar)
            }
        }
        let name = String(scalars).split(separator: " ").joined(separator: " ")
        guard !name.isEmpty, name.count <= maxNameCharacters, name != code else { return nil }
        return name
    }

    private static func name(in data: Data, code: String) -> String? {
        guard let body = try? JSONDecoder().decode(Body.self, from: data) else { return nil }
        // A 0 status is "no such product", which their API can say with a 200.
        guard body.status != 0 else { return nil }
        return suggestedName(body.product?.productName, code: code)
    }

    private struct Body: Decodable {
        let status: Int?
        let product: Product?

        struct Product: Decodable {
            let productName: String?

            private enum CodingKeys: String, CodingKey { case productName = "product_name" }
        }

        private enum CodingKeys: String, CodingKey { case status, product }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // A status we cannot read as a number is not a "not found" — the name still has to
            // survive `suggestedName` before anyone sees it.
            status = try? container.decodeIfPresent(Int.self, forKey: .status)
            product = try container.decodeIfPresent(Product.self, forKey: .product)
        }
    }
}

/// The suggestion as the barcode screen holds it: one lookup per code this kitchen cannot name,
/// an answer that may never come, and a memory that dies with the screen.
@Observable @MainActor
final class ProductSuggestion {
    /// Disclosed on the screen itself, because a barcode leaving the phone is something
    /// `PRODUCT.md` §5 says out loud rather than burying.
    let isEnabled: Bool

    /// The code the current suggestion belongs to — the answer to any other one is discarded.
    private(set) var code: String?
    private(set) var name: String?

    private let lookup: ProductLookup
    /// The lifetime of the capture flow and no longer: the alias op means a code taught once is
    /// never looked up again, so a file of someone else's data would buy almost nothing.
    private var seen: [String: String] = [:]

    init(lookup: ProductLookup = ProductLookup(), defaults: UserDefaults = .appGroup()) {
        self.lookup = lookup
        isEnabled = ProductLookup.isEnabled(defaults)
    }

    func ask(about code: String) async {
        self.code = code
        name = seen[code]
        guard isEnabled, name == nil else { return }
        guard let found = await lookup.name(for: code) else { return }
        // The user scanned on while this was in flight; answering the old question here would
        // put one packet's name under another packet's code.
        guard self.code == code else { return }
        seen[code] = found
        name = found
    }

    func clear() {
        code = nil
        name = nil
    }
}
