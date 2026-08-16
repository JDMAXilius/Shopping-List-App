import CoreVideo
import ImageIO
import Vision

// Barcode reading is entirely on-device: no network, no cost, works offline and in a dead-signal
// aisle. There is no cloud path here and there must never be one.
enum VisionService {
    // Vision asks for no actor; `perform` blocks its thread, so this stays nonisolated and async
    // — a main-actor caller hops off the main thread to run it.
    static func barcodePayload(in frame: sending CVPixelBuffer,
                               orientation: CGImagePropertyOrientation = .up) async throws -> String? {
        let request = VNDetectBarcodesRequest()
        // UPC-A has no symbology of its own: Vision reports it as EAN-13 with a leading zero.
        request.symbologies = [.ean13, .ean8, .qr]
        let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: orientation)
        try handler.perform([request])
        return request.results?.compactMap(\.payloadStringValue).first
    }
}
