import DesignKit
import SwiftUI

/// Where the capture flow can be. The two the next packet owns are wired here and land on a
/// screen that names what is coming — never a live-looking button that does nothing.
enum CaptureRoute: Hashable {
    case camera
    case review
    case resolver(CaptureLine.ID)
    case result
    case barcode
    case byHand
}

/// Sheet 20. The three ways a price gets into Bagged.
struct CaptureChooserSheet: View {
    let session: CaptureSession

    @State private var path: [CaptureRoute] = []
    @State private var showsFirstReceipt = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            chooser
                .navigationDestination(for: CaptureRoute.self) { route in
                    destination(route)
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // One screen at a time, decided by the flow's own stage: a saved receipt can never
        // leave a stale review behind it in the stack.
        .onChange(of: session.stage) { _, stage in
            switch stage {
            case .review: path = [.review]
            case .committed:
                path = [.result]
                // The flow's stage changes here and nowhere else, so this is the one place that
                // knows a receipt just became prices.
                showsFirstReceipt = FirstReceiptSheet.shouldShow(session.result)
            case .idle where path == [.review]: path = []
            default: break
            }
        }
        .sheet(isPresented: $showsFirstReceipt) {
            if let result = session.result {
                FirstReceiptSheet(result: result, shopName: session.shopName) {
                    showsFirstReceipt = false
                }
            }
        }
    }

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add prices")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink.color)
                waitingRow
                option("Scan a receipt", "Every line at once, in about six seconds.", .camera)
                option("Scan a barcode", "One item, straight off the packet.", .barcode)
                option("Enter by hand", "No camera, no signal, same prices.", .byHand)
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A photo taken with no signal is still a promise, and it is kept across an app kill.
    @ViewBuilder private var waitingRow: some View {
        if let waiting = session.waiting.first {
            VStack(alignment: .leading, spacing: 8) {
                Notice("A receipt is waiting to be read. It stays on this phone until it is.",
                       on: .paper)
                Button {
                    path = [.camera]
                    Task { await session.read(waiting) }
                } label: {
                    Text("Read it now")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(Palette.persimmon.color))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func option(_ title: String, _ detail: String, _ route: CaptureRoute) -> some View {
        Button { path = [route] } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                    Text(detail)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
            .padding(14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card.color))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func destination(_ route: CaptureRoute) -> some View {
        switch route {
        case .camera:
            ReceiptCameraScreen(session: session)
        case .review:
            ReceiptReviewScreen(session: session, path: $path)
        case .resolver(let lineID):
            LineResolverScreen(session: session, lineID: lineID, path: $path)
        case .result:
            CaptureResultScreen(session: session, onDone: { dismiss() })
        case .barcode:
            BarcodeScanScreen(session: session, path: $path)
        case .byHand:
            EnterByHandScreen(session: session)
        }
    }
}
