import Foundation
import UIKit
import SwiftUI
import os
import VideoPlayerCore
@preconcurrency internal import KSPlayer
import AVFoundation
import CoreMedia
import QuartzCore

/// Custom player options tuned specifically for smooth local BitTorrent streaming over HDMI on tvOS.
/// Overrides aggressive KSPlayer frame-dropping thresholds that cause periodic micro-freezes.
final class CineClawPlayerOptions: KSOptions {
    private var videoClockDelayCount = 0

    override func videoClockSync(main: KSClock, nextVideoTime: TimeInterval, fps: Double, frameCount: Int) -> (Double, ClockProcessType) {
        let mainTime: TimeInterval
        if main.time.isValid {
            mainTime = main.time.seconds + (CACurrentMediaTime() - main.lastMediaTime)
        } else {
            mainTime = CACurrentMediaTime() - main.lastMediaTime
        }
        let desire = mainTime - videoDelay
        let diff = nextVideoTime - desire
        let safeFps = fps > 0 ? fps : 24.0
        let frameDuration = 1.0 / safeFps

        // 1. Frame is ahead of audio clock by more than half frame duration -> hold frame in render queue
        if diff >= frameDuration * 0.5 {
            videoClockDelayCount = 0
            return (diff, .remain)
        }

        // 2. Normal sync window (-400ms to +frameDuration/2) -> Present frame smoothly!
        // Never drop frames for transient delays caused by HDMI audio buffering,
        // CADisplayLink 3:2 pulldown cadence, or minor network jitter.
        if diff >= -0.40 {
            videoClockDelayCount = 0
            return (diff, .next)
        }

        // 3. Catastrophic lag (> 1.5 seconds behind audio) -> Force flush or drop to resync
        if diff < -1.5 {
            videoClockDelayCount += 1
            if videoClockDelayCount % 10 == 0 {
                return (diff, .flush)
            }
            return (diff, .dropNextFrame)
        }

        // 4. Significant sustained lag (> 800ms behind audio) -> Drop every 5th frame if queue has buffer
        if diff < -0.80 {
            videoClockDelayCount += 1
            if frameCount > 2 && videoClockDelayCount % 5 == 0 {
                return (diff, .dropNextFrame)
            }
            return (diff, .next)
        }

        // 5. Moderate lag (-400ms to -800ms) -> Present immediately to let video naturally catch up
        videoClockDelayCount = 0
        return (diff, .next)
    }

    /// Dynamic frame rate matching for tvOS / AVDisplayManager.
    /// Returns the target AVDisplayCriteria with the video stream's exact native refresh rate.
    @available(tvOS 11.2, *)
    func makeDisplayCriteria(for fps: Float) -> AVDisplayCriteria? {
        guard fps > 1.0 else { return nil }
        #if os(tvOS)
        let roundedRate: Float
        if abs(fps - 23.976) < 0.1 || abs(fps - 24.0) < 0.1 {
            roundedRate = 24.0
        } else if abs(fps - 25.0) < 0.1 {
            roundedRate = 25.0
        } else if abs(fps - 29.97) < 0.1 || abs(fps - 30.0) < 0.1 {
            roundedRate = 30.0
        } else if abs(fps - 50.0) < 0.1 {
            roundedRate = 50.0
        } else if abs(fps - 59.94) < 0.1 || abs(fps - 60.0) < 0.1 {
            roundedRate = 60.0
        } else {
            roundedRate = fps
        }
        return AVDisplayCriteria(refreshRate: roundedRate, videoDynamicRange: 0)
        #else
        return nil
        #endif
    }
}

// MARK: - Internal Delegate Bridge (Hides KSPlayer from public module boundary)
private final class KSPlayerDelegateBridge: NSObject, KSPlayerLayerDelegate {
    private weak var engine: KSPlayerEngine?

    init(engine: KSPlayerEngine) {
        self.engine = engine
        super.init()
    }

    func player(layer: KSPlayerLayer, state: KSPlayerState) {
        engine?.handleStateChange(layer: layer, state: state)
    }

    func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        engine?.handleTimeUpdate(layer: layer, currentTime: currentTime, totalTime: totalTime)
    }

    func player(layer: KSPlayerLayer, finish error: Error?) {
        engine?.handleFinish(layer: layer, finish: error)
    }

    func player(layer: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        // Buffering telemetry
    }
}

