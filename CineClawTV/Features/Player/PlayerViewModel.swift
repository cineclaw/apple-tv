import Foundation
import SwiftUI
import os

enum ActivePopover: Hashable, Sendable {
    case none
    case subtitles
    case audio
    case quality
}

@Observable
@MainActor
final class PlayerViewModel: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "PlayerViewModel")

    let tconst: String
    var release: TorrentRelease
    var customTitle: String?
    var season: Int?
    var episode: Int?

    let engine = KSPlayerEngine()
    let nowPlayingService = NowPlayingService()

    var isMounting: Bool = false
    var mountStatusText: String = "Подготовка видеопотока..."
    var playerInfo: PlayerInfoResponse?
    var errorMessage: String?

    // Transcoding State
    var isTranscoding: Bool = false
    var activeTranscodeProfile: String = APIConfig.shared.transcodeQuality
    var selectedAudioTrackIndex: Int = 0

    var showResumePrompt: Bool = false
    var resumeSeconds: Double = 0.0
    var autoResume: Bool = false

    // OSD and Controls State
    var showControls: Bool = false
    var showInfoSheet: Bool = false
    var activePopover: ActivePopover = .none
    var seekDeltaToast: String? = nil
    var pendingSeekTarget: Double? = nil

    var qualityGroups: [QualityGroup] = []
    var isLoadingTorrents: Bool = false

    var audioTracks: [AudioTrackOption] {
        if isTranscoding, let serverTracks = playerInfo?.audioTracks, !serverTracks.isEmpty {
            return serverTracks.map { track in
                AudioTrackOption(
                    id: String(track.index),
                    title: track.title,
                    language: track.language ?? "",
                    codec: track.codec ?? "",
                    channels: track.channels != nil ? "\(track.channels!)ch" : ""
                )
            }
        }
        return engine.audioTracks
    }

    var currentAudioTrackId: String {
        if isTranscoding {
            return String(selectedAudioTrackIndex)
        }
        return engine.currentAudioTrackId
    }

    var subtitleTracks: [SubtitleTrackOption] {
        engine.subtitleTracks
    }

    var currentSubtitleTrackId: String {
        engine.currentSubtitleTrackId
    }

    private var hideControlsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var periodicTimer: Timer?

    var isPlaying: Bool {
        engine.isPlaying
    }

    var currentTime: Double {
        if let target = pendingSeekTarget { return target }
        return engine.currentTime
    }

    var duration: Double {
        let d = engine.duration
        if d > 0 { return d }
        if let durSec = playerInfo?.durationSeconds, durSec > 0 { return durSec }
        return 0.0
    }

    var displayTitle: String {
        if let s = season, let e = episode, s > 0 && e > 0 {
            let base = customTitle ?? playerInfo?.title ?? release.title
            return "\(base) • Сезон \(s), Серия \(e)"
        }
        return customTitle ?? playerInfo?.title ?? release.title
    }

    init(
        tconst: String,
        title: String? = nil,
        release: TorrentRelease,
        season: Int? = nil,
        episode: Int? = nil,
        resumeSeconds: Double = 0.0,
        autoResume: Bool = false,
        qualityGroups: [QualityGroup] = []
    ) {
        self.tconst = tconst
        self.customTitle = title
        self.release = release
        self.season = season
        self.episode = episode
        self.resumeSeconds = resumeSeconds
        self.autoResume = autoResume
        self.qualityGroups = qualityGroups

        setupNowPlayingService()
    }

    private func setupNowPlayingService() {
        nowPlayingService.onPlay = { [weak self] in
            self?.play()
        }
        nowPlayingService.onPause = { [weak self] in
            self?.pause()
        }
        nowPlayingService.onTogglePlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        nowPlayingService.onSkipForward = { [weak self] interval in
            self?.seekRelative(seconds: interval)
        }
        nowPlayingService.onSkipBackward = { [weak self] interval in
            self?.seekRelative(seconds: -interval)
        }
        nowPlayingService.onSeek = { [weak self] target in
            self?.seek(to: target)
        }
        nowPlayingService.setup()
    }

    func start() async {
        if autoResume && resumeSeconds > 0 {
            await mountAndPlay(seek: resumeSeconds)
        } else if resumeSeconds > 60 {
            showResumePrompt = true
        } else {
            await mountAndPlay(seek: nil)
        }
    }

    func confirmResume() async {
        showResumePrompt = false
        await mountAndPlay(seek: resumeSeconds)
    }

    func startFromBeginning() async {
        showResumePrompt = false
        await mountAndPlay(seek: 0)
    }

    func determineShouldTranscode(info: PlayerInfoResponse?) -> Bool {
        switch APIConfig.shared.playbackMode {
        case .transcodeH264:
            return true
        case .direct:
            return false
        case .auto:
            if !DeviceCapabilities.supportsHardwareHEVC {
                let codec = (info?.videoCodec ?? "").lowercased()
                let isHevc = codec.contains("hevc") || codec.contains("h265") || codec.contains("x265")
                let is4K = (info?.width ?? 0) > 1920 || (info?.height ?? 0) > 1080
                let titleLower = release.title.lowercased()
                let titleHevc = titleLower.contains("hevc") || titleLower.contains("2160p") || titleLower.contains("x265") || titleLower.contains("h.265")
                return isHevc || is4K || titleHevc
            }
            let is4K = (info?.width ?? 0) > 3840
            return is4K
        }
    }

    func mountAndPlay(seek: Double?) async {
        isMounting = true
        mountStatusText = "Проверка состояния раздачи..."
        errorMessage = nil

        do {
            // 1. Check if server already has remembered/mounted stream for this title
            var info: PlayerInfoResponse? = try? await CineClawClient.shared.getPlayerInfo(tconst: tconst, season: season, episode: episode)

            let serverHash = info?.mediaSourceId ?? ""
            let hasActiveStream = info?.success == true && (info?.directStreamUrl?.isEmpty == false || info?.streamUrl?.isEmpty == false)
            let isDifferentRelease = !release.effectiveHash.isEmpty && !serverHash.isEmpty && serverHash.caseInsensitiveCompare(release.effectiveHash) != .orderedSame
            let needsMount = !hasActiveStream || isDifferentRelease

            if needsMount {
                mountStatusText = "Монтирование торрента в TorrServer..."
                _ = try await CineClawClient.shared.mountTorrent(
                    tconst: tconst,
                    title: release.title,
                    magnet: release.magnet,
                    hash: release.effectiveHash,
                    type: (season != nil && season! > 0) ? "tvSeries" : "movie",
                    season: season,
                    episode: episode
                )

                for attempt in 0..<10 {
                    mountStatusText = attempt == 0 ? "Определение серии и подготовка потока..." : "Получение метаданных серии (\(attempt + 1)/10)..."
                    do {
                        let candidate = try await CineClawClient.shared.getPlayerInfo(tconst: tconst, season: season, episode: episode)
                        if candidate.success == true && (candidate.directStreamUrl?.isEmpty == false || candidate.streamUrl?.isEmpty == false) {
                            info = candidate
                            break
                        }
                    } catch {
                        logger.warning("getPlayerInfo attempt \(attempt + 1) error: \(error.localizedDescription)")
                    }
                    if attempt < 9 {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                    }
                }
            } else if !serverHash.isEmpty && serverHash.caseInsensitiveCompare(release.effectiveHash) != .orderedSame {
                logger.info("Using remembered server source hash: \(serverHash, privacy: .public)")
            }

            if info == nil || info?.success != true {
                info = try? await CineClawClient.shared.getPlayerInfo(tconst: tconst, season: season, episode: episode)
            }
            self.playerInfo = info

            let effectiveSeek = seek ?? info?.resumeSeconds ?? 0.0
            let shouldTranscode = determineShouldTranscode(info: info)
            self.isTranscoding = shouldTranscode

            let streamURL: URL
            if shouldTranscode {
                self.activeTranscodeProfile = APIConfig.shared.transcodeQuality
                let targetAudio = selectedAudioTrackIndex
                let totalDur = info?.durationSeconds ?? duration
                let durParam = totalDur > 0 ? "&duration=\(String(format: "%.2f", totalDur))" : ""
                let startParam = effectiveSeek > 0 ? String(format: "%.2f", effectiveSeek) : "0"
                let targetHash = (info?.mediaSourceId?.isEmpty == false ? info?.mediaSourceId : nil) ?? release.effectiveHash
                let fileIdx = info?.targetFileIdx ?? 0
                guard !targetHash.isEmpty else {
                    throw NSError(domain: "CineClaw", code: -1002, userInfo: [NSLocalizedDescriptionKey: "Отсутствует хеш торрента для транскодирования"])
                }
                let transcodePath = "/api/stream/transcode/\(targetHash)/master.m3u8?profile=\(activeTranscodeProfile)&file_idx=\(fileIdx)&audio=\(targetAudio)&start=\(startParam)\(durParam)&s=\(UUID().uuidString.prefix(8))"
                guard let url = APIConfig.shared.streamURL(for: transcodePath) else {
                    throw NSError(domain: "CineClaw", code: -1000, userInfo: [NSLocalizedDescriptionKey: "Не удалось сформировать адрес потока транскодирования"])
                }
                streamURL = url
                logger.info("Playing H.264 transcoded stream: \(streamURL.absoluteString, privacy: .public)")
            } else {
                let rawPath = info?.directStreamUrl ?? info?.streamUrl
                guard let path = rawPath, !path.isEmpty else {
                    let errDetail = info?.error ?? "Торрент не успел запуститься в TorrServer. Попробуйте еще раз."
                    throw NSError(domain: "CineClaw", code: -1001, userInfo: [NSLocalizedDescriptionKey: errDetail])
                }
                guard let url = APIConfig.shared.streamURL(for: path) else {
                    throw NSError(domain: "CineClaw", code: -1000, userInfo: [NSLocalizedDescriptionKey: "Не удалось сформировать адрес видеопотока (\(path))"])
                }
                streamURL = url
                logger.info("Playing direct container stream: \(streamURL.absoluteString, privacy: .public)")
            }

            self.isMounting = false
            self.engine.load(url: streamURL, initialSeek: effectiveSeek > 2.0 ? effectiveSeek : nil)

            startPeriodicTimer()
            userActivity()

            // Preload other quality releases in background if not provided
            Task {
                await loadQualityGroupsIfNeeded()
            }
        } catch {
            self.logger.error("Failed to mount torrent: \(error.localizedDescription)")
            self.errorMessage = "Не удалось запустить видеопоток: \(error.localizedDescription)"
            self.isMounting = false
        }
    }

    private func startPeriodicTimer() {
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.onPeriodicTick()
            }
        }
    }

    private func onPeriodicTick() {
        let cur = engine.currentTime
        let dur = duration
        let playing = engine.isPlaying

        if let target = pendingSeekTarget {
            if abs(cur - target) <= 2.0 {
                pendingSeekTarget = nil
            }
        }

        // 1. Sync now playing metadata to Apple TV / iOS Lock Screen
        nowPlayingService.updateNowPlaying(
            title: displayTitle,
            season: season,
            episode: episode,
            currentTime: cur,
            duration: dur,
            isPlaying: playing
        )

        // 2. Report progress to CineClaw backend
        if cur > 2 && dur > 0 {
            reportProgress(cur: cur, dur: dur, isPlaying: playing)
        }
    }

    func play() {
        engine.play()
        userActivity()
        onPeriodicTick()
    }

    func pause() {
        engine.pause()
        showControls = true
        hideControlsTask?.cancel()
        onPeriodicTick()
    }

    func togglePlayPause() {
        if engine.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        pendingSeekTarget = seconds
        engine.seek(to: seconds)
        userActivity()
    }

    func seekRelative(seconds delta: Double) {
        let cur = currentTime
        let dur = duration > 0 ? duration : 7200.0
        let target = max(0.0, min(dur, cur + delta))
        seek(to: target)

        let sign = delta >= 0 ? "+" : ""
        showToast("\(sign)\(Int(delta))с")
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        seekDeltaToast = text
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled {
                self.seekDeltaToast = nil
            }
        }
    }

    func userActivity() {
        hideControlsTask?.cancel()

        // If controls are hidden or popover is open, do not auto-hide immediately
        guard showControls && activePopover == .none else { return }

        // Only auto-hide if currently playing
        if engine.isPlaying {
            hideControlsTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled && self.engine.isPlaying && self.activePopover == .none {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.showControls = false
                    }
                }
            }
        }
    }

    func openPopover(_ popover: ActivePopover) {
        if activePopover == popover {
            activePopover = .none
            userActivity()
        } else {
            activePopover = popover
            hideControlsTask?.cancel()
        }
    }

    func closePopover() {
        activePopover = .none
        userActivity()
    }

    // Audio track selection (in-memory for direct, seamless stream reload for transcode)
    func selectAudio(trackId: String, title: String? = nil) {
        logger.info("Audio switch requested: trackId='\(trackId)', title='\(title ?? "")'")
        if isTranscoding {
            guard let idx = Int(trackId) else { return }
            if idx != selectedAudioTrackIndex {
                selectedAudioTrackIndex = idx
                let cur = engine.currentTime
                let targetHash = playerInfo?.mediaSourceId ?? release.effectiveHash
                let fileIdx = playerInfo?.targetFileIdx ?? 0
                let totalDur = playerInfo?.durationSeconds ?? duration
                let durParam = totalDur > 0 ? "&duration=\(String(format: "%.2f", totalDur))" : ""
                let transcodePath = "/api/stream/transcode/\(targetHash)/master.m3u8?profile=\(activeTranscodeProfile)&file_idx=\(fileIdx)&audio=\(idx)&start=\(String(format: "%.2f", cur))\(durParam)&s=\(UUID().uuidString.prefix(8))"
                if let url = APIConfig.shared.streamURL(for: transcodePath) {
                    logger.info("Switching transcode audio to track \(idx): \(url.absoluteString, privacy: .public)")
                    if let t = title {
                        showToast(t)
                    }
                    engine.switchStream(url: url, initialSeek: cur > 2.0 ? cur : nil)
                }
            }
        } else {
            engine.selectAudio(trackId: trackId)
            if let t = title {
                showToast(t)
            }
        }

        if let t = title {
            Task {
                await CineClawClient.shared.setAudioPreference(imdbId: tconst, title: t)
            }
        }
    }

    func switchTranscodeMode(enableTranscode: Bool, profile: String = "1080p") {
        guard enableTranscode != isTranscoding || profile != activeTranscodeProfile else { return }
        let cur = engine.currentTime
        self.isTranscoding = enableTranscode
        self.activeTranscodeProfile = profile
        if enableTranscode {
            APIConfig.shared.playbackMode = .transcodeH264
            APIConfig.shared.transcodeQuality = profile
            let targetAudio = selectedAudioTrackIndex
            let totalDur = playerInfo?.durationSeconds ?? duration
            let durParam = totalDur > 0 ? "&duration=\(String(format: "%.2f", totalDur))" : ""
            let targetHash = playerInfo?.mediaSourceId ?? release.effectiveHash
            let fileIdx = playerInfo?.targetFileIdx ?? 0
            let transcodePath = "/api/stream/transcode/\(targetHash)/master.m3u8?profile=\(profile)&file_idx=\(fileIdx)&audio=\(targetAudio)&start=\(String(format: "%.2f", cur))\(durParam)&s=\(UUID().uuidString.prefix(8))"
            if let url = APIConfig.shared.streamURL(for: transcodePath) {
                logger.info("Switching to transcoded stream: \(url.absoluteString, privacy: .public)")
                engine.switchStream(url: url, initialSeek: cur > 2.0 ? cur : nil)
            }
        } else {
            APIConfig.shared.playbackMode = .direct
            let rawPath = playerInfo?.directStreamUrl ?? playerInfo?.streamUrl ?? ""
            if let url = APIConfig.shared.streamURL(for: rawPath) {
                logger.info("Switching to direct stream: \(url.absoluteString, privacy: .public)")
                engine.load(url: url, initialSeek: cur > 2.0 ? cur : nil)
            }
        }
    }

    // Direct in-memory subtitle track selection
    func selectSubtitle(trackId: String) {
        logger.info("Direct subtitle switch requested: trackId='\(trackId)'")
        engine.selectSubtitle(trackId: trackId)
    }

    func switchQuality(to newRelease: TorrentRelease) async {
        guard newRelease.effectiveHash != release.effectiveHash else { return }
        let cur = engine.currentTime
        logger.info("Switching quality to '\(newRelease.title)' at pos=\(cur)s")
        self.release = newRelease
        self.activePopover = .none
        await mountAndPlay(seek: cur)
    }

    func startScrubbing(initialTime: Double) {
        pendingSeekTarget = initialTime
        hideControlsTask?.cancel()
    }

    func updateScrubTime(_ time: Double) {
        pendingSeekTarget = time
    }

    func commitScrub(to time: Double) {
        pendingSeekTarget = time
        engine.seek(to: time)
        userActivity()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self?.pendingSeekTarget == time {
                self?.pendingSeekTarget = nil
            }
        }
    }

    func cancelScrub() {
        pendingSeekTarget = nil
        userActivity()
    }

    func reportProgress(cur: Double, dur: Double, isPlaying: Bool) {
        guard cur > 2 && dur > 0 else { return }
        let percent = (cur / dur) * 100.0
        let tc = tconst
        let title = customTitle ?? playerInfo?.title ?? release.title
        let s = season
        let e = episode
        let isTv = (s != nil && s! > 0) || (playerInfo?.mediaType == "tv")

        Task {
            await CineClawClient.shared.reportProgress(
                tconst: tc,
                title: title,
                isTv: isTv,
                season: s,
                episode: e,
                position: cur,
                duration: dur,
                percent: percent
            )
        }
    }

    func loadQualityGroupsIfNeeded() async {
        guard qualityGroups.isEmpty else { return }
        isLoadingTorrents = true
        do {
            let imdbIdParam = tconst.hasPrefix("tt") ? tconst : nil
            let list = try await CineClawClient.shared.getTorrents(imdbId: imdbIdParam, query: playerInfo?.title ?? release.title)
            self.qualityGroups = groupReleases(list)
        } catch {
            logger.error("Failed to load quality groups for player: \(error.localizedDescription)")
        }
        isLoadingTorrents = false
    }

    private func groupReleases(_ list: [TorrentRelease]) -> [QualityGroup] {
        TorrentSelectionHelper.groupReleases(list)
    }

    func stop() {
        let cur = engine.currentTime
        let dur = duration
        if cur > 2 && dur > 0 {
            reportProgress(cur: cur, dur: dur, isPlaying: false)
        }
        periodicTimer?.invalidate()
        periodicTimer = nil
        hideControlsTask?.cancel()
        toastTask?.cancel()
        nowPlayingService.teardown()
        if isTranscoding {
            let targetHash = playerInfo?.mediaSourceId ?? release.effectiveHash
            Task {
                await CineClawClient.shared.stopTranscoding(hash: targetHash)
            }
        }
        engine.stop()
    }
}
