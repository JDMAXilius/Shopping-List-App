import AuthenticationServices
import CryptoKit
import DesignKit
import Foundation
import Security
import SwiftUI

/// Screen 19 — owners only, and only when inviting or restoring. A guest never reaches this
/// screen and never needs to: their anonymous session is a full membership.
struct SignInScreen: View {
    let store: KitchenStore
    var onSignedIn: (() -> Void)?

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var nonce = AppleNonce.make()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keep your kitchen safe")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("So your prices and lists survive a lost phone. Guests never need this.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if codeSent { codeEntry } else { emailEntry }
            if let message = store.message {
                Notice(message, on: .paper)
            }
            appleButton
            Button("Skip — stay on this phone only") { dismiss() }
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
            Text("Your data stays yours. Export or delete any time.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDragIndicator(.visible)
    }

    private var emailEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("you@example.com", text: $email)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card.color)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.line.color, lineWidth: 1)))
            Button {
                Task { codeSent = await store.requestEmailCode(email) }
            } label: {
                Text("Continue with email")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink.color)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.card.color)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Palette.line.color, lineWidth: 1)))
            }
            .buttonStyle(.plain)
            .disabled(!email.contains("@") || store.isWorking)
            .opacity(!email.contains("@") || store.isWorking ? 0.4 : 1)
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We sent a code to \(email).")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            TextField("6-digit code", text: $code)
                .font(Typography.price)
                .foregroundStyle(Palette.ink.color)
                .keyboardType(.numberPad)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.card.color)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.line.color, lineWidth: 1)))
            Button {
                Task {
                    guard await store.verifyEmailCode(code) else { return }
                    onSignedIn?()
                    dismiss()
                }
            } label: {
                Text(store.isWorking ? "Checking…" : "Confirm")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(code.count < 6 || store.isWorking)
            .opacity(code.count < 6 || store.isWorking ? 0.4 : 1)
        }
    }

    /// Apple is offered only to a phone with no session. With an anonymous session it would
    /// mint a DIFFERENT user and quietly drop this phone's membership, so the store refuses it
    /// and the email path — which keeps the same user id — is the one that upgrades a guest.
    @ViewBuilder private var appleButton: some View {
        if store.isGuest == false {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email]
                request.nonce = AppleNonce.hashed(nonce)
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let token = String(data: data, encoding: .utf8) else { return }
        let used = nonce
        // One nonce, one exchange: a fresh one is minted for any later attempt.
        nonce = AppleNonce.make()
        Task {
            guard await store.signInWithApple(idToken: token, nonce: used) else { return }
            onSignedIn?()
            dismiss()
        }
    }
}

/// The nonce Apple signs and Supabase checks: the raw value goes to the server, its SHA-256
/// goes to Apple. Sending the same value to both is what makes a replay possible.
enum AppleNonce {
    static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString + UUID().uuidString
        }
        return Foundation.Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func hashed(_ nonce: String) -> String {
        SHA256.hash(data: Foundation.Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
