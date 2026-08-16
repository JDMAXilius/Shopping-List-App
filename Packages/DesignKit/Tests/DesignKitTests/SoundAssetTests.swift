import XCTest
import DesignKit

// The two sounds, verified as shipped (INTERACTION.md §5): sub-120ms tick, ≤450ms
// completion tone, peaks ≤ -12dBFS, 44.1kHz mono 16-bit. Parsed by hand — no AVFoundation.
final class SoundAssetTests: XCTestCase {

    private struct WAV {
        let sampleRate: Int
        let channels: Int
        let bitsPerSample: Int
        let durationSeconds: Double
        let peakDBFS: Double
    }

    private func parseWAV(_ data: Data) throws -> WAV {
        func u16(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        func u32(_ o: Int) -> Int {
            Int(data[o]) | Int(data[o + 1]) << 8 | Int(data[o + 2]) << 16 | Int(data[o + 3]) << 24
        }
        XCTAssertEqual(String(decoding: data[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")

        var sampleRate = 0, channels = 0, bits = 0
        var frames = 0, peak = 0
        var offset = 12
        while offset + 8 <= data.count {
            let id = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let size = u32(offset + 4)
            let body = offset + 8
            if id == "fmt " {
                channels = u16(body + 2)
                sampleRate = u32(body + 4)
                bits = u16(body + 14)
            } else if id == "data" {
                XCTAssertEqual(bits, 16, "expected 16-bit PCM")
                let bytesPerFrame = channels * 2
                frames = size / bytesPerFrame
                var i = body
                while i + 1 < body + size {
                    var sample = u16(i)
                    if sample >= 0x8000 { sample -= 0x10000 }
                    peak = max(peak, abs(sample))
                    i += 2
                }
            }
            offset = body + size + (size % 2)
        }
        let duration = Double(frames) / Double(sampleRate)
        let peakDB = 20 * log10(Double(max(peak, 1)) / 32768.0)
        return WAV(sampleRate: sampleRate, channels: channels, bitsPerSample: bits,
                   durationSeconds: duration, peakDBFS: peakDB)
    }

    private func load(_ url: URL?) throws -> WAV {
        let url = try XCTUnwrap(url, "sound missing from bundle")
        return try parseWAV(Data(contentsOf: url))
    }

    func testCheckTick() throws {
        let wav = try load(SoundAssets.checkURL)
        XCTAssertEqual(wav.sampleRate, 44100)
        XCTAssertEqual(wav.channels, 1)
        XCTAssertEqual(wav.bitsPerSample, 16)
        XCTAssertLessThanOrEqual(wav.durationSeconds, 0.120, "a tick, not a chime")
        XCTAssertLessThanOrEqual(wav.peakDBFS, -12.0, "must survive 40 repetitions")
    }

    func testCompleteTone() throws {
        let wav = try load(SoundAssets.completeURL)
        XCTAssertEqual(wav.sampleRate, 44100)
        XCTAssertEqual(wav.channels, 1)
        XCTAssertEqual(wav.bitsPerSample, 16)
        XCTAssertLessThanOrEqual(wav.durationSeconds, 0.450, "arrival, not celebration")
        XCTAssertLessThanOrEqual(wav.peakDBFS, -12.0)
    }
}
