import Foundation
import UIKit
import SwiftUI
import os
@preconcurrency import KSPlayer
import AVFoundation


@Observable
@MainActor
final class KSPlayerEngine: NSObject, VideoPlayerEngine, KSPlayerLayerDelegate {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "KSPlayerEngine")

    private(set) var playerLayer: KSPlayerLayer?
    var onVideoViewReady: ((UIView) -> Void)?

    private var _currentTime: Double = 0.0
    private var _duration: Double = 0.0
    private var _state: KSPlayerState = .initialized
    private var isSeeking: Bool = false
    private var seekTargetTime: Double = 0.0
    private var seekTask: Task<Void, Never>?
    private var pendingInitialSeek: Double? = nil

    override init() {
        super.init()
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

    var isPlaying: Bool {
        if let player = playerLayer?.player {
            return player.playbackState == .playing
        }
        return _state.isPlaying
    }

    var isBuffering: Bool {
        _state == .buffering || _state == .preparing
    }

    var currentTime: Double {
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

    var duration: Double {
        if let player = playerLayer?.player, player.duration > 0 {
            return player.duration
        }
        return _duration
    }

    var audioTracks: [AudioTrackOption] {
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

    var subtitleTracks: [SubtitleTrackOption] {
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

    var currentAudioTrackId: String {
        guard let player = playerLayer?.player else { return "" }
        let tracks = player.tracks(mediaType: .audio)
        if let enabled = tracks.first(where: { $0.isEnabled }) {
            return String(enabled.trackID)
        }
        return tracks.first.map { String($0.trackID) } ?? ""
    }

    var currentSubtitleTrackId: String {
        guard let player = playerLayer?.player else { return "off" }
        let tracks = player.tracks(mediaType: .subtitle)
        if let enabled = tracks.first(where: { $0.isEnabled }) {
            return String(enabled.trackID)
        }
        return "off"
    }

    func load(url: URL, initialSeek: Double?) {
        logger.info("Loading stream with KSPlayer: \(url.absoluteString, privacy: .public), initialSeek: \(initialSeek ?? 0)")

        stop()
        configurePlayerTypes(for: url)

        let options = KSOptions()
        options.hardwareDecode = true
        options.asynchronousDecompression = true
        options.isAccurateSeek = false
        options.preferredForwardBufferDuration = 0.0
        options.maxBufferDuration = 90.0
        options.seekFlags = 1 // AVSEEK_FLAG_BACKWARD

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

        let layer = KSPlayerLayer(url: url, isAutoPlay: true, options: options, delegate: self)
        self.playerLayer = layer

        if let av = (layer.player as? KSAVPlayer)?.player {
            av.automaticallyWaitsToMinimizeStalling = true
        }

        if let videoView = layer.player.view {
            onVideoViewReady?(videoView)
        }
    }

    func switchStream(url: URL, initialSeek: Double?) {
        guard let layer = playerLayer else {
            load(url: url, initialSeek: initialSeek)
            return
        }
        logger.info("Switching stream in-place: \(url.absoluteString, privacy: .public), initialSeek: \(initialSeek ?? 0)")
        configurePlayerTypes(for: url)

        let isHLS = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains(".m3u8")

        let options = KSOptions()
        options.hardwareDecode = true
        options.asynchronousDecompression = true
        options.isAccurateSeek = false
        options.preferredForwardBufferDuration = 0.0
        options.maxBufferDuration = 90.0
        options.seekFlags = 1 // AVSEEK_FLAG_BACKWARD
        options.probesize = 1024 * 1024 // 1 MB
        options.maxAnalyzeDuration = 500_000 // 0.5s
        options.autoSelectEmbedSubtitle = false

        if let seek = initialSeek, seek > 2.0 {
            options.startPlayTime = seek
            _currentTime = seek
            seekTargetTime = seek
            pendingInitialSeek = isHLS ? nil : seek
        }

        layer.set(url: url, options: options)
        if let av = (layer.player as? KSAVPlayer)?.player {
            av.automaticallyWaitsToMinimizeStalling = true
        }
    }

    func play() {
        playerLayer?.play()
    }

    func pause() {
        playerLayer?.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
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

    func selectAudio(trackId: String) {
        guard let player = playerLayer?.player else { return }
        let tracks = player.tracks(mediaType: .audio)
        if let match = tracks.first(where: { String($0.trackID) == trackId }) {
            logger.info("Selecting audio track: \(trackId) (\(match.name))")
            player.select(track: match)
        }
    }

    func selectSubtitle(trackId: String) {
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

    func stop() {
        isSeeking = false
        pendingInitialSeek = nil
        playerLayer?.pause()
        playerLayer?.player.view?.removeFromSuperview()
        playerLayer = nil
    }

    // MARK: - KSPlayerLayerDelegate
    func player(layer: KSPlayerLayer, state: KSPlayerState) {
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

    func player(layer: KSPlayerLayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        if !isSeeking {
            self._currentTime = currentTime
        }
        self._duration = totalTime
    }

    func player(layer: KSPlayerLayer, finish error: Error?) {
        self.isSeeking = false
        if let error {
            self.logger.error("KSPlayer playback finished with error: \(error)")
        } else {
            self.logger.info("KSPlayer playback finished successfully")
        }
    }

    func player(layer: KSPlayerLayer, bufferedCount: Int, consumeTime: TimeInterval) {
        // Buffering telemetry
    }
}
