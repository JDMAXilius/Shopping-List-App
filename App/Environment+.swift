import Core
import Data
import SwiftUI

// Nil only when the database could not be opened — RootView renders that failure honestly
// instead of force-unwrapping. PriceStore and SubscriptionStore land with waves 7 and 9.
extension EnvironmentValues {
    @Entry var listStore: ListStore?
    // What a per-flow store is built from (ARCHITECTURE §3): CaptureSession needs these, and
    // widening ListStore to hand them over would make it the DI container §6 refuses.
    @Entry var repository: Repository?
    @Entry var kitchenID: KitchenID?
    @Entry var catalog: ListCatalog?
    @Entry var scanBackend: (any ScanBackend)?
}
