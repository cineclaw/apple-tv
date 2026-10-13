import Foundation
import AVFoundation
import AVKit
import UIKit
import os
import VideoPlayerCore

private final class AVPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

@Observable
@MainActor
final class AVPlayerEngine: NSObject, VideoPlayerEngine, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "AVPlayerEngine")

    let player: AVPlayer = AVPlayer()
    private let playerView = AVPlayerLayerView()
    private(set) var currentItem: AVPlayerItem?
    private var endObserver: Any?

    var onVideoViewReady: ((UIView) -> Void)?
    var videoSurfaceView: UIView? { playerView }

    var onPlaybackEnded: (@MainActor () -> Void)?

    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    var isBuffering: Bool {
        player.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    var currentTime: Double {
        let t = player.currentTime()
        guard t.isValid && !t.isIndefinite else { return 0.0 }
        return max(0.0, CMTimeGetSeconds(t))
    }

    var duration: Double {
        guard let item = currentItem else { return 0.0 }
        let d = item.duration
        guard d.isValid && !d.isIndefinite else { return 0.0 }
        return max(0.0, CMTimeGetSeconds(d))
    }

    var audioTracks: [AudioTrackOption] { [] }
    var subtitleTracks: [SubtitleTrackOption] { [SubtitleTrackOption(id: "off", title: "Выключить субтитры", language: "")] }
    var currentAudioTrackId: String { "" }
    var currentSubtitleTrackId: String { "off" }

    override init() {
        super.init()
        player.actionAtItemEnd = .pause
        playerView.playerLayer.player = player
        playerView.playerLayer.videoGravity = .resizeAspect
    }

    func load(url: URL, initialSeek: Double? = nil) {
        logger.info("Loading HLS stream in AVPlayer: \(url.absoluteString, privacy: .public)")
        cleanEndObserver()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.currentItem = item

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onPlaybackEnded?()
            }
        }

        player.replaceCurrentItem(with: item)
        onVideoViewReady?(playerView)

        if let seek = initialSeek, seek > 2.0 {
            logger.info("Applying initial seek to \(seek)s")
            let target = CMTime(seconds: seek, preferredTimescale: 600)
            item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.player.play()
            }
        } else {
            player.play()
        }
    }

    func switchStream(url: URL, initialSeek: Double?) {
        load(url: url, initialSeek: initialSeek)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: max(0.0, seconds), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func selectAudio(trackId: String) {}
    func selectSubtitle(trackId: String) {}

    func stop() {
        player.pause()
        cleanEndObserver()
        player.replaceCurrentItem(with: nil)
        currentItem = nil
    }

    private func cleanEndObserver() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
    }
}
