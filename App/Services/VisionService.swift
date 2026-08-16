import CoreVideo
import ImageIO
import Vision

// Barcode reading is entirely on-device: no network, no cost, works offline and in a dead-signal
// aisle. There is no cloud path here and there must never be one.
enum VisionService {
    // The symbologies a grocery packet actually carries. QR is deliberately absent: a QR payload
    // is a URL or a coupon, never a product, and it must not become a key we teach.
    private static let symbologies: [VNBarcodeSymbology] = [.ean13, .ean8, .upce, .code128]

    // `perform` blocks its caller, so this stays synchronous and nonisolated: the video-data
    // queue calls it directly and AVFoundation drops the frames that arrive while it works.
    static func barcodePayload(in frame: CVPixelBuffer,
                               orientation: CGImagePropertyOrientation = .up) throws -> String? {
        let request = VNDetectBarcodesRequest()
        // UPC-A has no symbology of its own: Vision reports it as EAN-13 with a leading zero.
        request.symbologies = symbologies
        let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: orientation)
        try handler.perform([request])
        // The biggest code in the frame is the one being held up to the camera; a receipt or a
        // shelf label in the background must not win.
        return request.results?.max { area($0) < area($1) }?.payloadStringValue
    }

    private static func area(_ observation: VNBarcodeObservation) -> CGFloat {
        observation.boundingBox.width * observation.boundingBox.height
    }
}