@Observable
@MainActor
public final class KSPlayerEngine: NSObject, VideoPlayerEngine {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "KSPlayerEngine")

    private var playerLayer: KSPlayerLayer?
    private var delegateBridge: KSPlayerDelegateBridge?
    public var onVideoViewReady: ((UIView) -> Void)?
    public var videoSurfaceView: UIView? { playerLayer?.player.view }

    private var _currentTime: Double = 0.0
    private var _duration: Double = 0.0
    private var _state: KSPlayerState = .initialized
    private var isSeeking: Bool = false
    private var seekTargetTime: Double = 0.0
    private var seekTask: Task<Void, Never>?
    private var pendingInitialSeek: Double? = nil

    public override init() {
        super.init()
        KSOptions.preferredFrame = true
        configurePlayerTypes()
    }

    private func configurePlayerTypes(for url: URL? = nil) {
        let isHLS = url?.pathExtension.lowercased() == "m3u8" || url?.absoluteString.contains(".m3u8") == true
        if isHLS {
            KSOptions.firstPlayerType = KSAVPlayer.self
            KSOptions.secondPlayerType = KSAVPlayer.self
            KSOptions.audioPlayerType = AudioEnginePlayer.self
            logger.info("Configured KSAVPlayer (native Apple HLS engine) for m3u8")
        } else {
            KSOptions.firstPlayerType = KSMEPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
            KSOptions.audioPlayerType = AudioEnginePlayer.self
            logger.info("Configured KSMEPlayer (FFmpeg Metal engine) for container stream")
        }
    }

    public var isPlaying: Bool {
        if let player = playerLayer?.player {
            return player.playbackState == .playing
        }
        return _state.isPlaying
    }

    public var isBuffering: Bool {
        _state == .buffering || _state == .preparing
    }

    public var currentTime: Double {
        if isSeeking {
            return seekTargetTime
        }
        if let mePlayer = playerLayer?.player as? KSMEPlayer, mePlayer.isReadyToPlay {
            let vTime = mePlayer.displayedVideoTime
            if vTime > 0 {
                return vTime
            }
            return mePlayer.currentPlaybackTime
        }
        if let player = playerLayer?.player, player.isReadyToPlay {
            return player.currentPlaybackTime
        }
        return _currentTime
    }

    public var duration: Double {
        if let player = playerLayer?.player, player.duration > 0 {
            return player.duration
        }
        return _duration
    }

    public var audioTracks: [AudioTrackOption] {
        guard let player = playerLayer?.player else { return [] }
        let tracks = player.tracks(mediaType: .audio)
        return tracks.map { track in
            let id = String(track.trackID)
            let title = track.name
            let lang = track.languageCode ?? track.language ?? ""
            let codec = track.mediaSubType.rawValue.string.trimmingCharacters(in: .whitespaces)
            let channels: String
            if let desc = track.formatDescription?.audioStreamBasicDescription, desc.mChannelsPerFrame > 0 {
                channels = "\(desc.mChannelsPerFrame)ch"
            } else {
                channels = ""
            }
            return AudioTrackOption(
                id: id,
                title: title,
                language: lang,
                codec: codec,
                channels: channels
            )
        }
    }

    public var subtitleTracks: [SubtitleTrackOption] {
        var list = [
            SubtitleTrackOption(id: "off", title: "Выключить субтитры", language: "")
        ]
        guard let player = playerLayer?.player else { return list }
        let tracks = player.tracks(mediaType: .subtitle)
        list.append(contentsOf: tracks.map { track in
            let id = String(track.trackID)
            let title = track.name
            let lang = track.languageCode ?? track.language ?? ""
            return SubtitleTrackOption(id: id, title: title, language: lang)
        })
        return list
    }

    public var currentAudioTrackId: String {
        guard let player = playerLayer?.player else { return "" }
        let tracks = player.tracks(mediaType: .audio)
        if let enabled = tracks.first(where: { $0.isEnabled }) {
            return String(enabled.trackID)
        }
        return tracks.first.map { String($0.trackID) } ?? ""
    }

    public var currentSubtitleTrackId: String {
        guard let player = playerLayer?.player else { return "off" }
        let tracks = player.tracks(mediaType: .subtitle)
        if let enabled = tracks.first(where: { $0.isEnabled }) {
            return String(enabled.trackID)
        }
        return "off"
    }

    private func makePlayerOptions(for url: URL, initialSeek: Double?) -> CineClawPlayerOptions {
        let options = CineClawPlayerOptions()
        options.hardwareDecode = true
        options.asynchronousDecompression = true
        options.isAccurateSeek = false
        options.videoAdaptable = false
        options.preferredForwardBufferDuration = 4.0
        options.maxBufferDuration = 60.0
        options.seekFlags = 1 // AVSEEK_FLAG_BACKWARD

        // Network read-ahead buffer & persistent HTTP Keep-Alive for TorrServer HTTP Range chunks
        options.formatContextOptions["buffer_size"] = 1048576
        options.formatContextOptions["multiple_requests"] = 1

        // Probing optimization: cuts open time to <0.5s while keeping proper demuxer buffering
        options.probesize = 1024 * 1024 // 1 MB
        options.maxAnalyzeDuration = 500_000 // 0.5s
        options.autoSelectEmbedSubtitle = false

        let isHLS = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains(".m3u8")

        if let seek = initialSeek, seek > 2.0 {
            options.startPlayTime = seek
            _currentTime = seek
            seekTargetTime = seek
            // HLS streams with #EXT-X-START:TIME-OFFSET start at target seek automatically.
            // Avoid redundant playerLayer.seek which flushes buffer and delays start.
            pendingInitialSeek = isHLS ? nil : seek
            logger.info("Set startPlayTime to \(seek)s (isHLS: \(isHLS))")
        } else {
            options.startPlayTime = 0
            _currentTime = 0
            seekTargetTime = 0
            pendingInitialSeek = nil
            logger.info("Starting from 0s")
        }

        return options
    }

    public func load(url: URL, initialSeek: Double?) {
        logger.info("Loading stream with KSPlayer: \(url.absoluteString, privacy: .public), initialSeek: \(initialSeek ?? 0)")

        stop()
        configurePlayerTypes(for: url)

        let options = makePlayerOptions(for: url, initialSeek: initialSeek)
        let bridge = KSPlayerDelegateBridge(engine: self)
        self.delegateBridge = bridge
        let layer = KSPlayerLayer(url: url, isAutoPlay: true, options: options, delegate: bridge)
        self.playerLayer = layer

        if let videoView = layer.player.view {
            videoView.contentMode = .scaleAspectFit
            videoView.layer.contentsScale = UIScreen.main.scale
            videoView.contentScaleFactor = UIScreen.main.scale
            onVideoViewReady?(videoView)
        }
    }

    public func switchStream(url: URL, initialSeek: Double?) {
        guard let layer = playerLayer else {
            load(url: url, initialSeek: initialSeek)
            return
        }
        logger.info("Switching stream in-place: \(url.absoluteString, privacy: .public), initialSeek: \(initialSeek ?? 0)")
        configurePlayerTypes(for: url)

        let options = makePlayerOptions(for: url, initialSeek: initialSeek)
        layer.set(url: url, options: options)
        if let av = (layer.player as? KSAVPlayer)?.player {
            av.automaticallyWaitsToMinimizeStalling = true
        }
    }

    public func play() {
        playerLayer?.play()
    }

    public func pause() {
        playerLayer?.pause()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to seconds: Double) {
        guard let layer = playerLayer else { return }
        logger.info("Seeking to \(seconds)s")
        seekTask?.cancel()
        _currentTime = seconds
        seekTargetTime = seconds
        isSeeking = true
        layer.seek(time: seconds, autoPlay: true) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if finished {
                    self.logger.info("Seek to \(seconds)s completed")
                }
                // Hold isSeeking for 0.5s to allow decoder to present new keyframe
                // and prevent timeline from bouncing to old PTS
                self.seekTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if !Task.isCancelled {
                        self.isSeeking = false
                    }
                }
            }
        }
    }

    public func selectAudio(trackId: String) {
        guard let player = playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .audio)
        if let match = tracks.first(where: { String($0.trackID) == trackId }) {
            logger.info("Selecting audio track: \(trackId) (\(match.name))")
            player.select(track: match)
        }
    }

    public func selectSubtitle(trackId: String) {
        guard let player = playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .subtitle)
        if trackId == "off" {
            logger.info("Disabling subtitles")
            for t in tracks {
                t.isEnabled = false
            }
        } else {
            if let match = tracks.first(where: { String($0.trackID) == trackId }) {
                logger.info("Selecting subtitle track: \(trackId) (\(match.name))")
                player.select(track: match)
            }
        }
    }

    public func stop() {
        isSeeking = false
        pendingInitialSeek = nil
        playerLayer?.pause()
        playerLayer?.player.view?.removeFromSuperview()
        playerLayer = nil
        delegateBridge = nil
    }

    // MARK: - Delegate Bridge Handlers
    fileprivate func handleStateChange(layer: KSPlayerLayer, state: KSPlayerState) {
        self._state = state
        self.logger.debug("KSPlayer state: \(state.description)")
        if state == .readyToPlay {
            self.isSeeking = false
            if let av = (layer.player as? KSAVPlayer)?.player {
                av.automaticallyWaitsToMinimizeStalling = true
                av.currentItem?.preferredForwardBufferDuration = 30.0
            }
            if let videoView = layer.player.view {
                self.onVideoViewReady?(videoView)
            }
            if let seek = self.pendingInitialSeek {
                self.pendingInitialSeek = nil
                let cur = layer.player.currentPlaybackTime
                if abs(cur - seek) > 3.0 {
                    self.logger.info("ReadyToPlay: applying pending initial seek to \(seek)s (current is \(cur)s)")
                    layer.seek(time: seek, autoPlay: true) { _ in }
                }
            }
        }
    }

    fileprivate func handleTimeUpdate(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        if !isSeeking {
            self._currentTime = currentTime
        }
        self._duration = totalTime
    }

    fileprivate func handleFinish(layer: KSPlayerLayer, finish error: Error?) {
        self.isSeeking = false
        if let error {
            self.logger.error("KSPlayer playback finished with error: \(error)")
        } else {
            self.logger.info("KSPlayer playback finished successfully")
        }
    }
}
