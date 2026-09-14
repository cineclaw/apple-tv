import Foundation
import MediaPlayer
import AVFoundation
import os

@MainActor
final class NowPlayingService {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "NowPlayingService")

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onTogglePlayPause: (() -> Void)?
    var onSkipForward: ((Double) -> Void)?
    var onSkipBackward: ((Double) -> Void)?
    var onSeek: ((Double) -> Void)?

    private var targets: [Any] = []

    func setup() {
        configureAudioSession()
        setupCommands()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
            logger.info("AVAudioSession configured for playback/moviePlayback")
        } catch {
            logger.warning("Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }

    private func setupCommands() {
        let center = MPRemoteCommandCenter.shared()

        // 1. Play
        center.playCommand.isEnabled = true
        targets.append(center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onPlay?()
            }
            return .success
        })

        // 2. Pause
        center.pauseCommand.isEnabled = true
        targets.append(center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onPause?()
            }
            return .success
        })

        // 3. Toggle Play/Pause
        center.togglePlayPauseCommand.isEnabled = true
        targets.append(center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onTogglePlayPause?()
            }
            return .success
        })

        // 4. Skip Forward (10s)
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [10]
        targets.append(center.skipForwardCommand.addTarget { [weak self] event in
            let interval: Double
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                interval = skipEvent.interval
            } else {
                interval = 10.0
            }
            Task { @MainActor in
                self?.onSkipForward?(interval)
            }
            return .success
        })

        // 5. Skip Backward (10s)
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [10]
        targets.append(center.skipBackwardCommand.addTarget { [weak self] event in
            let interval: Double
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                interval = skipEvent.interval
            } else {
                interval = 10.0
            }
            Task { @MainActor in
                self?.onSkipBackward?(interval)
            }
            return .success
        })

        // 6. Scrubbing / Position Change
        center.changePlaybackPositionCommand.isEnabled = true
        targets.append(center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let target = posEvent.positionTime
            Task { @MainActor in
                self?.onSeek?(target)
            }
            return .success
        })

        logger.info("MPRemoteCommandCenter targets registered successfully")
    }

    func updateNowPlaying(
        title: String,
        season: Int? = nil,
        episode: Int? = nil,
        currentTime: Double,
        duration: Double,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title

        if let s = season, let e = episode, s > 0 && e > 0 {
            info[MPMediaItemPropertyAlbumTitle] = "Сезон \(s), Серия \(e)"
        }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        info[MPMediaItemPropertyMediaType] = MPMediaType.movie.rawValue

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func teardown() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        targets.removeAll()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        logger.info("MPRemoteCommandCenter targets removed and nowPlayingInfo cleared")
    }
}
