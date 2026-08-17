import Foundation
import XCTest
import Core

final class PriceObservationTests: XCTestCase {
    private let item = ItemID(UUID(uuidString: "1D9E7A70-0000-4000-8000-00000000000A")!)
    private let shop = ShopID(UUID(uuidString: "1D9E7A70-0000-4000-8000-00000000000B")!)
    private let date = Date(timeIntervalSince1970: 1_755_300_000)

    // Data's OpCoding shape, mirrored: the payload on disk stores its date as integer
    // milliseconds, so these fixtures are the bytes a `.price` op really holds.
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Int64((date.timeIntervalSince1970 * 1000).rounded()))
        }
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let milliseconds = try decoder.singleValueContainer().decode(Int64.self)
            return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
        }
        return decoder
    }

    private func observation(quantity: Double?) -> PriceObservation {
        PriceObservation(itemID: item, shopID: shop, date: date,
                         amount: Money(minorUnits: 350), source: .receipt, quantity: quantity)
    }

    /// The payload of every `.price` op written before this field existed, byte for byte.
    private let oldShape = """
        {"amount":{"currencyCode":"USD","minorUnits":350},"date":1755300000000,\
        "itemID":"1D9E7A70-0000-4000-8000-00000000000A",\
        "shopID":"1D9E7A70-0000-4000-8000-00000000000B","source":"receipt"}
        """

    // RULING 2: an op already in a log must decode, and must go on meaning exactly one unit.
    func testAPayloadWrittenBeforeQuantitiesDecodesAndStillMeansOne() throws {
        let decoded = try decoder().decode(PriceObservation.self,
                                           from: Foundation.Data(oldShape.utf8))
        XCTAssertEqual(decoded.amount, Money(minorUnits: 350))
        XCTAssertEqual(decoded.quantity, 1, "an observation with no count is worth one unit")
        XCTAssertNil(decoded.quantityMilli)
        XCTAssertFalse(decoded.hasRecordedQuantity,
                       "counted-as-one and recorded-as-one are different claims")
    }

    /// The other half of the same rule: an observation with no count writes the OLD shape back,
    /// with no key invented. Nothing already stored needs rewriting, in either direction.
    func testAnObservationWithNoCountEncodesToExactlyTheOldShape() throws {
        let written = try encoder().encode(observation(quantity: nil))
        XCTAssertEqual(String(decoding: written, as: UTF8.self), oldShape)
    }

    func testACountRoundTripsThroughThePayloadExactly() throws {
        for quantity in [4.0, 1.0, 0.5, 1.5, 2.75, 0.333, 999.0] {
            let written = try encoder().encode(observation(quantity: quantity))
            let back = try decoder().decode(PriceObservation.self, from: written)
            XCTAssertEqual(back.quantity, quantity, "\(quantity) did not survive the op log")
            XCTAssertTrue(back.hasRecordedQuantity)
            XCTAssertEqual(back.amount, Money(minorUnits: 350), "the price of ONE is untouched")
        }
    }

    /// Thousandths, not a Double: 0.1 + 0.2 has no place in something a total is built from.
    func testTheCountIsStoredAsAnExactInteger() {
        XCTAssertEqual(observation(quantity: 4).quantityMilli, 4_000)
        XCTAssertEqual(observation(quantity: 0.5).quantityMilli, 500)
        XCTAssertEqual(observation(quantity: 0.333).quantityMilli, 333)
        let written = try? encoder().encode(observation(quantity: 4))
        XCTAssertTrue(String(decoding: written ?? Foundation.Data(), as: UTF8.self)
            .contains("\"quantityMilli\":4000"), "an integer on the wire, never 4.0000001")
    }

    /// A number that is not a count is recorded as none — never as one, which would be a claim
    /// somebody made, and never as itself, which would multiply a total by nonsense.
    func testWhatIsNotACountIsRecordedAsNoCount() {
        let notCounts: [Double] = [0, -1, 2_000_000, .nan, .infinity]
        for bad in notCounts {
            let made = observation(quantity: bad)
            XCTAssertNil(made.quantityMilli, "\(bad) is not a count")
            XCTAssertFalse(made.hasRecordedQuantity)
            XCTAssertEqual(made.quantity, 1)
        }
        // And it encodes as the old shape: JSON cannot carry a NaN, so an op that tried would
        // throw on the way out and the price would simply never be written.
        let written = try? encoder().encode(observation(quantity: Double.nan))
        XCTAssertEqual(String(decoding: written ?? Foundation.Data(), as: UTF8.self), oldShape)
    }

    /// Adding the field changed no existing key. A rename here orphans every op ever written.
    func testThePayloadKeysAreTheOnesAlreadyOnDisk() throws {
        let written = try encoder().encode(observation(quantity: 4))
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: written) as? [String: Any])
        XCTAssertEqual(Set(object.keys),
                       ["itemID", "shopID", "date", "amount", "source", "quantityMilli"])
    }

    /// The count says nothing about how fresh the price is — the two decay rules stay separate.
    func testACountDoesNotTouchConfidence() {
        let now = Date()
        let old = PriceObservation(itemID: item, shopID: shop,
                                   date: now.addingTimeInterval(-120 * 86_400),
                                   amount: Money(minorUnits: 350), source: .receipt, quantity: 4)
        XCTAssertEqual(old.confidence(asOf: now), .estimate)
    }
}
