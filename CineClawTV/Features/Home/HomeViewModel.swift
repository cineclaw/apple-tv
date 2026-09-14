import Foundation
import SwiftUI
import os

@Observable
@MainActor
final class HomeViewModel {
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "HomeVM")

    var isLoading: Bool = false
    var heroItems: [HomeItem] = []
    var continueWatching: HomeShelf?
    var shelves: [HomeShelf] = []
    var errorMessage: String?

    func loadHome(refresh: Bool = false) async {
        if shelves.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        do {
            let payload = try await CineClawClient.shared.getHomeFeed(refresh: refresh)
            self.heroItems = payload.hero ?? []

            // Separate continue watching shelf from general catalog shelves
            self.continueWatching = payload.shelves.first { $0.id == "continue_watching" }
            self.shelves = payload.shelves.filter { $0.id != "continue_watching" }
            self.isLoading = false
        } catch {
            self.logger.error("Failed to load home feed: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = "Не удалось загрузить медиатеку. Проверьте адрес сервера в Настройках."
            self.isLoading = false
        }
    }

    func deleteResume(tconst: String) async {
        do {
            try await CineClawClient.shared.deleteResumeItem(tconst: tconst)
            await loadHome(refresh: true)
        } catch {
            logger.error("Failed to delete resume item: \(error.localizedDescription)")
        }
    }

    func toggleWatchlist(item: HomeItem, currentlyIn: Bool) async {
        do {
            if currentlyIn {
                try await CineClawClient.shared.removeFromWatchlist(tconst: item.effectiveTconst)
            } else {
                try await CineClawClient.shared.addToWatchlist(item: item)
            }
            await loadHome(refresh: true)
        } catch {
            logger.error("Failed to toggle watchlist: \(error.localizedDescription)")
        }
    }

    func preparePlayback(for item: HomeItem) async throws -> PlaybackTarget {
        let cleanTitle = item.title.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveTconst = item.effectiveTconst

        if !effectiveTconst.hasPrefix("tt"), let tmdb = item.tmdbId {
            if let resolved = try? await CineClawClient.shared.resolveTmdb(mediaType: item.isTv ? "tv" : "movie", tmdbId: tmdb),
               !resolved.tconst.isEmpty && resolved.tconst.hasPrefix("tt") {
                effectiveTconst = resolved.tconst
            }
        }

        let imdbIdParam = effectiveTconst.hasPrefix("tt") ? effectiveTconst : nil
        let torrents = try await CineClawClient.shared.getTorrents(imdbId: imdbIdParam, query: cleanTitle)
        guard !torrents.isEmpty else {
            throw NSError(domain: "CineClaw", code: 404, userInfo: [NSLocalizedDescriptionKey: "Раздачи не найдены"])
        }

        let groups = TorrentSelectionHelper.groupReleases(torrents)

        // Prefer server remembered release if available (e.g. chosen from web)
        var selectedRel: TorrentRelease? = nil
        if let info = try? await CineClawClient.shared.getPlayerInfo(tconst: effectiveTconst, season: item.season, episode: item.episode),
           let savedHash = info.mediaSourceId, !savedHash.isEmpty {
            if let matched = torrents.first(where: { $0.effectiveHash.caseInsensitiveCompare(savedHash) == .orderedSame }) {
                selectedRel = matched
            }
        }

        if selectedRel == nil {
            selectedRel = TorrentSelectionHelper.selectBestRelease(from: torrents, targetSeason: item.season)
        }

        guard let finalRelease = selectedRel else {
            throw NSError(domain: "CineClaw", code: 404, userInfo: [NSLocalizedDescriptionKey: "Подходящая раздача не найдена"])
        }

        let resumeSec = Double(item.positionSeconds ?? 0)

        return PlaybackTarget(
            tconst: effectiveTconst,
            release: finalRelease,
            title: cleanTitle,
            season: item.season,
            episode: item.episode,
            qualityGroups: groups,
            resumeSeconds: resumeSec,
            autoResume: true
        )
    }
}
