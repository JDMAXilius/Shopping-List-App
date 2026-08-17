import Core
import Data
import DesignKit
import Foundation
import SwiftUI

/// Screen 11 — who is in this kitchen, and the one button that adds someone.
///
/// The mock's activity feed is NOT here, and it is not a placeholder either: an op carries a
/// `device_id`, never a `user_id`, and no table maps one to the other — so "Mara checked off
/// eggs" cannot be told truthfully by this build. A feed of guesses would be worse than none.
struct KitchenScreen: View {
    let store: KitchenStore
    let sync: SyncCoordinator
    @Binding var sheet: Sheet?

    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                ForEach(store.members, id: \.userID) { member in
                    row(member)
                }
                if store.members.isEmpty { soloNotice }
                inviteButton
                joinButton
                Text(sync.sentence)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                if let message = store.message {
                    Notice(message, on: .paper)
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isJoining) {
            JoinScreen(store: store)
        }
        .task { await store.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.kitchen.name)
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink.color)
            Text(store.headline)
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
        }
        .accessibilityElement(children: .combine)
    }

    /// No names anywhere: the roster is `user_id`, `role`, `joined_at` and nothing else.
    /// Everyone is shown as what the server can actually say they are.
    private func row(_ member: Member) -> some View {
        HStack(spacing: 12) {
            GlyphTile(emoji: member.role == .owner ? "🔑" : "🛒")
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe(member) ? "You" : title(member))
                    .font(Typography.itemName)
                    .foregroundStyle(Palette.ink.color)
                Text(subtitle(member))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            Spacer(minLength: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .combine)
    }

    private func isMe(_ member: Member) -> Bool {
        store.identity?.userID == member.userID
    }

    private func title(_ member: Member) -> String {
        member.role == .owner ? "Owner" : "Guest"
    }

    private func subtitle(_ member: Member) -> String {
        var parts = [member.role == .owner ? "Owner" : "Guest · free forever"]
        if member.joinedAt.timeIntervalSince1970 > 0 {
            parts.append("joined \(member.joinedAt.formatted(.dateTime.day().month(.abbreviated)))")
        }
        return parts.joined(separator: " · ")
    }

    private var soloNotice: some View {
        Notice("This kitchen is on this phone only. Invite someone and the list is on both.",
               on: .paper)
    }

    private var inviteButton: some View {
        Button {
            sheet = .invite
        } label: {
            Text("+ Invite someone")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.persimmon.color)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.card.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Palette.line.color, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite someone to this kitchen")
    }

    /// The other side of the same loop: a link that arrived by message rather than by tap.
    private var joinButton: some View {
        Button {
            isJoining = true
        } label: {
            Text("I have an invite link")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}
