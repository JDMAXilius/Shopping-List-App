import DesignKit
import Foundation
import SwiftUI

/// The guest's whole path. No account, no sign-in, no paywall — not on this screen and not
/// behind it: joining mints an anonymous session server-side and that session IS the
/// membership (PRODUCT §2, "paywall the owner, never the joiner").
///
/// The link that got here is a bearer token, so it is never shown back, never copied to the
/// clipboard, and never written anywhere but the request that spends it.
struct JoinScreen: View {
    let store: KitchenStore
    /// Pre-filled when the app was opened by the link itself; typed or pasted otherwise.
    var link: String = ""
    var onJoined: (() -> Void)?

    @State private var text = ""
    @State private var joined = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(joined ? "You're in" : "Join this kitchen")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text(joined
                 ? "Their list is your list now. Nothing to set up."
                 : "You'll see their list straight away. No account, and it stays free for you.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)

            if !joined {
                if link.isEmpty {
                    TextField("Paste your invite link", text: $text)
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink.color)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.card.color)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Palette.line.color, lineWidth: 1)))
                }
                Button(action: join) {
                    Text(store.isWorking ? "Joining…" : "Join")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.persimmon.color))
                }
                .buttonStyle(.plain)
                .disabled(store.isWorking || candidate.isEmpty)
                .opacity(store.isWorking || candidate.isEmpty ? 0.4 : 1)
            }

            if let message = store.message {
                Notice(message, on: .paper)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDragIndicator(.visible)
    }

    private var candidate: String { link.isEmpty ? text : link }

    private func join() {
        Task {
            guard await store.join(candidate) else { return }
            joined = true
            Haptics.play(.add)
            onJoined?()
            // A beat on "You're in", then out of the way — the list is the point, not this.
            try? await Task.sleep(for: .milliseconds(700))
            dismiss()
        }
    }
}
