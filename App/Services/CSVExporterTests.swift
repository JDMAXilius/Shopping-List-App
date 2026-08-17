import Core
import Data
import Foundation
import XCTest

@testable import Bagged

final class CSVExporterTests: XCTestCase {
    private let kitchen = Kitchen(name: "test kitchen", currencyCode: "USD")
    private let shopID = ShopID()
    private let itemID = ItemID()
    private let now = Date(timeIntervalSince1970: 1_755_000_000)

    private var shops: [ShopID: String] { [shopID: "Trader Joe's"] }

    private func observation(_ minor: Int, currency: String = "USD",
                             quantity: Double? = nil) -> PriceObservation {
        PriceObservation(itemID: itemID, shopID: shopID, date: now,
                         amount: Money(minorUnits: minor, currencyCode: currency),
                         source: .receipt, quantity: quantity)
    }

    // MARK: - Money, out and back

    func testEveryAmountRoundTripsThroughTheFileExactly() throws {
        let amounts = [Money(minorUnits: 1), Money(minorUnits: 449),
                       Money(minorUnits: 999_999), Money(minorUnits: 500, currencyCode: "JPY"),
                       Money(minorUnits: 1_500, currencyCode: "BHD")]
        let text = CSVExporter.prices(amounts.map {
            PriceObservation(itemID: itemID, shopID: shopID, date: now, amount: $0,
                             source: .receipt)
        }, names: [itemID: "Milk"], shops: shops)

        let rows = try parse(text)
        XCTAssertEqual(rows.count, amounts.count + 1)
        for (amount, row) in zip(amounts, rows.dropFirst()) {
            let minor = try XCTUnwrap(Int(row[4]), "amount_minor must parse as a whole number")
            XCTAssertEqual(Money(minorUnits: minor, currencyCode: row[5]), amount)
            XCTAssertEqual(row[6], String(amount.minorUnitExponent))
        }
    }

    // A rendering cannot be added up again: $4.49, 4,49 and ¥500 are all the same lie in a
    // spreadsheet column. The file carries the integer the database carries.
    func testAnAmountIsNeverWrittenAsAFormattedPrice() throws {
        let text = CSVExporter.prices([observation(449), observation(500, currency: "JPY")],
                                      names: [:], shops: shops)

        let rows = try parse(text).dropFirst()
        for row in rows {
            XCTAssertFalse(row[4].contains("."), row[4])
            XCTAssertFalse(row[4].contains("$"), row[4])
            XCTAssertFalse(row[4].contains(","), row[4])
        }
        XCTAssertEqual(rows.map { $0[4] }, ["449", "500"])
        XCTAssertFalse(text.contains("$4.49"))
    }

    // MARK: - Never inventing what was not recorded

    func testAQuantityThatWasNeverRecordedStaysEmpty() throws {
        let text = CSVExporter.prices([observation(449), observation(349, quantity: 4),
                                       observation(299, quantity: 0.5)],
                                      names: [:], shops: shops)

        let quantities = try parse(text).dropFirst().map { $0[7] }
        // The first was written before counts existed; "1" here would be this file claiming
        // something the observation never said.
        XCTAssertEqual(quantities, ["", "4", "0.5"])
    }

    func testATillTotalThatWasNeverReadStaysEmpty() throws {
        let receipts = [Receipt(shopID: shopID, capturedAt: now, lineCount: 14,
                                totalMinor: nil, recordedMinor: 4_211),
                        Receipt(shopID: shopID, capturedAt: now, lineCount: 3,
                                totalMinor: 1_299, recordedMinor: nil)]
        let rows = try parse(CSVExporter.receipts(receipts, shops: shops, currencyCode: "USD"))
            .dropFirst()

        XCTAssertEqual(rows.map { $0[3] }, ["", "1299"])
        XCTAssertEqual(rows.map { $0[4] }, ["4211", ""])
        XCTAssertEqual(rows.map { $0[7] }, ["no", "no"])
    }

