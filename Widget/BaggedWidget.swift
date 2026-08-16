import SwiftUI
import WidgetKit

@main
struct BaggedWidgetBundle: WidgetBundle {
    var body: some Widget {
        ListWidget()
    }
}

/// One widget, two families: the lock-screen line and the small home-screen tile
/// (design/app/28-widget.png). Nothing configurable, so nothing to configure.
struct ListWidget: Widget {
    static let kind = "app.bagged.list"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ListWidget.kind, provider: WidgetProvider()) { entry in
            ListWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly shop")
        .description("What's left to get, and a tick to check it off.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
