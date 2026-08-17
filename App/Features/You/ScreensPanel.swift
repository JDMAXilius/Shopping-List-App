import Core
import Data
import DesignKit
import Foundation
import SwiftUI

/// Testing scaffolding, and temporary on purpose: one list that opens a screen directly, because
/// a few of them cost a real receipt or a real invite to reach by hand. It owns no `Route` and no
/// `Sheet` case, so removing it is deleting this file and the one `ScreensPanelRow()` in
/// `AboutScreen`.
struct ScreensPanel: View {
    @Environment(\.listStore) private var listStore
    @Environment(\.priceStore) private var priceStore
    @Environment(\.kitchenStore) private var kitchenStore
    @Environment(\.placeStore) private var placeStore
    @Environment(\.subscriptionStore) private var subscriptionStore
    @Environment(\.syncCoordinator) private var syncCoordinator
    @Environment(\.repository) private var repository
    @Environment(\.kitchenID) private var kitchenID
    @Environment(\.catalog) private var catalog
    @Environment(\.scanBackend) private var scanBackend
    @State private var path: [Destination] = []
    @State private var presented: Destination?
    /// Built on the tap, never in a body pass, for the reason `RootView` builds it that way.
    @State private var capture: CaptureSession?
    @State private var captureEntry: CaptureScreen = .chooser
    @State private var capturePath: [CaptureRoute] = []

    static let explanation = "This opens screens directly so they can be tested. Some will look "
        + "empty because nothing has been added yet. It is not part of the app."

    var body: some View {
        if let listStore, let subscriptionStore {
            panel(listStore, subscriptionStore)
        } else {
            EmptyState(glyph: .other,
                       message: "Bagged couldn't open your list on this device, so these screens "
                           + "have nothing to show.")
        }
    }

