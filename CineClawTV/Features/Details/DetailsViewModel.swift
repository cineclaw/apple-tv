import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class DetailsViewModel {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "DetailsVM")

    let rawTconst: String
    var effectiveTconst: String
    var initialTitle: String?
    var homeItem: HomeItem?

    var isLoading: Bool = true
    var metadata: MovieMetadataResponse?
    var seasons: [SeasonInfo] = []
    var selectedSeasonNumber: Int = 1
    var episodes: [EpisodeInfo] = []
    var isLoadingEpisodes: Bool = false

    var criticSummary: CriticSummaryResponse?
    var isLoadingCritics: Bool = false
    var hasCriticsFailed: Bool = false

    var seriesProgress: SeriesProgressResponse? = nil
    var isLoadingSeriesProgress: Bool = false

    var torrents: [TorrentRelease] = []
    var qualityGroups: [QualityGroup] = []
    var selectedRelease: TorrentRelease?
    var isLoadingTorrents: Bool = true
    var inWatchlist: Bool = false

    var isTv: Bool {
        if let hi = homeItem, hi.isTv { return true }
        return !seasons.isEmpty
    }

    init(item: HomeItem) {
        self.rawTconst = item.effectiveTconst
        self.effectiveTconst = item.effectiveTconst
        self.initialTitle = item.title
        self.homeItem = item

        // Instant pre-population from HomeItem - zero blank screen!
        self.metadata = MovieMetadataResponse(
            tconst: item.effectiveTconst,
            title: item.title,
            originalTitle: item.originalTitle,
            year: item.year,
            rating: item.rating,
            voteCount: item.voteCount,
            overview: item.overview,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            genres: [],
            runtimeMinutes: nil,
            cast: [],
            crew: [],
            backdrops: [],
            trailerYoutubeId: nil
        )
    }

    init(tconst: String, initialTitle: String? = nil) {
        self.rawTconst = tconst
        self.effectiveTconst = tconst
        self.initialTitle = initialTitle
        self.homeItem = nil
    }

    func loadDetails() async {
        isLoading = true
        isLoadingTorrents = true

        // 1. Resolve real IMDb tconst if this is a TMDB ID
        await resolveRealTconstIfNeeded()

        // 2. Start AI critics synthesis independently in background (never block page rendering)
        Task { [weak self] in
            await self?.fetchCritics()
        }

        // 3. Concurrently fetch full metadata, torrents, watchlist
        async let metaTask: Void = fetchMetadata()
        async let torrentTask: Void = fetchTorrents()
        async let watchlistTask: Void = checkWatchlist()

        _ = await (metaTask, torrentTask, watchlistTask)
        isLoading = false
    }

    private func resolveRealTconstIfNeeded() async {
        // If already tt..., nothing to resolve
        if effectiveTconst.hasPrefix("tt") {
            return
        }

        let tmdbId: Int64 = {
            if let hi = homeItem, let id = hi.tmdbId, id > 0 {
                return id
            }
            let cleaned = rawTconst.replacingOccurrences(of: "tmdb_", with: "")
            return Int64(cleaned) ?? 0
        }()

        guard tmdbId > 0 else { return }

        let mediaType = (homeItem?.isTv == true) ? "tv" : "movie"
        do {
            let res = try await CineClawClient.shared.resolveTmdb(mediaType: mediaType, tmdbId: tmdbId)
            if !res.tconst.isEmpty && res.tconst.hasPrefix("tt") {
                logger.info("Resolved TMDB \(tmdbId) -> \(res.tconst, privacy: .public)")
                self.effectiveTconst = res.tconst
                if self.initialTitle == nil || self.initialTitle?.isEmpty == true {
                    self.initialTitle = res.titleRu ?? res.titleOrig
                }
            }
        } catch {
            logger.warning("Failed to resolve TMDB \(tmdbId): \(error.localizedDescription)")
        }
    }

    private func fetchMetadata() async {
        guard effectiveTconst.hasPrefix("tt") else { return }
        do {
            let meta = try await CineClawClient.shared.getMovieMetadata(tconst: effectiveTconst)
            self.metadata = meta
            if self.initialTitle == nil || self.initialTitle?.isEmpty == true {
                self.initialTitle = meta.title
            }

            // Check if series by loading seasons
            let sList = (try? await CineClawClient.shared.getSeriesSeasons(tconst: effectiveTconst)) ?? []
            self.seasons = sList
            if let first = sList.first {
                self.selectedSeasonNumber = first.seasonNumber
            }
            if !sList.isEmpty {
                self.isLoadingEpisodes = true
                do {
                    let all = try await CineClawClient.shared.getSeriesEpisodes(tconst: effectiveTconst)
                    self.allEpisodes = all
                    self.episodes = all.filter { $0.seasonNumber == self.selectedSeasonNumber }
                    await fetchSeriesProgress()
                } catch {
                    self.logger.error("Failed to load episodes: \(error.localizedDescription)")
                }
                self.isLoadingEpisodes = false
            }
        } catch {
            self.logger.error("Failed to load metadata for \(self.effectiveTconst): \(error.localizedDescription)")
        }
    }

    private var allEpisodes: [EpisodeInfo] = []

    func fetchSeriesProgress() async {
        guard effectiveTconst.hasPrefix("tt") else { return }
        isLoadingSeriesProgress = true
        do {
            let prog = try await CineClawClient.shared.getSeriesProgress(imdbId: effectiveTconst)
            self.seriesProgress = prog
            applyProgressToEpisodes(prog)
        } catch {
            self.logger.warning("Failed to fetch series progress: \(error.localizedDescription)")
        }
        isLoadingSeriesProgress = false
    }

    private func applyProgressToEpisodes(_ prog: SeriesProgressResponse) {
        guard !allEpisodes.isEmpty else { return }
        self.allEpisodes = allEpisodes.map { ep in
            let key = "\(ep.seasonNumber)_\(ep.episodeNumber)"
            let status = prog.episodes[key]
            let isPlayed = status?.isCompleted ?? false
            let resumeSec = status?.positionSeconds ?? ep.resumeSeconds
            return EpisodeInfo(
                seasonNumber: ep.seasonNumber,
                episodeNumber: ep.episodeNumber,
                name: ep.name,
                overview: ep.overview,
                stillPath: ep.stillPath,
                airDate: ep.airDate,
                runtime: ep.runtime,
                voteAverage: ep.voteAverage,
                resumeSeconds: resumeSec,
                isPlayed: isPlayed
            )
        }
        self.episodes = allEpisodes.filter { $0.seasonNumber == self.selectedSeasonNumber }
    }

    func seasonSummary(seasonNumber: Int) -> SeasonProgressSummary? {
        seriesProgress?.seasons["\(seasonNumber)"]
    }

    func isEpisodeWatched(season: Int, episode: Int) -> Bool {
        let keyUnderscore = "\(season)_\(episode)"
        let keyX = "\(season)x\(episode)"
        return seriesProgress?.episodes[keyX]?.isCompleted == true || seriesProgress?.episodes[keyUnderscore]?.isCompleted == true
    }

    func hasUnwatchedPrior(season: Int, episode: Int) -> Bool {
        // If series has episodes loaded, check if any episode before (season, episode) is unwatched
        for ep in allEpisodes {
            if ep.seasonNumber <= 0 { continue }
            if ep.seasonNumber < season || (ep.seasonNumber == season && ep.episodeNumber < episode) {
                if !isEpisodeWatched(season: ep.seasonNumber, episode: ep.episodeNumber) {
                    return true
                }
            }
        }
        return false
    }

    func markEpisodeWatched(season: Int, episode: Int, completed: Bool) async {
        do {
            try await CineClawClient.shared.markWatched(
                imdbId: effectiveTconst,
                mode: "episode",
                title: metadata?.title ?? initialTitle,
                season: season,
                episode: episode,
                completed: completed
            )
            await fetchSeriesProgress()
        } catch {
            logger.error("Failed to mark episode \(season)x\(episode) watched: \(error.localizedDescription)")
        }
    }

    func markSeasonWatched(season: Int, completed: Bool) async {
        do {
            try await CineClawClient.shared.markWatched(
                imdbId: effectiveTconst,
                mode: "season",
                title: metadata?.title ?? initialTitle,
                season: season,
                completed: completed
            )
            await fetchSeriesProgress()
        } catch {
            logger.error("Failed to mark season \(season) watched: \(error.localizedDescription)")
        }
    }

    func markAllUpTo(season: Int, episode: Int) async {
        do {
            try await CineClawClient.shared.markWatched(
                imdbId: effectiveTconst,
                mode: "up_to",
                title: metadata?.title ?? initialTitle,
                upToSeason: season,
                upToEpisode: episode,
                completed: true
            )
            await fetchSeriesProgress()
        } catch {
            logger.error("Failed to mark up to \(season)x\(episode) watched: \(error.localizedDescription)")
        }
    }

    func selectSeason(_ number: Int) {
        guard selectedSeasonNumber != number else { return }
        selectedSeasonNumber = number
        if !allEpisodes.isEmpty {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                self.episodes = allEpisodes.filter { $0.seasonNumber == number }
            }
        }
        if isTv {
            self.qualityGroups = groupReleases(self.torrents, forSeason: number)
            if let current = selectedRelease, seasonMatchScore(current, targetSeason: number) >= 0 {
                // Keep currently selected release
            } else if let bestForSeason = selectBestRelease(forSeason: number) {
                self.selectedRelease = bestForSeason
            }

            Task { [weak self] in
                await self?.fetchTorrentsForSeason(number)
            }
        }
    }

    func fetchTorrentsForSeason(_ sNum: Int) async {
        guard effectiveTconst.hasPrefix("tt") else { return }
        do {
            let list = try await CineClawClient.shared.getTorrents(imdbId: effectiveTconst, query: initialTitle, season: sNum)
            if !list.isEmpty {
                var existingKeys = Set(self.torrents.map { $0.effectiveHash.isEmpty ? ($0.id ?? $0.title) : $0.effectiveHash })
                var merged = self.torrents
                for item in list {
                    let key = item.effectiveHash.isEmpty ? (item.id ?? item.title) : item.effectiveHash
                    if !existingKeys.contains(key) {
                        existingKeys.insert(key)
                        merged.append(item)
                    }
                }
                self.torrents = merged
                if self.selectedSeasonNumber == sNum {
                    self.qualityGroups = groupReleases(merged, forSeason: sNum)
                    if self.selectedRelease == nil || seasonMatchScore(self.selectedRelease!, targetSeason: sNum) < 0 {
                        self.selectedRelease = selectBestRelease(forSeason: sNum)
                    }
                }
            }
        } catch {
            logger.warning("Failed to fetch season \(sNum) torrents: \(error.localizedDescription)")
        }
    }

    private func fetchTorrents() async {
        isLoadingTorrents = true
        do {
            let imdbIdParam = effectiveTconst.hasPrefix("tt") ? effectiveTconst : nil
            let targetSeason = isTv ? selectedSeasonNumber : 0
            let list = try await CineClawClient.shared.getTorrents(imdbId: imdbIdParam, query: initialTitle, season: targetSeason > 0 ? targetSeason : nil)
            self.torrents = list
            self.qualityGroups = groupReleases(list, forSeason: isTv ? selectedSeasonNumber : nil)

            // Prefer server remembered release if available (e.g. chosen from web)
            var matchedSaved: TorrentRelease? = nil
            if let info = try? await CineClawClient.shared.getPlayerInfo(tconst: effectiveTconst, season: targetSeason, episode: nil),
               let savedHash = info.mediaSourceId, !savedHash.isEmpty {
                matchedSaved = list.first(where: { $0.effectiveHash.caseInsensitiveCompare(savedHash) == .orderedSame })
            }

            if let saved = matchedSaved, isTv ? (seasonMatchScore(saved, targetSeason: selectedSeasonNumber) >= 0) : true {
                self.selectedRelease = saved
            } else if isTv {
                self.selectedRelease = selectBestRelease(forSeason: selectedSeasonNumber)
            } else {
                self.selectedRelease = selectBestRelease()
            }
        } catch {
            self.logger.error("Failed to load torrents for \(self.initialTitle ?? self.effectiveTconst): \(error.localizedDescription)")
        }
        isLoadingTorrents = false
    }

    func fetchCritics() async {
        guard effectiveTconst.hasPrefix("tt") else { return }
        if criticSummary != nil { return }
        isLoadingCritics = true
        hasCriticsFailed = false
        logger.info("Starting AI critics fetch for \(self.effectiveTconst, privacy: .public)")
        do {
            let summary = try await CineClawClient.shared.getCriticSummary(tconst: effectiveTconst)
            self.criticSummary = summary
            self.hasCriticsFailed = false
            self.logger.info("Successfully loaded AI critics for \(self.effectiveTconst, privacy: .public): tone=\(summary.tone, privacy: .public)")
        } catch {
            self.hasCriticsFailed = true
            self.logger.error("Failed to load AI critics for \(self.effectiveTconst, privacy: .public): \(error.localizedDescription)")
        }
        isLoadingCritics = false
    }

    func retryCritics() {
        Task {
            await fetchCritics()
        }
    }

    private func checkWatchlist() async {
        self.inWatchlist = (try? await CineClawClient.shared.checkWatchlist(tconst: effectiveTconst)) ?? false
    }

    func toggleWatchlist() async {
        let title = metadata?.title ?? initialTitle ?? homeItem?.title ?? "Без названия"
        let item = HomeItem(
            id: effectiveTconst,
            tconst: effectiveTconst,
            tmdbId: homeItem?.tmdbId,
            mediaType: isTv ? "tv" : "movie",
            title: title,
            originalTitle: metadata?.originalTitle ?? homeItem?.originalTitle,
            year: metadata?.year ?? homeItem?.year,
            rating: metadata?.rating ?? homeItem?.rating,
            posterPath: metadata?.posterPath ?? homeItem?.posterPath,
            backdropPath: metadata?.backdropPath ?? homeItem?.backdropPath,
            overview: metadata?.overview ?? homeItem?.overview
        )
        do {
            if inWatchlist {
                try await CineClawClient.shared.removeFromWatchlist(tconst: effectiveTconst)
                inWatchlist = false
            } else {
                try await CineClawClient.shared.addToWatchlist(item: item)
                inWatchlist = true
            }
        } catch {
            logger.error("Toggle watchlist error: \(error.localizedDescription)")
        }
    }

    private func groupReleases(_ list: [TorrentRelease], forSeason targetSeason: Int? = nil) -> [QualityGroup] {
        TorrentSelectionHelper.groupReleases(list, forSeason: targetSeason)
    }

    func seasonMatchScore(_ r: TorrentRelease, targetSeason: Int?) -> Int {
        TorrentSelectionHelper.seasonMatchScore(r, targetSeason: targetSeason)
    }

    func selectBestRelease(forSeason targetSeason: Int? = nil) -> TorrentRelease? {
        TorrentSelectionHelper.selectBestRelease(from: torrents, targetSeason: targetSeason, preferredQuality: APIConfig.shared.defaultQuality)
    }
}
