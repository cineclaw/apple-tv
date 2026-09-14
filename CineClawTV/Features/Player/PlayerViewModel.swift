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

    func mountAndPlay(seek: Double?) async {
        isMounting = true
        mountStatusText = "Монтирование торрента в TorrServer..."
        errorMessage = nil

        do {
            _ = try await CineClawClient.shared.mountTorrent(
                tconst: tconst,
                title: release.title,
                magnet: release.magnet,
                hash: release.effectiveHash,
                type: (season != nil && season! > 0) ? "tvSeries" : "movie",
                season: season,
                episode: episode
            )

            var info: PlayerInfoResponse? = nil
            for attempt in 0..<6 {
                mountStatusText = attempt == 0 ? "Определение серии и подготовка потока..." : "Получение метаданных серии (\(attempt + 1)/6)..."
                do {
                    let candidate = try await CineClawClient.shared.getPlayerInfo(tconst: tconst, season: season, episode: episode)
                    if candidate.success == true && (candidate.directStreamUrl != nil || candidate.streamUrl != nil) {
                        info = candidate
                        break
                    }
                } catch {
                    logger.warning("getPlayerInfo attempt \(attempt + 1) error: \(error.localizedDescription)")
                }
                if attempt < 5 {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }

            if info == nil {
                info = try? await CineClawClient.shared.getPlayerInfo(tconst: tconst, season: season, episode: episode)
            }
            self.playerInfo = info

            // Direct MKV stream URL (Infuse / VLC native direct container streaming)
            let rawPath = info?.directStreamUrl ?? info?.streamUrl
            guard let path = rawPath, !path.isEmpty else {
                throw URLError(.badURL)
            }

            guard let streamURL = APIConfig.shared.torrServerURL(for: path) else {
                throw URLError(.badURL)
            }

            logger.info("Playing direct container stream: \(streamURL.absoluteString, privacy: .public)")

            let effectiveSeek = seek ?? info?.resumeSeconds ?? 0.0

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

    // Direct in-memory audio track selection (NO rebuffering, NO reload)
    func selectAudio(trackId: String, title: String? = nil) {
        logger.info("Direct audio switch requested: trackId='\(trackId)'")
        engine.selectAudio(trackId: trackId)

        if let t = title {
            Task {
                await CineClawClient.shared.setAudioPreference(imdbId: tconst, title: t)
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
        engine.stop()
    }
}
