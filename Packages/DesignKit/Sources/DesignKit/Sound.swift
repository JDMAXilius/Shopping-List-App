import Foundation
#if os(iOS)
import AVFoundation
#endif

/// Bundle locations for the two shipped sounds — exposed so tests can verify the
/// assets (length, peak, format) without any audio framework.
public enum SoundAssets {
    public static var checkURL: URL? { Bundle.module.url(forResource: "check", withExtension: "wav") }
    public static var completeURL: URL? { Bundle.module.url(forResource: "complete", withExtension: "wav") }
}

/// APP TARGET ONLY. Never call from the widget or an App Intent — a check-off from
/// the lock screen is silent (INTERACTION.md §5). Two sounds; that's the whole library.
@MainActor
public enum Sound {

    public enum Event: Sendable {
        case check     // sub-120ms tick, survives 40 repetitions
        case complete  // the arrival tone, whole-list completion only
    }

    /// The single settings toggle, next to haptics. Default on — the sounds are
    /// quiet by design, not by volume setting.
    public static var isEnabled = true

    // Structural, not conventional (W4-C1 fix 8): in any .appex the doc rule above enforces itself.
    private static var isAppExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }

    #if os(iOS)
    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionConfigured = false

    // `.ambient`, never `.playback`: silent switch always respected, other audio
    // never interrupted or ducked. This is what makes on-by-default acceptable.
    private static func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    private static func player(for event: Event) -> AVAudioPlayer? {
        let url: URL?
        switch event {
        case .check: url = SoundAssets.checkURL
        case .complete: url = SoundAssets.completeURL
        }
        guard let url else { return nil }
        if let cached = players[url.lastPathComponent] { return cached }
        guard let made = try? AVAudioPlayer(contentsOf: url) else { return nil }
        made.prepareToPlay()
        players[url.lastPathComponent] = made
        return made
    }
    #endif

    /// Feedback must never fail loudly: any audio error is a silent no-op.
    public static func play(_ event: Event) {
        guard isEnabled, !isAppExtension else { return }
        #if os(iOS)
        configureSessionIfNeeded()
        guard let player = player(for: event) else { return }
        player.currentTime = 0
        player.play()
        #endif
    }

    /// Warm the players (e.g. when the list appears) so the first tick isn't late.
    public static func prepare() {
        guard !isAppExtension else { return }
        #if os(iOS)
        configureSessionIfNeeded()
        _ = player(for: .check)
        _ = player(for: .complete)
        #endif
    }
}
