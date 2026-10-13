import Foundation
import UIKit
import SwiftUI
import os
import Combine
import VideoPlayerCore
internal import AetherEngine
import AVFoundation

@Observable
@MainActor
public final class AetherPlayerEngine: NSObject, VideoPlayerEngine {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "AetherPlayerEngine")

    // MARK: - Video Surface
    private let playerView = AetherPlayerView()
    public var onVideoViewReady: ((UIView) -> Void)?

    public var videoSurfaceView: UIView? {
        playerView
    }

    // MARK: - Subtitles UI
    private let subtitleContainer = UIView()
    private let subtitleLabel = UILabel()

    // MARK: - Engine Lifecycle
    private static var sharedEngine: AetherEngine? = {
        do {
            return try AetherEngine()
        } catch {
            print("[AetherPlayerEngine] Failed to initialize shared AetherEngine: \(error)")
            return nil
        }
    }()

    private let engine: AetherEngine?
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var seekTask: Task<Void, Never>?

    // MARK: - State Properties
    private var _isPlaying: Bool = false
    private var _isBuffering: Bool = false
    private var _currentTime: Double = 0.0
    private var _duration: Double = 0.0
    private var _audioTracks: [AudioTrackOption] = []
    private var _subtitleTracks: [SubtitleTrackOption] = []
    private var _currentAudioTrackId: String = ""
    private var _currentSubtitleTrackId: String = "off"

    public var isPlaying: Bool { _isPlaying }
    public var isBuffering: Bool { _isBuffering }
    public var currentTime: Double { _currentTime }
    public var duration: Double { _duration }
    public var audioTracks: [AudioTrackOption] { _audioTracks }
    public var subtitleTracks: [SubtitleTrackOption] { _subtitleTracks }
    public var currentAudioTrackId: String { _currentAudioTrackId }
    public var currentSubtitleTrackId: String { _currentSubtitleTrackId }

    public override init() {
        if let shared = Self.sharedEngine {
            self.engine = shared
        } else {
            self.engine = try? AetherEngine()
        }
        super.init()

        setupSubtitleOverlay()

        if let eng = self.engine {
            eng.bind(view: playerView)
            setupSubscriptions(eng)
        } else {
            logger.error("AetherEngine could not be initialized")
        }
    }

    // MARK: - Subtitle Overlay
    private func setupSubtitleOverlay() {
        subtitleContainer.translatesAutoresizingMaskIntoConstraints = false
        subtitleContainer.isUserInteractionEnabled = false
        subtitleContainer.backgroundColor = .clear

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = .white
        subtitleLabel.font = UIFont.systemFont(ofSize: 42, weight: .bold)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.shadowColor = UIColor.black
        subtitleLabel.shadowOffset = CGSize(width: 2, height: 2)
        subtitleLabel.layer.shadowRadius = 4
        subtitleLabel.layer.shadowOpacity = 0.9

        subtitleContainer.addSubview(subtitleLabel)
        playerView.addSubview(subtitleContainer)

        NSLayoutConstraint.activate([
            subtitleContainer.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 80),
            subtitleContainer.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -80),
            subtitleContainer.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -90),

            subtitleLabel.topAnchor.constraint(equalTo: subtitleContainer.topAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: subtitleContainer.bottomAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: subtitleContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: subtitleContainer.trailingAnchor),
        ])
    }

    // MARK: - Subscriptions
    private func setupSubscriptions(_ eng: AetherEngine) {
        eng.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self._isPlaying = (state == .playing)
                self._isBuffering = (state == .loading || eng.isBuffering || eng.isSeeking)
                self.logger.debug("AetherEngine state: \(String(describing: state))")

                if case .error(let msg) = state {
                    self.logger.error("AetherEngine playback error: \(msg)")
                }
            }
            .store(in: &cancellables)

        eng.$isBuffering
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buffering in
                guard let self else { return }
                self._isBuffering = buffering || eng.state == .loading || eng.isSeeking
            }
            .store(in: &cancellables)

        eng.$isSeeking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seeking in
                guard let self else { return }
                self._isBuffering = seeking || eng.state == .loading || eng.isBuffering
            }
            .store(in: &cancellables)

        eng.clock.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cur in
                guard let self else { return }
                if !eng.isSeeking {
                    self._currentTime = cur
                }
                self.updateSubtitleDisplay(cues: eng.subtitleCues, currentTime: cur)
            }
            .store(in: &cancellables)

        eng.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                self?._duration = dur
            }
            .store(in: &cancellables)

        eng.$audioTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                self._audioTracks = tracks.map { track in
                    let ch = track.channels > 0 ? "\(track.channels)ch" : ""
                    return AudioTrackOption(
                        id: String(track.id),
                        title: track.name,
                        language: track.language ?? "",
                        codec: track.codec,
                        channels: ch
                    )
                }
            }
            .store(in: &cancellables)

        eng.$activeAudioTrackIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] idx in
                guard let self else { return }
                if let idx {
                    self._currentAudioTrackId = String(idx)
                } else {
                    self._currentAudioTrackId = self._audioTracks.first?.id ?? ""
                }
            }
            .store(in: &cancellables)

        eng.$subtitleTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tracks in
                guard let self else { return }
                var list = [
                    SubtitleTrackOption(id: "off", title: "Выключить субтитры", language: "")
                ]
                list.append(contentsOf: tracks.map { track in
                    SubtitleTrackOption(
                        id: String(track.id),
                        title: track.name.isEmpty ? (track.language ?? "Субтитры") : track.name,
                        language: track.language ?? ""
                    )
                })
                self._subtitleTracks = list
            }
            .store(in: &cancellables)

        eng.$activeSubtitleTrackIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] idx in
                guard let self else { return }
                if let idx {
                    self._currentSubtitleTrackId = String(idx)
                } else {
                    self._currentSubtitleTrackId = "off"
                }
            }
            .store(in: &cancellables)

        eng.$subtitleCues
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cues in
                guard let self else { return }
                self.updateSubtitleDisplay(cues: cues, currentTime: self._currentTime)
            }
            .store(in: &cancellables)
    }

    private func updateSubtitleDisplay(cues: [SubtitleCue], currentTime: Double) {
        if cues.isEmpty || _currentSubtitleTrackId == "off" {
            subtitleLabel.text = nil
            return
        }
        let active = cues.filter { $0.startTime <= currentTime && currentTime <= $0.endTime }
        let text = active.compactMap { $0.text }.joined(separator: "\n")
        subtitleLabel.text = text.isEmpty ? nil : text
    }

    // MARK: - Audio Track Auto-Selection
    static func selectBestAudioTrack(tracks: [TrackInfo], preferredTitle: String? = nil) -> TrackInfo? {
        guard !tracks.isEmpty else { return nil }

        let prefLower = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        // 1. Exact title match
        if !prefLower.isEmpty {
            if let exact = tracks.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == prefLower }) {
                return exact
            }
        }

        // 2. Studio / author keywords match with preferredTitle
        if !prefLower.isEmpty {
            let studioKeywords = [
                "гоблин", "goblin", "пучков",
                "сербин", "serbin",
                "amedia", "амедиа",
                "нтв", "ntv",
                "fox",
                "карповский", "боровой",
                "lostfilm", "лостфильм",
                "hdrezka", "резка",
                "кубик", "kubik",
                "дубляж", "дублированный", "dub",
                "newstudio", "ньюстудио",
                "кураж", "kuraj",
                "red head sound", "rhs",
                "пифагор", "мост-видео", "инис",
                "живов", "гаврилов", "михалев", "володарский",
                "novamedia", "новамедиа", "кириллица", "захаров",
                "английский", "english", "original"
            ]

            for kw in studioKeywords {
                if prefLower.contains(kw) {
                    if let matched = tracks.first(where: { $0.name.lowercased().contains(kw) }) {
                        return matched
                    }
                }
            }
        }

        // 3. Fallback: Quality heuristic ranking
        func score(track: TrackInfo) -> Int {
            var s = 0
            let lang = (track.language ?? "").lowercased()
            let name = track.name.lowercased()

            let isRussian = lang == "ru" || lang == "rus" || lang == "russian" ||
                name.contains("рус") || name.contains("дубл") || name.contains("мво") ||
                name.contains("дб") || name.contains("пд") || name.contains("полное")

            if isRussian {
                s += 1000
            } else if lang.isEmpty || lang == "und" {
                if name.isEmpty {
                    s += 200
                }
            } else if lang == "en" || lang == "eng" || lang == "english" {
                s += 50
            }

            // High-quality Russian studios / dubs
            if name.contains("дубляж") || name.contains("дублированный") {
                s += 300
            } else if name.contains("red head sound") || name.contains("rhs") {
                s += 280
            } else if name.contains("hdrezka") {
                s += 260
            } else if name.contains("lostfilm") {
                s += 250
            } else if name.contains("кубик") {
                s += 250
            } else if name.contains("мво") || name.contains("многоголос") {
                s += 200
            } else if name.contains("line") || name.contains("чистый звук") {
                s += 100
            }

            // Channel count bonus: 5.1/7.1 > stereo
            if track.channels >= 8 {
                s += 150
            } else if track.channels >= 6 {
                s += 120
            } else if track.channels >= 2 {
                s += 40
            }

            // Codec bonus: modern surround > AAC
            let codec = track.codec.lowercased()
            if codec.contains("eac3") || codec.contains("ec-3") || codec.contains("atmos") {
                s += 50
            } else if codec.contains("truehd") || codec.contains("dts-hd") || codec.contains("flac") {
                s += 45
            } else if codec.contains("ac3") || codec.contains("dts") {
                s += 30
            } else if codec.contains("aac") {
                s += 10
            }

            if track.isDefault {
                s += 15
            }

            return s
        }

        return tracks.max(by: { score(track: $0) < score(track: $1) })
    }

    // MARK: - VideoPlayerEngine API
    public func load(url: URL, initialSeek: Double?) {
        load(url: url, initialSeek: initialSeek, preferredAudio: nil)
    }

    public func load(url: URL, initialSeek: Double?, preferredAudio: String?) {
        guard let engine else {
            logger.error("Cannot load stream: AetherEngine is nil")
            return
        }
        logger.info("Loading stream with AetherEngine: \(url.absoluteString, privacy: .public), initialSeek: \(initialSeek ?? 0), preferredAudio: \(preferredAudio ?? "none")")

        stop()
        engine.bind(view: playerView)
        onVideoViewReady?(playerView)

        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var options = LoadOptions()
                options.matchContentEnabled = true
                options.preferredAudioLanguages = ["ru", "rus", "Russian"]

                var targetAudioStreamIndex: Int32? = nil

                // Fast pre-probe container to select the best audio track upfront
                let probeOptions = LoadOptions()
                let probeURL = url
                let probeLimits = ProbeLimits(
                    maxInputBytes: 8 * 1024 * 1024,
                    maxPackets: 128,
                    maxPacketBytes: 2 * 1024 * 1024,
                    timeBudget: 1.5
                )

                let probeResult: SourceProbe? = await Task.detached { () -> SourceProbe? in
                    do {
                        return try AetherEngine.probe(url: probeURL, options: probeOptions, limits: probeLimits)
                    } catch {
                        return nil
                    }
                }.value

                if let probe = probeResult, !probe.audioTracks.isEmpty {
                    if let matched = Self.selectBestAudioTrack(tracks: probe.audioTracks, preferredTitle: preferredAudio) {
                        targetAudioStreamIndex = Int32(matched.id)
                        self.logger.info("Pre-probe selected audio stream [\(matched.id)]: '\(matched.name)' (\(matched.language ?? "und"), \(matched.channels)ch)")
                    }
                }

                let seek = (initialSeek != nil && initialSeek! > 2.0) ? initialSeek : nil
                _ = try await self.engine?.load(
                    url: url,
                    startPosition: seek,
                    options: options,
                    audioSourceStreamIndex: targetAudioStreamIndex
                )
                self.engine?.play()
                self.logger.info("AetherEngine playback started successfully (audio stream: \(targetAudioStreamIndex?.description ?? "default"))")
            } catch is CancellationError {
                // Cancelled
            } catch {
                self.logger.error("AetherEngine load failed: \(error.localizedDescription)")
            }
        }
    }

    public func switchStream(url: URL, initialSeek: Double?) {
        load(url: url, initialSeek: initialSeek, preferredAudio: nil)
    }

    public func switchStream(url: URL, initialSeek: Double?, preferredAudio: String?) {
        load(url: url, initialSeek: initialSeek, preferredAudio: preferredAudio)
    }

    public func play() {
        engine?.play()
    }

    public func pause() {
        engine?.pause()
    }

    public func togglePlayPause() {
        engine?.togglePlayPause()
    }

    public func seek(to seconds: Double) {
        guard engine != nil else { return }
        logger.info("Seeking to \(seconds)s")
        _currentTime = seconds
        seekTask?.cancel()
        seekTask = Task { @MainActor [weak self] in
            await self?.engine?.seek(to: seconds)
        }
    }

    public func selectAudio(trackId: String) {
        guard let engine, let id = Int(trackId) else { return }
        logger.info("Selecting audio track: \(trackId)")
        engine.selectAudioTrack(index: id)
    }

    public func selectSubtitle(trackId: String) {
        guard let engine else { return }
        if trackId == "off" {
            logger.info("Disabling subtitles")
            engine.clearSubtitle()
            subtitleLabel.text = nil
        } else if let id = Int(trackId) {
            logger.info("Selecting subtitle track: \(trackId)")
            engine.selectSubtitleTrack(index: id)
        }
    }

    public func stop() {
        logger.info("Stopping AetherEngine playback")
        loadTask?.cancel()
        seekTask?.cancel()
        subtitleLabel.text = nil
        engine?.stop()
        engine?.unbind(view: playerView)
    }
}
