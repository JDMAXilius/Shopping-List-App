import Catalog
import Core
import Data
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class PlaceStoreTests: XCTestCase {
    private let kitchenID = KitchenID()
    private let latitude = 40.712776
    private let longitude = -74.005974

    // MARK: - Harness

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("places-\(UUID().uuidString)", isDirectory: true)
    }

    /// Every test runs with no CoreLocation behind the service, which is the same state as a
    /// phone that refused permission — and the only state a machine with no simulator has.
    private func makeStore(_ directory: URL) -> PlaceStore {
        PlaceStore(location: LocationService(manager: nil), directory: directory)
    }

    private func fix(_ latitude: Double? = nil, _ longitude: Double? = nil,
                     at date: Date = Date()) -> LocationService.Fix {
        LocationService.Fix(latitude: latitude ?? self.latitude,
                            longitude: longitude ?? self.longitude, accuracy: 12, takenAt: date)
    }

    private func place(_ recency: Date, wake: Bool = true,
                       shopID: ShopID = ShopID()) -> Place {
        Place(shopID: shopID, latitude: latitude, longitude: longitude, accuracy: 12,
              pinnedAt: recency, radius: Place.defaultRadius, wakeEnabled: wake)
    }

    // MARK: - A pin is never an op

    func testPinningAShopWritesNothingToTheOpLog() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("places-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: databaseURL)
        try database.migrate()
        let repository = try Repository(database: database)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        let list = try ListStore(repository: repository, kitchenID: kitchenID,
                                 catalog: ListCatalog(database: try CatalogDatabase.bundled()),
                                 defaults: defaults)
        let shopID = try XCTUnwrap(list.createShop(named: "Trader Joe's"))
        let opsAfterTheShop = try repository.unpushedOps().count

        let places = makeStore(makeDirectory())
        places.setPin(fix(), for: shopID)
        places.setRadius(300, for: shopID)
        places.setWake(true, for: shopID)

        // Ops are the whole sync protocol (ARCHITECTURE §5). Not appending one IS the promise.
        XCTAssertEqual(try repository.unpushedOps().count, opsAfterTheShop,
                       "a pin, a radius and a wake-up switch produced an op")
        // The shop syncs and carries nothing about the pin. Since v7 that is structural —
        // `Shop` has no geofence fields at all and the columns are gone (MigrationTests
        // .testTheGeofenceColumnsAreGoneInV7) — so what is left to assert is that the shop
        // itself round-trips unchanged through a pin, a radius and a wake-up switch.
        let shop = try XCTUnwrap(repository.shops().first { $0.id == shopID })
        XCTAssertEqual(shop.name, "Trader Joe's")
        XCTAssertNil(shop.branch)
    }

    func testTheCoordinateIsInTheLocalFileAndNowhereNearTheDatabase() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("places-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: databaseURL)
        try database.migrate()
        let repository = try Repository(database: database)
        let shop = Shop(name: "Trader Joe's")
        try repository.append(.shop(.upsert(shop)), kitchenID: kitchenID)

        let directory = makeDirectory()
        let places = makeStore(directory)
        places.setPin(fix(), for: shop.id)

        // The control: the search below can find a coordinate when there is one to find.
        let written = try XCTUnwrap(String(data: try Foundation.Data(contentsOf: places.file),
                                           encoding: .utf8))
        XCTAssertTrue(written.contains("40.712776"))

        // Op payloads are JSON text, so a leaked coordinate would be readable in these bytes.
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: databaseURL.path + suffix)
            guard let bytes = try? Foundation.Data(contentsOf: url) else { continue }
            let text = String(decoding: bytes, as: UTF8.self)
            XCTAssertFalse(text.contains("40.712776"), "a coordinate reached \(url.lastPathComponent)")
            XCTAssertFalse(text.contains("-74.005974"))
            XCTAssertFalse(text.contains("latitude"))
        }
    }

    func testThePinFileLivesOutsideTheAppGroupTheWidgetAndIntentsRead() throws {
        let places = PlaceStore(location: LocationService(manager: nil))
        places.setPin(fix(), for: ShopID())

        // The group container is the surface the widget and the App Intents read. The pin file
        // is not in it, and the database it holds is the only thing the transport ever sees.
        XCTAssertFalse(places.file.path.contains("group.app.bagged"))
        if let container = AppGroup.containerURL() {
            XCTAssertFalse(places.file.path.hasPrefix(container.path))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: places.file.path))
    }

    // MARK: - The 20-region cap, decided the same way every time

    func testOnlyTwentyPlacesAreWatchedAndTheyAreTheMostRecentOnes() {
        let now = Date()
        let places = (0..<30).map { place(now.addingTimeInterval(Double(-$0) * 3600)) }

        let monitored = Place.monitored(places)

        XCTAssertEqual(monitored.count, LocationService.fenceLimit)
        XCTAssertEqual(monitored.map(\.recency), places.prefix(20).map(\.recency))
    }

    func testTheChoiceDoesNotDependOnTheOrderItIsAskedIn() {
        let now = Date()
        let places = (0..<30).map { place(now.addingTimeInterval(Double(-$0) * 3600)) }

        let first = Place.monitored(places).map(\.shopID)
        let second = Place.monitored(places.shuffled()).map(\.shopID)
        let third = Place.monitored(places.reversed()).map(\.shopID)

        XCTAssertEqual(first, second, "a relaunch must watch the same twenty")
        XCTAssertEqual(first, third)
    }

    func testPlacesPinnedInTheSameInstantAreSeparatedByIdNotByLuck() {
        let instant = Date()
        let places = (0..<25).map { _ in place(instant) }

        let chosen = Place.monitored(places).map(\.shopID.rawValue.uuidString)

        XCTAssertEqual(chosen, chosen.sorted(), "the tiebreak is the id, ascending")
        XCTAssertEqual(Set(chosen).count, 20)
    }

    func testAnArrivalPromotesAShopIntoTheWatchedTwenty() {
        let now = Date()
        var old = place(now.addingTimeInterval(-90 * 24 * 3600))
        let recent = (0..<20).map { place(now.addingTimeInterval(Double(-$0) * 60)) }
        XCTAssertFalse(Place.monitored([old] + recent).contains(old))

        old.lastArrival = now
        XCTAssertTrue(Place.monitored([old] + recent).contains(old),
                      "the shop you were in yesterday outranks one pinned and never visited")
    }

    func testAPlaceWithWakeOffIsNeverWatched() {
        let off = place(Date(), wake: false)
        let on = place(Date().addingTimeInterval(-3600))

        XCTAssertEqual(Place.monitored([off, on]).map(\.shopID), [on.shopID])
    }

    func testTheWaitingCountSaysHowManyPinsIosHasNoRoomFor() {
        let places = makeStore(makeDirectory())
        let now = Date()
        for index in 0..<23 {
            let shopID = ShopID()
            places.setPin(fix(at: now.addingTimeInterval(Double(-index))), for: shopID)
        }

        XCTAssertEqual(places.monitored.count, 20)
        XCTAssertEqual(places.waiting, 3)
    }

    // MARK: - A refusal leaves every screen usable

    func testWithLocationRefusedNothingIsPinnedAndNothingBreaks() async {
        let directory = makeDirectory()
        let places = makeStore(directory)
        let shopID = ShopID()

        XCTAssertEqual(places.permission, .denied)
        XCTAssertFalse(places.canPin)
        let pinned = await places.pinHere(shopID)

        XCTAssertFalse(pinned, "no fix, so no pin — and the screen says so rather than guessing")
        XCTAssertNil(places.place(shopID))
        XCTAssertTrue(places.monitored.isEmpty)
        XCTAssertEqual(places.waiting, 0)
        // The rest of the screen still works on a phone that said no.
        places.requestPermission()
        places.setRadius(300, for: shopID)
        places.setWake(true, for: shopID)
        places.removePin(shopID)
        places.prune(to: [])
        XCTAssertTrue(places.places.isEmpty)
    }

    func testPinsMadeBeforeARefusalAreStillReadable() {
        let directory = makeDirectory()
        let shopID = ShopID()
        let first = makeStore(directory)
        first.setPin(fix(), for: shopID)

        let second = makeStore(directory)

        XCTAssertEqual(second.place(shopID)?.radius, Place.defaultRadius)
        XCTAssertEqual(second.place(shopID)?.wakeEnabled, true)
        XCTAssertEqual(second.permission, .denied)
    }

    // MARK: - Radius, arrivals and tidying up

    func testTheRadiusIsHeldInsideTheRangeAGeofenceCanActuallyKeep() {
        let places = makeStore(makeDirectory())
        let shopID = ShopID()
        places.setPin(fix(), for: shopID)

        places.setRadius(10, for: shopID)
        XCTAssertEqual(places.place(shopID)?.radius, Place.radiusRange.lowerBound)
        places.setRadius(5000, for: shopID)
        XCTAssertEqual(places.place(shopID)?.radius, Place.radiusRange.upperBound)
    }

    func testARadiusForAShopWithNoPinIsNotAPin() {
        let places = makeStore(makeDirectory())
        let shopID = ShopID()

        places.setRadius(300, for: shopID)
        places.setWake(true, for: shopID)

        XCTAssertNil(places.place(shopID))
    }

    func testArrivingSwitchesTheListOnceAndNotAgainOnTheDoorstepWobble() {
        let places = makeStore(makeDirectory())
        let shopID = ShopID()
        places.setPin(fix(), for: shopID)
        var arrivals: [ShopID] = []
        places.onArrival = { arrivals.append($0) }

        places.location.onArrival?(shopID.rawValue.uuidString)
        places.location.onArrival?(shopID.rawValue.uuidString)

        XCTAssertEqual(arrivals, [shopID])
        XCTAssertNotNil(places.place(shopID)?.lastArrival)
    }

    func testAnArrivalAtAShopWithWakeOffIsIgnored() {
        let places = makeStore(makeDirectory())
        let shopID = ShopID()
        places.setPin(fix(), for: shopID)
        places.setWake(false, for: shopID)
        var arrivals: [ShopID] = []
        places.onArrival = { arrivals.append($0) }

        places.location.onArrival?(shopID.rawValue.uuidString)
        places.location.onArrival?("not-a-uuid")

        XCTAssertTrue(arrivals.isEmpty)
    }

    func testAShopDeletedSomewhereElseTakesItsPinWithIt() {
        let places = makeStore(makeDirectory())
        let kept = ShopID()
        let gone = ShopID()
        places.setPin(fix(), for: kept)
        places.setPin(fix(), for: gone)

        places.prune(to: [kept])

        XCTAssertNotNil(places.place(kept))
        XCTAssertNil(places.place(gone))
    }
}