    func testAPriceWhoseItemNobodyNamedKeepsItsIdAndAnEmptyName() throws {
        let row = try XCTUnwrap(try parse(CSVExporter.prices([observation(449)], names: [:],
                                                             shops: [:])).last)

        XCTAssertEqual(row[0], itemID.rawValue.uuidString)
        XCTAssertEqual(row[1], "")
        XCTAssertEqual(row[2], "", "an unknown shop is not named after its id either")
    }

    // MARK: - The list

    func testCommasQuotesAndNewlinesInAnItemSurviveTheRoundTrip() throws {
        let item = ListItem(itemID: itemID, name: "Milk, semi-skimmed",
                            quantity: 2, unit: "L", note: "the \"blue\" one\nnot the green",
                            checked: true, shopID: shopID, createdAt: now)

        let row = try XCTUnwrap(try parse(CSVExporter.list([item], shops: shops)).last)
        XCTAssertEqual(row[0], "Milk, semi-skimmed")
        XCTAssertEqual(row[1], "2")
        XCTAssertEqual(row[2], "L")
        XCTAssertEqual(row[3], "the \"blue\" one\nnot the green")
        XCTAssertEqual(row[4], "yes")
        XCTAssertEqual(row[5], "Trader Joe's")
    }

    func testAFractionalQuantityIsExactThousandths() {
        XCTAssertEqual(CSVExporter.quantity(0.5), "0.5")
        XCTAssertEqual(CSVExporter.quantity(4), "4")
        XCTAssertEqual(CSVExporter.quantity(1.25), "1.25")
        XCTAssertEqual(CSVExporter.decimal(milli: 1), "0.001")
        XCTAssertEqual(CSVExporter.decimal(milli: 12_000), "12")
    }

    // MARK: - The three files, off a real database

    func testTheExportIsListPricesAndReceiptsAndNothingElse() throws {
        let repository = try makeRepository()
        try repository.append(.shop(.upsert(Shop(id: shopID, name: "Trader Joe's"))),
                              kitchenID: kitchen.id)
        try repository.append(.add(ListItem(itemID: itemID, name: "Milk", quantity: 2)),
                              kitchenID: kitchen.id)
        try repository.append(.name(itemID, "Milk"), kitchenID: kitchen.id)
        try repository.append(.price(observation(349, quantity: 2)), kitchenID: kitchen.id)
        try repository.saveReceipt(Receipt(shopID: shopID, capturedAt: now, lineCount: 2,
                                           totalMinor: 698, recordedMinor: 698))

        let files = try CSVExporter(repository: repository).files()

        XCTAssertEqual(files.map(\.name),
                       ["bagged-list.csv", "bagged-prices.csv", "bagged-receipts.csv"])
        XCTAssertEqual(try parse(files[0].text).count, 2)
        let price = try XCTUnwrap(try parse(files[1].text).last)
        XCTAssertEqual(price[1], "Milk")
        XCTAssertEqual(price[4], "349")
        XCTAssertEqual(price[7], "2")
        let receipt = try XCTUnwrap(try parse(files[2].text).last)
        XCTAssertEqual(receipt[1], "Trader Joe's")
        XCTAssertEqual(receipt[3], "698")
        XCTAssertEqual(receipt[5], "USD")
    }

    func testWritingLeavesThreeReadableFiles() throws {
        let repository = try makeRepository()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("csv-export-\(UUID().uuidString)", isDirectory: true)

        let urls = try CSVExporter(repository: repository).write(to: directory)

        XCTAssertEqual(urls.count, 3)
        for url in urls {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.isEmpty, "a header is written even with nothing under it")
        }
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> Repository {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("csv-exporter-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        try repository.saveKitchen(kitchen)
        return repository
    }

    /// RFC 4180, only as far as this file goes: enough to prove what the exporter wrote is what
    /// a spreadsheet reads back.
    private func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = text.makeIterator()
        var pending: Character?
        while let character = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"": quoted = true
            case ",": row.append(field); field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default: field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
