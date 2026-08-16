import DesignKit
import SwiftUI

struct RootView: View {
    @Environment(\.listStore) private var listStore
    @Environment(\.scenePhase) private var scenePhase
    // DesignKit's Tab, not SwiftUI's iOS 18 TabView `Tab`.
    @State private var tab: DesignKit.Tab = .list
    @State private var sheet: Sheet?
    @State private var listPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.paper.color.ignoresSafeArea()
            content
                .safeAreaPadding(.bottom, 72)
            TabPill(selection: $tab, onAdd: { sheet = .capture })
                .padding(.bottom, 8)
        }
        .sheet(item: $sheet) { presented in
            sheetContent(presented)
        }
        .onChange(of: scenePhase) { _, phase in
            // The widget and App Intents write to the same file while we're backgrounded.
            if phase == .active { listStore?.refresh() }
        }
    }

    @ViewBuilder private var content: some View {
        if let listStore {
            switch tab {
            case .list:
                NavigationStack(path: $listPath) {
                    ListScreen(store: listStore, sheet: $sheet)
                        .navigationDestination(for: Route.self) { route in
                            destination(route, store: listStore)
                        }
                }
            case .prices:
                // Waves 7 and 9 replace these two roots with their own screens.
                EmptyState(
                    glyph: .other,
                    message: "Your price book fills in as you record what you paid.")
            case .you:
                EmptyState(
                    glyph: .household,
                    message: "Your kitchen, sharing and settings live here.")
            }
        } else {
            EmptyState(
                glyph: .other,
                message: "Bagged couldn't open your list on this device. Reopening the app usually fixes it.")
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
            case .addItem:
                AddItemSheet(store: listStore)
            case .itemDetail(let id):
                ItemDetailSheet(store: listStore, listItemID: id)
            case .shopSwitcher, .firstShop:
                ShopSwitcherSheet(store: listStore)
            case .capture:
                // Wave 6 owns the real chooser; saying so beats a blank sheet or a fake camera.
                EmptyState(glyph: .other, message: "Receipt capture arrives with the camera work.")
                    .presentationDetents([.medium])
            case .invite, .paywall:
                EmptyView()
            }
        }
    }
}
