import AVFoundation
import CoreMedia
import DesignKit
import SwiftUI
import UIKit

/// One item, straight off the packet. A barcode here is NOT a product lookup — this app has no
/// UPC data and does not pretend to. It is an unambiguous key the kitchen teaches once: say what
/// the code is, and every phone in the kitchen knows it after that.
struct BarcodeScanScreen: View {
    let session: CaptureSession
    @Binding var path: [CaptureRoute]

    @State private var camera = BarcodeCamera()
    @State private var chosen: CaptureMatch?
    /// This save writes the alias that teaches the code — true until the kitchen knows it.
    @State private var teaches = false
    /// The code is matched to an item nothing on this phone can name.
    @State private var unnamed = false
    @State private var saved: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let saved {
                    Notice(saved, on: .paper)
                }
                if let code = camera.code {
                    scanned(code)
                } else {
                    scanner
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationTitle("Scan a barcode")
        .navigationBarTitleDisplayMode(.inline)
        .task { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.code) { _, code in
            guard let code else { return }
            let known = session.remembered(code)
            // A match we cannot put a name to is not a match we may show: the digits of a code
            // are not a product name.
            chosen = known.flatMap { $0.name == code ? nil : $0 }
            unnamed = known != nil && chosen == nil
            teaches = chosen == nil
        }
    }

    // MARK: - Finding a code

    @ViewBuilder private var scanner: some View {
        switch camera.access {
        case .undecided:
            primer
        case .denied:
            denied
        case .granted:
            viewfinder
            Notice("A barcode is a name your kitchen teaches once. Bagged has no product database behind it — you say what a code is the first time, and it's known from then on.",
                   on: .paper)
        }
    }

    private var primer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One item, off the packet")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("Bagged needs the camera to read a barcode. The reading happens on this phone — no photo is taken, and the code is never sent anywhere.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Button {
                Task { await camera.request() }
            } label: {
                primaryLabel("Allow the camera")
            }
            .buttonStyle(.plain)
            byHandButton
        }
    }

    /// Never a dead end: the price can still be typed.
    private var denied: some View {
        VStack(alignment: .leading, spacing: 12) {
            Notice("The camera is switched off for Bagged, so no code can be read. Turn it on in Settings — or enter the price by hand.",
                   tone: .attention, on: .paper)
            Button { path.append(.byHand) } label: {
                primaryLabel("Enter by hand")
            }
            .buttonStyle(.plain)
        }
    }

    private var viewfinder: some View {
        ZStack(alignment: .top) {
            BarcodePreview(camera: camera)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Notice("Hold the barcode inside the frame", on: .paper)
                .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var byHandButton: some View {
        Button { path.append(.byHand) } label: {
            Text("Enter by hand instead")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - What the code turned out to be

    @ViewBuilder private func scanned(_ code: String) -> some View {
        codeRow(code)
        if let chosen {
            Notice(teaches
                   ? "Saving this price also teaches your kitchen that this code is \(chosen.name)."
                   : "Your kitchen already taught this code: it's \(chosen.name).", on: .paper)
            TypedPriceEntry(session: session, item: chosen,
                            rawText: teaches ? code : "") { sentence in
                saved = sentence
                self.chosen = nil
                camera.clear()
            }
        } else {
            Notice(unnamed
                   ? "This code was matched here before, but nothing on this phone names that item. Say what it is."
                   : "New code — what is this? Say it once and the whole kitchen knows it.",
                   on: .paper)
            ItemChoice(session: session, prompt: "WHAT IS THIS?") { match, _ in
                chosen = match
                teaches = true
            }
        }
    }

    private func codeRow(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("THE CODE")
            Text(code)
                .font(Typography.price)
                .foregroundStyle(Palette.ink.color)
            Button { camera.clear() } label: {
                Text("Scan a different one")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(Palette.card.color)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Palette.persimmon.color))
    }
}

/// The viewfinder for a stream of frames rather than a shutter — same permission vocabulary as
/// `ReceiptCamera`, because a camera is a camera.
@Observable @MainActor
final class BarcodeCamera {
    typealias Access = ReceiptCamera.Access

    private(set) var access: Access = BarcodeCamera.current
    /// The code being asked about. One at a time: scanning stops until the screen clears it.
    private(set) var code: String?

    @ObservationIgnored private lazy var engine = BarcodeEngine { [weak self] payload in
        Task { @MainActor in self?.read(payload) }
    }

    var previewSession: AVCaptureSession { engine.previewSession }

    private static var current: Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .undecided
        default: return .denied
        }
    }

    /// Asked at the moment of use, never before (PRODUCT §5).
    func request() async {
        access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        start()
    }

    func start() {
        access = BarcodeCamera.current
        guard access == .granted, code == nil else { return }
        engine.start()
    }

    func stop() {
        engine.stop()
    }

    func clear() {
        code = nil
        start()
    }

    private func read(_ payload: String) {
        guard code == nil else { return }
        code = payload
        engine.stop()
        Haptics.play(.add)
    }
}

/// The one object that touches `AVCaptureSession` here. Every mutation and every frame happens
/// on `queue` — that serialization, not a promise, is what makes the unchecked conformance true.
private final class BarcodeEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
                                   @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.bagged.barcode")
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let found: @Sendable (String) -> Void
    private var isConfigured = false

    var previewSession: AVCaptureSession { session }

    init(found: @escaping @Sendable (String) -> Void) {
        self.found = found
        super.init()
    }

    func start() {
        queue.async { [self] in
            configureIfNeeded()
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        // A dropped frame costs nothing — the barcode is still there in the next one, and a
        // backlog would only make the reading later than the packet in front of the lens.
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // The back camera hands portrait frames over rotated; `.right` is what the user sees.
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer),
              let payload = try? VisionService.barcodePayload(in: frame, orientation: .right),
              !payload.isEmpty else { return }
        found(payload)
    }
}

/// `PreviewView` already owns the layer class; only the session it shows differs.
private struct BarcodePreview: UIViewRepresentable {
    let camera: BarcodeCamera

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = camera.previewSession
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}
