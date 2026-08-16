import DesignKit
import SwiftUI

struct RootView: View {
    @Environment(\.listStore) private var listStore
    @Environment(\.priceStore) private var priceStore
    @Environment(\.repository) private var repository
    @Environment(\.kitchenID) private var kitchenID
    @Environment(\.catalog) private var catalog
    @Environment(\.scanBackend) private var scanBackend
    @Environment(\.scenePhase) private var scenePhase
    // DesignKit's Tab, not SwiftUI's iOS 18 TabView `Tab`.
    @State private var tab: DesignKit.Tab = .list
    @State private var sheet: Sheet?
    @State private var listPath = NavigationPath()
    @State private var pricePath = NavigationPath()
    /// Lives as long as the capture sheet does (ARCHITECTURE §3), and is built before the sheet
    /// is asked for — a session minted in a body pass would lose a half-checked review.
    @State private var capture: CaptureSession?

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.paper.color.ignoresSafeArea()
            content
            TabPill(selection: $tab, onAdd: { presentCapture() })
                .padding(.bottom, 8)
        }
        // Released after the dismissal, not during it: the flow keeps its state to the last frame.
        // A capture that landed wrote prices and a receipt, and the receipt index is not
        // observed — the book re-reads on the way out, not on the next launch.
        .sheet(item: $sheet, onDismiss: { capture = nil; priceStore?.refresh() }) { presented in
            sheetContent(presented)
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget and App Intents write to the same file while we're backgrounded.
            if phase == .active {
                listStore?.refresh()
                priceStore?.refresh()
            }
        }
    }

    /// Nothing to capture into without a database, so the `+` stays quiet rather than opening a
    /// sheet that can only apologise.
    private func presentCapture() {
        guard let listStore, let repository, let kitchenID, let catalog, let scanBackend
        else { return }
        capture = CaptureSession(repository: repository, kitchenID: kitchenID, store: listStore,
                                 catalog: catalog, backend: scanBackend)
        sheet = .capture
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
                .padding(.bottom, 72)
                .tag(DesignKit.Tab.list)
                pricesRoot
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 72)
                    .tag(DesignKit.Tab.prices)
                // Wave 9 replaces this root with its own screens.
                EmptyState(
                    glyph: .household,
                    message: "Your kitchen, sharing and settings live here.")
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaPadding(.bottom, 72)
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
                if let capture {
                    CaptureChooserSheet(session: capture)
                } else {
                    EmptyState(
                        glyph: .other,
                        message: "Capture couldn't start on this device. Reopening the app usually fixes it.")
                        .presentationDetents([.medium])
                }
            // Neither screen exists yet (wave 9), and a sheet the user can only escape by
            // guessing is worse than one that says so.
            case .invite:
                EmptyState(
                    glyph: .household,
                    message: "Sharing your kitchen arrives with accounts and invites.")
                    .presentationDetents([.medium])
            case .paywall:
                EmptyState(
                    glyph: .other,
                    message: "Bagged Plus isn't on sale yet. Everything you already have keeps working.")
                    .presentationDetents([.medium])
            }
        }
    }
}
