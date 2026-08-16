import SwiftUI

// Nil only when the database could not be opened — RootView renders that failure honestly
// instead of force-unwrapping. PriceStore and SubscriptionStore land with waves 7 and 9.
extension EnvironmentValues {
    @Entry var listStore: ListStore?
}
