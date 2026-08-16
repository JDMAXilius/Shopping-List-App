import DesignKit
import Foundation
import SwiftUI

/// Screen 21. The shutter always succeeds: the photo is queued the moment it is taken, and
/// what the network does next changes only how long the reading waits.
struct ReceiptCameraScreen: View {
    let session: CaptureSession

    @State private var camera = ReceiptCamera()
    @State private var isShooting = false
    @State private var shutterFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch session.stage {
            case .parsing:
                reading
            case .waiting:
                queued
            case .failed(let failure):
                failed(failure)
            case .handoff(let destination):
                handoffState(destination)
            default:
                shooting
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.paper.color)
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .task { camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Taking the photo

    @ViewBuilder private var shooting: some View {
        #if DEBUG
        // Walkthrough scaffolding: the simulator has no camera, so the scripted-scan
        // launch mode gets a stand-in shutter. Compiled out of release.
        if ScriptedScanBackend.isRequested {
            Button("Use test photo") {
                Task { await session.capture(jpeg: Foundation.Data([0xFF, 0xD8, 0xFF, 0xE0])) }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(Palette.persimmon.color)
            .frame(minHeight: 44)
        }
        #endif
        switch camera.access {
        case .undecided:
            primer
        case .denied:
            EmptyState(
                glyph: .other,
                message: "The camera is switched off for Bagged. Turn it on in Settings, or type the receipt in by hand.")
        case .granted:
            viewfinder
            if shutterFailed {
                Notice("The camera gave us no photo. Try that again.", tone: .attention, on: .paper)
            }
            shutter
        }
    }

    /// The primer, at the moment of use and not one screen earlier (PRODUCT §5).
    private var primer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One photo, every line")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("Bagged needs the camera to read a receipt. The photo stays on this phone — it is never uploaded to us and never kept on a server.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Button {
                Task { await camera.request() }
            } label: {
                primaryLabel("Allow the camera")
            }
            .buttonStyle(.plain)
        }
    }

    private var viewfinder: some View {
        ZStack(alignment: .top) {
            CameraPreview(camera: camera)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Notice("Catch the whole receipt in the frame", on: .paper)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shutter: some View {
        Button {
            Task { await shoot() }
        } label: {
            primaryLabel(isShooting ? "Taking it…" : "Take the photo")
        }
        .buttonStyle(.plain)
        .disabled(isShooting)
        .opacity(isShooting ? 0.6 : 1)
    }

    private func shoot() async {
        isShooting = true
        shutterFailed = false
        defer { isShooting = false }
        Haptics.play(.add)
        guard let jpeg = await camera.shoot() else {
            shutterFailed = true
            return
        }
        await session.capture(jpeg: jpeg)
    }

    // MARK: - What happened next

    private var reading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading the receipt…")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Notice("About six seconds. Nothing is saved until you've checked the lines.", on: .paper)
        }
    }

    /// Offline is not an error state. It is the promised behaviour.
    private var queued: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo kept")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Notice("Works offline — reads when you're back", on: .paper)
            retryRow
        }
    }

    private func failed(_ failure: CaptureSession.Failure) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Notice(Self.sentence(failure), tone: .attention, on: .paper)
            if Self.keepsThePhoto(failure) {
                retryRow
            } else {
                takeAnother
            }
        }
    }

    /// Wave 9 owns all three destinations. The route is decided here and named honestly —
    /// a live-looking button to a screen that does not exist would be the worse lie.
    private func handoffState(_ handoff: CaptureSession.Handoff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.headline(handoff))
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Notice(Self.sentence(handoff), on: .paper)
            Notice("Your photo is queued on this phone until then.", on: .paper)
            takeAnother
        }
    }

    @ViewBuilder private var retryRow: some View {
        if let pending = session.scan {
            Button {
                Task { await session.read(pending) }
            } label: {
                primaryLabel("Try reading it now")
            }
            .buttonStyle(.plain)
        }
        takeAnother
    }

    private var takeAnother: some View {
        Button { session.retakePhoto() } label: {
            Text("Take another photo")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(Palette.card.color)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Palette.persimmon.color))
    }

    // MARK: - Words

    /// A photo still worth reading stays queued; one only a new photo can fix is deleted, and
    /// this answer is the one the session acted on — the two cannot disagree.
    static func keepsThePhoto(_ failure: CaptureSession.Failure) -> Bool {
        switch failure {
        case .rateLimited, .upstream, .unauthenticated, .ourBug: return true
        case .unreadable, .tooLarge, .storage: return false
        }
    }

    static func sentence(_ failure: CaptureSession.Failure) -> String {
        switch failure {
        case .unreadable:
            return "That photo couldn't be read, so it wasn't kept. Take another with the whole receipt in the frame."
        case .tooLarge:
            return "That photo is too large to send, so it wasn't kept. Take another one."
        case .rateLimited:
            return "That's ten scans in an hour. The photo is kept — read it again in a while."
        case .upstream:
            return "The reader didn't answer. The photo is kept — try again in a moment."
        case .ourBug:
            return "Something on our side refused that photo. It's kept — try reading it again in a moment."
        case .unauthenticated:
            return "You're signed out, so the reader wouldn't answer. The photo is kept."
        case .storage:
            return "This phone couldn't keep that photo, so nothing was queued. Try again."
        }
    }

    static func headline(_ handoff: CaptureSession.Handoff) -> String {
        switch handoff {
        case .paywall: return "That's your free scans"
        case .signIn: return "Scanning needs an account"
        case .kitchen: return "Name your kitchen first"
        }
    }

    static func sentence(_ handoff: CaptureSession.Handoff) -> String {
        switch handoff {
        // The count is the function's own; when it doesn't send one we don't invent it.
        case .paywall(let scansUsed):
            let used = scansUsed.map { "You've used \($0) free receipt \($0 == 1 ? "scan" : "scans")." }
            return [used, "The Plus screen isn't built yet."].compactMap { $0 }.joined(separator: " ")
        case .signIn:
            return "An account is what keeps your kitchen if you lose this phone. The sign-in screen arrives with sharing."
        case .kitchen:
            return "A receipt is filed to a kitchen. Naming yours arrives with sharing."
        }
    }
}
