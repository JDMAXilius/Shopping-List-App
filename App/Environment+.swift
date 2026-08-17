import Core
import Data
import SwiftUI

// Nil only when the database could not be opened — RootView renders that failure honestly
// instead of force-unwrapping.
extension EnvironmentValues {
    @Entry var listStore: ListStore?
    @Entry var priceStore: PriceStore?
    @Entry var kitchenStore: KitchenStore?
    @Entry var placeStore: PlaceStore?
    @Entry var subscriptionStore: SubscriptionStore?
    /// Nil when this build has no `SupabaseURL`, which is every build until a project exists.
    /// The app is local-first, so that is a normal state and not a failure to render.
    @Entry var syncCoordinator: SyncCoordinator?
    // What a per-flow store is built from (ARCHITECTURE §3): CaptureSession needs these, and
    // widening ListStore to hand them over would make it the DI container §6 refuses.
    @Entry var repository: Repository?
    @Entry var kitchenID: KitchenID?
    @Entry var catalog: ListCatalog?
    @Entry var scanBackend: (any ScanBackend)?
}
