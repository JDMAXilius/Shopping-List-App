import CoreImage
import DesignKit
import Foundation
import SwiftUI
import UIKit

/// Sheet 25 — one link, and the plain truth about it: a new link signs the old one out.
///
/// The link is a bearer token. Anyone holding it can join until it is replaced, so it is shown,
/// shared and then forgotten — never stored, never logged, never put in a screenshot-friendly
/// "invite id" that outlives the sheet.
struct InviteSheet: View {
    let store: KitchenStore

    @State private var isNaming = false
    @State private var isSigningIn = false
    @State private var isUnavailable = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get the kitchen on the list")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("They tap the link and see the list — no account, free forever.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)

            if let url = store.inviteURL {
                link(url)
                qr(url)
                Text("A new link signs the old one out.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .frame(maxWidth: .infinity, alignment: .center)
                ShareLink(item: url) {
                    Text("Share link")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.persimmon.color))
                }
                Button("Make a new link") { Task { await store.refreshInvite() } }
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else if isUnavailable {
                Notice("Sharing isn't switched on in this copy of Bagged. Your list is safe on "
                       + "this phone.", on: .paper)
            } else if let message = store.message {
                Notice(message, on: .paper)
            } else {
                // Not a spinner: a line that says what is happening and blocks nothing.
                Text("Making a link…")
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $isNaming) {
            NameKitchenSheet(store: store) { Task { await store.refreshInvite() } }
        }
        // Sign-in is a step of THIS moment (the owner's kitchen has to outlive the phone),
        // which is why it lives here and never in front of the list.
        .sheet(isPresented: $isSigningIn) {
            SignInScreen(store: store) { Task { await prepare() } }
        }
        .task { await prepare() }
        .onDisappear { store.forgetInvite() }
    }

    /// Name and sign-in are steps of THIS moment, not of a wizard — they appear only because
    /// an invite was asked for.
    private func prepare() async {
        switch await store.beginInvite() {
        case .invite:
            if store.inviteURL == nil { await store.refreshInvite() }
        case .name:
            isNaming = true
        case .signIn:
            isSigningIn = true
        case .unavailable:
            isUnavailable = true
        }
    }

    private func link(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Text(url.absoluteString)
                .font(Typography.priceSmall)
                .foregroundStyle(Palette.ink.color)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button {
                UIPasteboard.general.string = url.absoluteString
                copied = true
                Haptics.play(.add)
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(Palette.muted.color)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy invite link")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Palette.card.color))
    }

    @ViewBuilder private func qr(_ url: URL) -> some View {
        if let image = InviteQR.image(for: url) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: 160, height: 160)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card.color))
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel("QR code for this invite link")
        }
    }
}

/// Black on white, always: a QR code is read by a camera, and tinting it to match the palette
/// is how a code stops scanning.
enum InviteQR {
    static func image(for url: URL) -> CGImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Foundation.Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
