import Core
import Data
import Foundation

/// Your own data, out, whenever you want it — the thing that makes the rest of the privacy page
/// credible. Three files, and money written as whole minor units: a formatted string is a
/// rendering, and a rendering cannot be added up again.
struct CSVExporter: Sendable {
    struct File: Equatable, Sendable {
        let name: String
        let text: String
    }

    static let listHeader = "name,quantity,unit,note,checked,shop,added_at"
    static let pricesHeader = "item_id,item,shop,recorded_at,amount_minor,currency,"
        + "minor_unit_exponent,quantity,source"
    static let receiptsHeader = "captured_at,shop,lines,total_minor,priced_minor,currency,"
        + "minor_unit_exponent,photo_on_this_phone"

    private let repository: Repository

    init(repository: Repository) {
        self.repository = repository
    }

    func files() throws -> [File] {
        let shops = Dictionary(try repository.shops().map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        // One kitchen shops in one currency; with no kitchen there is nothing to state, and an
        // empty column beats naming a currency nobody chose.
        let currencyCode = try repository.kitchens().first?.currencyCode
        return [
            File(name: "bagged-list.csv",
                 text: Self.list(try repository.items(), shops: shops)),
            File(name: "bagged-prices.csv",
                 text: Self.prices(try repository.priceObservations(),
                                   names: try repository.itemNames(), shops: shops)),
            File(name: "bagged-receipts.csv",
                 text: Self.receipts(try repository.receipts(), shops: shops,
                                     currencyCode: currencyCode)),
        ]
    }

    @discardableResult
    func write(to directory: URL = CSVExporter.defaultDirectory) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try files().map { file in
            let url = directory.appendingPathComponent(file.name)
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("Bagged export", isDirectory: true)
    }

    // MARK: - The three files

    static func list(_ items: [ListItem], shops: [ShopID: String]) -> String {
        table(listHeader, items.map { item in
            [item.name,
             quantity(item.quantity),
             item.unit ?? "",
             item.note ?? "",
             item.checked ? "yes" : "no",
             item.shopID.flatMap { shops[$0] } ?? "",
             timestamp(item.createdAt)]
        })
    }

    /// The id travels with every row so a price whose item nobody named is still yours — the
    /// name column stays empty rather than being invented from the id.
    static func prices(_ observations: [PriceObservation], names: [ItemID: String],
                       shops: [ShopID: String]) -> String {
        table(pricesHeader, observations.map { observation in
            [observation.itemID.rawValue.uuidString,
             names[observation.itemID] ?? "",
             shops[observation.shopID] ?? "",
             timestamp(observation.date),
             String(observation.amount.minorUnits),
             observation.amount.currencyCode,
             String(observation.amount.minorUnitExponent),
             // Empty where no count was recorded: that observation never claimed one, and a 1
             // written here would be this file inventing it.
             observation.quantityMilli.map { decimal(milli: $0) } ?? "",
             observation.source.rawValue]
        })
    }

    static func receipts(_ receipts: [Receipt], shops: [ShopID: String],
                         currencyCode: String?) -> String {
        let exponent = currencyCode.map { String(Money.minorUnitExponent(for: $0)) } ?? ""
        return table(receiptsHeader, receipts.map { receipt in
            [timestamp(receipt.capturedAt),
             shops[receipt.shopID] ?? "",
             String(receipt.lineCount),
             // What the till printed, or nothing. Never a sum of lines wearing the till's name.
             receipt.totalMinor.map(String.init) ?? "",
             receipt.recordedMinor.map(String.init) ?? "",
             currencyCode ?? "",
             exponent,
             receipt.photoPath == nil ? "no" : "yes"]
        })
    }

    // MARK: - Shapes

    /// Thousandths as an exact decimal, never through a Double: 4000 is "4", 500 is "0.5".
    static func decimal(milli: Int) -> String {
        let sign = milli < 0 ? "-" : ""
        let units = abs(milli)
        guard units % 1000 != 0 else { return "\(sign)\(units / 1000)" }
        var fraction = String(format: "%03d", units % 1000)
        while fraction.hasSuffix("0") { fraction.removeLast() }
        return "\(sign)\(units / 1000).\(fraction)"
    }

    static func quantity(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return decimal(milli: Int((value * 1000).rounded()))
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    /// RFC 4180. A note with a comma, a quote or a newline in it is the normal case.
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" })
        else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func table(_ header: String, _ rows: [[String]]) -> String {
        ([header] + rows.map { $0.map(field).joined(separator: ",") }).joined(separator: "\n")
            + "\n"
    }
}
