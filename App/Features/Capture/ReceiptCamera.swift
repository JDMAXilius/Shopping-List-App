import AVFoundation
import SwiftUI
import UIKit

/// The viewfinder and the shutter, and nothing else: a photo leaves here as JPEG `Data`, and
/// `Repository.enqueueScan` is what writes it — this never touches the filesystem.
@Observable @MainActor
final class ReceiptCamera {

    enum Access: Hashable {
        case undecided   // the primer has not been answered yet
        case granted
        case denied
    }

    private(set) var access: Access = ReceiptCamera.current
    @ObservationIgnored private let engine = CameraEngine()

    var previewSession: AVCaptureSession { engine.previewSession }

    private static var current: Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .undecided
        default: return .denied
        }
    }

    /// The primer's answer. Asked at the moment of use, never before (PRODUCT §5).
    func request() async {
        access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        start()
    }

    func start() {
        access = ReceiptCamera.current
        guard access == .granted else { return }
        engine.start()
    }

    func stop() {
        engine.stop()
    }

    /// nil when the device gave us no image — the screen says so rather than queueing nothing.
    func shoot() async -> Data? {
        await engine.capture()
    }
}

/// The one object that touches `AVCaptureSession`. Every mutation happens on `queue` — that
/// serialization, not a promise, is what makes the unchecked conformance true.
final class CameraEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.bagged.camera")
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var isConfigured = false

    /// Read-only, for the preview layer to bind on the main thread; nothing else reads it.
    var previewSession: AVCaptureSession { session }

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

    func capture() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let settings = AVCapturePhotoSettings(
                    format: [AVVideoCodecKey: AVVideoCodecType.jpeg.rawValue])
                // The output retains its delegate until it has finished calling it back.
                output.capturePhoto(with: settings, delegate: PhotoDelegate { data in
                    continuation.resume(returning: data)
                })
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
    }
}

/// Callbacks arrive on AVFoundation's own queue, so this holds nothing but the answer it hands
/// back: the photo becomes `Data` here and never crosses a boundary as an object.
private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let answer: @Sendable (Data?) -> Void

    init(answer: @escaping @Sendable (Data?) -> Void) {
        self.answer = answer
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: (any Error)?) {
        answer(photo.fileDataRepresentation())
    }
}

struct CameraPreview: UIViewRepresentable {
    let camera: ReceiptCamera

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer?.session = camera.previewSession
        view.previewLayer?.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
}