    private func panel(_ list: ListStore, _ subscription: SubscriptionStore) -> some View {
        NavigationStack(path: $path) {
            content(list)
                .navigationDestination(for: Destination.self) { view($0, list, subscription) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $presented) { view($0, list, subscription) }
        .sheet(item: $capture) { captureView($0) }
    }

    private func content(_ list: ListStore) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                paragraph(Self.explanation)
                ForEach(Self.groups(availability(list))) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(group.title)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(group.rows) { row($0, list) }
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Palette.card.color))
                    }
                }
                paragraph("The list and prices tabs aren't in this list: the tab bar opens them.")
            }
            .padding(20)
        }
        .background(Palette.paper.color)
        .navigationTitle("Screens")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Typography.footnote)
            .foregroundStyle(Palette.muted.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Rows

    @ViewBuilder private func row(_ row: Row, _ list: ListStore) -> some View {
        switch row.opening {
        case .opens(let destination):
            Button { open(destination, list) } label: {
                label(row.title, [row.note].compactMap { $0 }, opens: true)
            }
            .buttonStyle(.plain)
        case .cannot(let reason):
            label(row.title, [row.note, reason].compactMap { $0 }, opens: false)
        }
    }

    private func label(_ title: String, _ notes: [String], opens: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle((opens ? Palette.ink : Palette.muted).color)
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if opens {
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func open(_ destination: Destination, _ list: ListStore) {
        if case .capture(let screen) = destination {
            start(screen, list)
        } else if destination.isSheet {
            presented = destination
        } else {
            path.append(destination)
        }
    }

    // MARK: - What this device can hand a screen

    private func availability(_ list: ListStore) -> Availability {
        Availability(listRow: list.rows.first?.id,
                     shop: list.activeShopID ?? list.shops.first?.id,
                     item: priceStore?.recent.first?.itemID
                         ?? list.rows.compactMap(\.item.itemID).first,
                     prices: priceStore != nil,
                     places: placeStore != nil,
                     kitchen: kitchenStore != nil,
                     sync: syncCoordinator != nil,
                     capture: repository != nil && kitchenID != nil && catalog != nil
                         && scanBackend != nil)
    }

    // MARK: - The screens

    @ViewBuilder private func view(_ destination: Destination, _ list: ListStore,
                                  _ subscription: SubscriptionStore) -> some View {
        switch destination {
        case .itemDetail(let listItemID):
            ItemDetailSheet(store: list, listItemID: listItemID)
        case .shopSwitcher:
            ShopSwitcherSheet(store: list, subscription: subscription)
        case .firstShop:
            if let placeStore {
                FirstShopSheet(store: list, places: placeStore)
            } else {
                missing("your shops")
            }
        case .aisleOrder(let shopID):
            AisleOrderEditor(store: list, shopID: shopID)
        case .monthSpend:
            if let priceStore {
                MonthSpendScreen(store: priceStore)
            } else {
                missing("your price book")
            }
        case .priceHistory(let itemID):
            if let priceStore {
                PriceHistoryScreen(store: priceStore, itemID: itemID, subscription: subscription,
                                   sheet: .constant(nil))
            } else {
                missing("your price book")
            }
        case .setup:
            SetupScreen(store: list, subscription: subscription, sheet: .constant(nil),
                        defaults: .appGroup())
        case .kitchen:
            if let kitchenStore, let syncCoordinator {
                KitchenScreen(store: kitchenStore, sync: syncCoordinator, sheet: .constant(nil))
            } else {
                missing("your kitchen")
            }
        case .signIn:
            if let kitchenStore {
                SignInScreen(store: kitchenStore)
            } else {
                missing("your kitchen")
            }
        case .nameKitchen:
            if let kitchenStore {
                NameKitchenSheet(store: kitchenStore)
            } else {
                missing("your kitchen")
            }
        case .invite:
            if let kitchenStore {
                InviteSheet(store: kitchenStore)
            } else {
                missing("your kitchen")
            }
        case .join:
            if let kitchenStore {
                JoinScreen(store: kitchenStore)
            } else {
                missing("your kitchen")
            }
        case .places:
            if let placeStore {
                PlacesScreen(store: list, places: placeStore, subscription: subscription)
            } else {
                missing("your shops")
            }
        case .shopEditor(let shopID):
            if let placeStore {
                ShopEditorScreen(store: list, places: placeStore, shopID: shopID)
            } else {
                missing("your shops")
            }
        case .paywall:
            PaywallScreen(store: subscription)
        case .dataPrivacy:
            DataPrivacyScreen(exporter: repository.map(CSVExporter.init), defaults: .appGroup())
        case .about:
            AboutScreen()
        case .whyItWorksThisWay:
            WhyItWorksThisWay()
        case .capture:
            // Opened through `start(_:_:)`, which needs the session that only a tap can mint.
            EmptyView()
        }
    }

    private func missing(_ what: String) -> some View {
        EmptyState(glyph: .other, message: "Bagged couldn't open \(what) on this device.")
    }

    /// The reader's answer reaches the app-lifetime store here exactly as it does in `RootView`:
    /// a scan spent from this panel is a scan spent.
    private func start(_ screen: CaptureScreen, _ list: ListStore) {
        guard let repository, let kitchenID, let catalog, let scanBackend else { return }
        capturePath = []
        captureEntry = screen
        capture = CaptureSession(repository: repository, kitchenID: kitchenID, store: list,
                                 catalog: catalog, backend: scanBackend,
                                 onOutcome: { [subscriptionStore] outcome in
                                     subscriptionStore?.record(outcome)
                                 })
    }

    @ViewBuilder private func captureView(_ session: CaptureSession) -> some View {
        switch captureEntry {
        case .chooser:
            CaptureChooserSheet(session: session)
        case .barcode:
            // Barcode's one push is "enter by hand"; nothing else in the flow is reachable here.
            NavigationStack(path: $capturePath) {
                BarcodeScanScreen(session: session, path: $capturePath)
                    .navigationDestination(for: CaptureRoute.self) { route in
                        if route == .byHand {
                            EnterByHandScreen(session: session)
                        } else {
                            EmptyState(glyph: .other,
                                       message: "Only entering by hand is reachable from the "
                                           + "barcode screen. Open the rest from the panel.")
                        }
                    }
            }
        case .byHand:
            NavigationStack { EnterByHandScreen(session: session) }
        }
    }
}

// MARK: - The list, as a function of facts

extension ScreensPanel {

    /// Everything the rows depend on, reduced to facts — so the list is pure, and testable
    /// without a database.
    struct Availability {
        var listRow: ListItemID?
        var shop: ShopID?
        var item: ItemID?
        var prices = false
        var places = false
        var kitchen = false
        var sync = false
        var capture = false
    }

    enum Opening {
        case opens(Destination)
        /// Why not, in one sentence. A row that cannot open says this instead of doing nothing.
        case cannot(String)
    }

    struct Row: Identifiable {
        let title: String
        let opening: Opening
        /// Why the screen is hard to reach by hand, or what the panel cannot do for it.
        let note: String?

        var id: String { title }

        init(_ title: String, _ opening: Opening, note: String? = nil) {
            self.title = title
            self.opening = opening
            self.note = note
        }
    }

    struct RowGroup: Identifiable {
        let title: String
        let rows: [Row]

        var id: String { title }
    }

    static func groups(_ have: Availability) -> [RowGroup] {
        [
            RowGroup(title: "List", rows: listRows(have)),
            RowGroup(title: "Prices", rows: priceRows(have)),
            RowGroup(title: "You", rows: youRows(have)),
            RowGroup(title: "Add prices", rows: captureRows(have)),
        ]
    }

    private static let noShops = "Bagged couldn't open your shops on this device."
    private static let noKitchen = "Bagged couldn't open your kitchen on this device."
    private static let noPrices = "Bagged couldn't open your price book on this device."

    private static func listRows(_ have: Availability) -> [Row] {
        [
            Row("Item detail", have.listRow.map { Opening.opens(.itemDetail($0)) }
                ?? .cannot("Put something on the list first: this sheet is about one row.")),
            Row("Shop switcher", .opens(.shopSwitcher)),
            Row("First shop", have.places ? .opens(.firstShop) : .cannot(noShops),
                note: "Nothing in the app opens this one — the shop switcher is shown instead."),
            Row("Aisle order", have.shop.map { Opening.opens(.aisleOrder($0)) }
                ?? .cannot("Add a shop first: this screen orders one shop's aisles.")),
        ]
    }

    private static func priceRows(_ have: Availability) -> [Row] {
        var history = Opening.cannot(noPrices)
        if have.prices {
            history = have.item.map { Opening.opens(.priceHistory($0)) }
                ?? .cannot("Nothing named yet: add an item or record a price first.")
        }
        return [
            Row("Month spend", have.prices ? .opens(.monthSpend) : .cannot(noPrices)),
            Row("Price history", history),
        ]
    }

    private static func youRows(_ have: Availability) -> [Row] {
        var editor = Opening.cannot(noShops)
        if have.places {
            editor = have.shop.map { Opening.opens(.shopEditor($0)) }
                ?? .cannot("Add a shop first: this screen edits one.")
        }
        return [
            Row("You", .opens(.setup),
                note: "The tab itself. Rows in it that open a sheet do nothing from here; open "
                    + "that sheet from this panel."),
            Row("Kitchen", have.kitchen && have.sync
                ? .opens(.kitchen)
                : .cannot("This build has no server configured, so there is no sync status for "
                    + "this screen to report.")),
            Row("Sign in", have.kitchen ? .opens(.signIn) : .cannot(noKitchen)),
            Row("Name kitchen", have.kitchen ? .opens(.nameKitchen) : .cannot(noKitchen)),
            Row("Invite", have.kitchen ? .opens(.invite) : .cannot(noKitchen)),
            Row("Join a kitchen", have.kitchen ? .opens(.join) : .cannot(noKitchen),
                note: "Needs a live invite token. A link can't reach the app yet — there is no "
                    + "associated domain — so this is the paste field."),
            Row("Places", have.places ? .opens(.places) : .cannot(noShops)),
            Row("Shop editor", editor),
            Row("Bagged Plus", .opens(.paywall),
                note: "In the app this is reached by spending all three free scans."),
            Row("Data & privacy", .opens(.dataPrivacy)),
            Row("About", .opens(.about)),
            Row("Why it works this way", .opens(.whyItWorksThisWay)),
        ]
    }

    private static func captureRows(_ have: Availability) -> [Row] {
        let noCapture = "Bagged couldn't open the database, so a capture can't start."
        return [
            Row("Add prices", have.capture ? .opens(.capture(.chooser)) : .cannot(noCapture),
                note: "The receipt camera is inside this one: opened on its own it would spend a "
                    + "scan and lose the review it lands on."),
            Row("Barcode scan", have.capture ? .opens(.capture(.barcode)) : .cannot(noCapture),
                note: "Needs a camera; without one it shows the app's own primer."),
            Row("Enter by hand", have.capture ? .opens(.capture(.byHand)) : .cannot(noCapture)),
            Row("Receipt review",
                .cannot("A made-up one would put invented prices in your book, so the panel "
                    + "doesn't open it."),
                note: "Needs a receipt a real scan has just parsed."),
            Row("Line resolver",
                .cannot("Needs one line of a parsed receipt, and only a real scan makes one.")),
            Row("Receipt saved",
                .cannot("Needs a receipt saved a moment ago; nothing else puts the flow in that "
                    + "state.")),
            Row("First receipt",
                .cannot("It marks itself seen as it closes, so opening it here would spend the "
                    + "real one."),
                note: "Shows once, ever, after a first receipt."),
        ]
    }
}

// MARK: - Where a row goes

extension ScreensPanel {

    enum CaptureScreen: Hashable {
        case chooser
        case barcode
        case byHand
    }

    /// The panel's own destinations. Deliberately not `Route` or `Sheet`: a temporary panel that
    /// needed a case in either of those would have stopped being temporary.
    enum Destination: Hashable, Identifiable {
        case itemDetail(ListItemID)
        case shopSwitcher
        case firstShop
        case aisleOrder(ShopID)
        case monthSpend
        case priceHistory(ItemID)
        case setup
        case kitchen
        case signIn
        case nameKitchen
        case invite
        case join
        case places
        case shopEditor(ShopID)
        case paywall
        case dataPrivacy
        case about
        case whyItWorksThisWay
        case capture(CaptureScreen)

        var id: Self { self }

        /// Presented the way the app presents it, so what a tester sees is what ships.
        var isSheet: Bool {
            switch self {
            case .itemDetail, .shopSwitcher, .firstShop, .signIn, .nameKitchen, .invite, .join,
                 .paywall, .capture:
                return true
            case .aisleOrder, .monthSpend, .priceHistory, .setup, .kitchen, .places, .shopEditor,
                 .dataPrivacy, .about, .whyItWorksThisWay:
                return false
            }
        }
    }
}

// MARK: - Which builds carry it

extension ScreensPanel {

    /// The one build test. `#if DEBUG` alone would hide the panel from TestFlight — a Release
    /// build — which is the one place a tester needs it; a TestFlight install carries a sandbox
    /// receipt and an App Store install carries a real one.
    static var isAllowedInThisBuild: Bool {
        isAllowed(receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent,
                  isDebugBuild: isDebugBuild)
    }

    // No receipt at all is treated as the App Store: absent is never a licence to show this.
    static func isAllowed(receiptName: String?, isDebugBuild: Bool) -> Bool {
        isDebugBuild || receiptName == "sandboxReceipt"
    }

    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

/// The one row that opens the panel, and the whole of its presentation. Deleting this file and
/// the `ScreensPanelRow()` line in `AboutScreen` removes the panel entirely.
struct ScreensPanelRow: View {
    @State private var isOpen = false

    var body: some View {
        if ScreensPanel.isAllowedInThisBuild {
            Button { isOpen = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open a screen directly")
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink.color)
                        Text("For testing. Not part of the app.")
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Palette.muted.color)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.card.color))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isOpen) { ScreensPanel() }
        }
    }
}
