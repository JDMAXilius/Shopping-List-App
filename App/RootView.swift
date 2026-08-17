import DesignKit
import SwiftUI

struct RootView: View {
    @Environment(\.listStore) private var listStore
    @Environment(\.priceStore) private var priceStore
    @Environment(\.repository) private var repository
    @Environment(\.kitchenID) private var kitchenID
    @Environment(\.catalog) private var catalog
    @Environment(\.scanBackend) private var scanBackend
    @Environment(\.kitchenStore) private var kitchenStore
    @Environment(\.placeStore) private var placeStore
    @Environment(\.subscriptionStore) private var subscriptionStore
    @Environment(\.syncCoordinator) private var syncCoordinator
    @Environment(\.scenePhase) private var scenePhase
    // DesignKit's Tab, not SwiftUI's iOS 18 TabView `Tab`.
    @State private var tab: DesignKit.Tab = .list
    @State private var sheet: Sheet?
    @State private var listPath = NavigationPath()
    @State private var pricePath = NavigationPath()
    @State private var youPath = NavigationPath()
    /// Lives as long as the capture sheet does (ARCHITECTURE §3), and is built before the sheet
    /// is asked for — a session minted in a body pass would lose a half-checked review.
    @State private var capture: CaptureSession?
    /// The pill's real height: at accessibility sizes it more than doubles, and a fixed
    /// page inset left it sitting on the input bar. Measured, never assumed.
    @State private var pillHeight: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.paper.color.ignoresSafeArea()
            content
            TabPill(selection: $tab, onAdd: { presentCapture() })
                .padding(.bottom, 8)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
                    pillHeight = $0
                }
        }
        .sheet(item: $sheet) { presented in
            sheetContent(presented)
        }
        // The capture sheet is driven by the session itself: presentation and state are one
        // value, so the sheet can never render before the session exists (sheet(item: $sheet)
        // evaluated its content against the pre-tap state and showed the apology instead).
        // Released by the dismissal, not during it: the flow keeps its state to the last frame.
        // A capture that landed wrote prices and a receipt, and the receipt index is not
        // observed — the book re-reads on the way out, not on the next launch.
        .sheet(item: $capture, onDismiss: { priceStore?.refresh() }) { session in
            CaptureChooserSheet(session: session)
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget and App Intents write to the same file while we're backgrounded.
            if phase == .active {
                listStore?.refresh()
                priceStore?.refresh()
                syncCoordinator?.start()
                syncCoordinator?.kick()
            } else {
                syncCoordinator?.stop()
            }
        }
        // An invite is a bearer token: it opens the join sheet and nothing else, and a URL that
        // is not one is ignored rather than guessed at.
        .onOpenURL { url in
            guard KitchenLink.isInvite(url), let token = KitchenLink.token(from: url) else { return }
            sheet = .join(token)
        }
        // The status the list shows is the engine's, not a guess. A queue that has not drained
        // is not "synced", and a phone with no server configured is local, not failing.
        .onChange(of: syncCoordinator?.status) { _, status in
            if let status { listStore?.syncStatus = status }
        }
        // A joiner is never paywalled — sharing is the growth loop and the owner already paid.
        // Bound to the answer rather than set once at launch, because `load()` resolves the
        // identity asynchronously: setting it before the answer arrives is how a guest meets
        // the paywall on their third scan.
        .task { await kitchenStore?.load() }
        .onChange(of: kitchenStore?.isGuest) { _, isGuest in
            guard let isGuest else { return }
            subscriptionStore?.adopt(isGuest ? .guest : .owner)
        }
    }

    /// Nothing to capture into without a database, so the `+` stays quiet rather than opening a
    /// sheet that can only apologise.
    private func presentCapture() {
        guard let listStore, let repository, let kitchenID, let catalog, let scanBackend
        else { return }
        capture = CaptureSession(repository: repository, kitchenID: kitchenID, store: listStore,
                                 catalog: catalog, backend: scanBackend)
    }

    @ViewBuilder private var content: some View {
        if let listStore {
            // A real TabView (ARCHITECTURE §6), system bar hidden because TabPill is the bar:
            // switching tabs must keep each root alive, draft, scroll position and all.
            TabView(selection: $tab) {
                NavigationStack(path: $listPath) {
                    ListScreen(store: listStore, sheet: $sheet)
                        .navigationDestination(for: Route.self) { route in
                            destination(route, store: listStore)
                        }
                }
                .toolbar(.hidden, for: .tabBar)
                // Plain padding on the page, not a safe-area inset on the TabView:
                // TabView hosts pages edge-to-edge and swallows both safeAreaPadding
                // and safeAreaInset (design/app/01-list.png puts the pill BELOW the
                // card, never over it).
                .padding(.bottom, pillHeight)
                .tag(DesignKit.Tab.list)
                pricesRoot
                    .toolbar(.hidden, for: .tabBar)
                    .padding(.bottom, pillHeight)
                    .tag(DesignKit.Tab.prices)
                youRoot(listStore)
                    .toolbar(.hidden, for: .tabBar)
                    .padding(.bottom, pillHeight)
                    .tag(DesignKit.Tab.you)
            }
        } else {
            EmptyState(
                glyph: .other,
                message: "Bagged couldn't open your list on this device. Reopening the app usually fixes it.")
        }
    }

    @ViewBuilder private var pricesRoot: some View {
        if let priceStore {
            NavigationStack(path: $pricePath) {
                PricesScreen(store: priceStore, onCapture: { presentCapture() })
                    .navigationDestination(for: Route.self) { route in
                        priceDestination(route, store: priceStore)
                    }
            }
        } else {
            EmptyState(
                glyph: .other,
                message: "Bagged couldn't open your price book on this device. Reopening the app usually fixes it.")
        }
    }

    /// Tab 3's root is Setup itself, not a push destination — everything else in the tab is
    /// reached from it, so `Route.setup` is never pushed.
    @ViewBuilder private func youRoot(_ listStore: ListStore) -> some View {
        if let subscriptionStore {
            NavigationStack(path: $youPath) {
                SetupScreen(store: listStore, subscription: subscriptionStore, sheet: $sheet,
                            defaults: .appGroup())
                    .navigationDestination(for: Route.self) { route in
                        youDestination(route, store: listStore)
                    }
            }
        } else {
            EmptyState(
                glyph: .other,
                message: "Bagged couldn't open your settings on this device. Reopening the app usually fixes it.")
        }
    }

    @ViewBuilder private func youDestination(_ route: Route, store: ListStore) -> some View {
        switch route {
        case .kitchen:
            if let kitchenStore, let syncCoordinator {
                KitchenScreen(store: kitchenStore, sync: syncCoordinator, sheet: $sheet)
            }
        case .places:
            if let placeStore {
                PlacesScreen(store: store, places: placeStore)
            }
        case .shopEditor(let shopID):
            if let placeStore, let shopID {
                ShopEditorScreen(store: store, places: placeStore, shopID: shopID)
            }
        case .aisleOrder(let shopID):
            AisleOrderEditor(store: store, shopID: shopID)
        case .dataPrivacy:
            DataPrivacyScreen(exporter: repository.map(CSVExporter.init), defaults: .appGroup())
        case .about:
            AboutScreen()
        case .whyItWorksThisWay:
            WhyItWorksThisWay()
        default:
            // Pushed from another tab's stack, or `.setup`, which is this tab's root.
            EmptyView()
        }
    }

    @ViewBuilder private func priceDestination(_ route: Route, store: PriceStore) -> some View {
        switch route {
        case .priceHistory(let itemID):
            PriceHistoryScreen(store: store, itemID: itemID)
        case .monthSpend:
            MonthSpendScreen(store: store)
        default:
            // Every other route is pushed from a stack that later waves own.
            EmptyView()
        }
    }

    @ViewBuilder private func destination(_ route: Route, store: ListStore) -> some View {
        switch route {
        case .aisleOrder(let shopID):
            AisleOrderEditor(store: store, shopID: shopID)
        default:
            // Every other route is pushed from a stack that later waves own.
            EmptyView()
        }
    }

    @ViewBuilder private func sheetContent(_ presented: Sheet) -> some View {
        if let listStore {
            switch presented {
            case .itemDetail(let id):
                ItemDetailSheet(store: listStore, listItemID: id)
            case .shopSwitcher, .firstShop:
                ShopSwitcherSheet(store: listStore)
            case .capture:
                // Unreachable today — capture presents through `.sheet(item: $capture)` —
                // but the case stays total for any later wave that sets it.
                EmptyState(
                    glyph: .other,
                    message: "Capture couldn't start on this device. Reopening the app usually fixes it.")
                    .presentationDetents([.medium])
            case .invite:
                if let kitchenStore { InviteSheet(store: kitchenStore) }
            case .join(let token):
                if let kitchenStore {
                    JoinScreen(store: kitchenStore, link: token, onJoined: { sheet = nil })
                }
            case .paywall:
                if let subscriptionStore { PaywallScreen(store: subscriptionStore) }
            }
        }
    }
}
