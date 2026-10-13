import Foundation

struct ResumeItem: Codable, Sendable, Identifiable {
    let tconst: String
    let title: String
    let season: Int?
    let episode: Int?
    let positionSeconds: Double
    let durationSeconds: Double
    let playbackPercent: Int
    let posterPath: String?
    let backdropPath: String?
    let timecode: String?
    let isNextUp: Bool?

    var id: String {
        if let s = season, let e = episode {
            return "\(tconst)_s\(s)e\(e)"
        }
        return tconst
    }

    var effectivePosterURL: URL? {
        resolveImageURL(posterPath, prefix: "https://image.tmdb.org/t/p/w500")
    }

    var effectiveBackdropURL: URL? {
        resolveImageURL(backdropPath, prefix: "https://image.tmdb.org/t/p/w780")
    }
}

struct WatchProgressRequest: Codable, Sendable {
    let imdbId: String
    let title: String
    let mediaType: String
    let seasonNumber: Int
    let episodeNumber: Int
    let positionSeconds: Double
    let durationSeconds: Double
    let playbackPercent: Double
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case title
        case mediaType = "media_type"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case positionSeconds = "position_seconds"
        case durationSeconds = "duration_seconds"
        case playbackPercent = "playback_percent"
        case isCompleted = "is_completed"
    }
}

struct AudioPreferenceRequest: Codable, Sendable {
    let imdbId: String
    let preferredAudioTitle: String
}

enum PlaybackPreferences {
    private static let releasePrefix = "cineclaw_pref_release_"
    private static let audioTitlePrefix = "cineclaw_pref_audio_title_"
    private static let globalAudioPrefKey = "cineclaw_global_audio_pref"

    private static func releaseKey(tconst: String, season: Int?) -> String {
        if let s = season, s > 0 {
            return "\(releasePrefix)\(tconst):s\(s)"
        }
        return "\(releasePrefix)\(tconst)"
    }

    static func saveRelease(tconst: String, season: Int? = nil, release: TorrentRelease) {
        let hash = release.effectiveHash
        guard !hash.isEmpty && !tconst.isEmpty else { return }

        // 1. If season is specified, save for this particular season
        if let s = season, s > 0 {
            UserDefaults.standard.set(hash, forKey: releaseKey(tconst: tconst, season: s))
        }
        // 2. Also record as latest selected release for the title / multi-season pack
        UserDefaults.standard.set(hash, forKey: releaseKey(tconst: tconst, season: nil))
    }

    static func getSavedReleaseHash(tconst: String, season: Int? = nil) -> String? {
        guard !tconst.isEmpty else { return nil }

        // 1. Check season-specific saved release first
        if let s = season, s > 0 {
            if let seasonHash = UserDefaults.standard.string(forKey: releaseKey(tconst: tconst, season: s)), !seasonHash.isEmpty {
                return seasonHash
            }
        }

        // 2. Fallback to title-level release / multi-season pack
        return UserDefaults.standard.string(forKey: releaseKey(tconst: tconst, season: nil))
    }

    static func saveAudioPreference(tconst: String, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if !tconst.isEmpty {
            UserDefaults.standard.set(clean, forKey: "\(audioTitlePrefix)\(tconst)")
        }
        UserDefaults.standard.set(clean, forKey: globalAudioPrefKey)
    }

    static func getSavedAudioPreference(tconst: String) -> String? {
        guard !tconst.isEmpty else { return nil }
        return UserDefaults.standard.string(forKey: "\(audioTitlePrefix)\(tconst)")
    }

    static func getGlobalAudioPreference() -> String? {
        UserDefaults.standard.string(forKey: globalAudioPrefKey)
    }
}


struct LoginRequest: Codable, Sendable {
    let username: String
    let password: String
    let rememberMe: Bool

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case rememberMe = "remember_me"
    }
}

struct LoginResponse: Codable, Sendable {
    let success: Bool
    let token: String
    let username: String
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case token
        case username
        case expiresAt = "expires_at"
    }
}

struct PairingStatusResponse: Codable, Sendable {
    let paired: Bool
    let token: String?
    let username: String?
}

struct PairInitRequest: Codable, Sendable {
    let code: String
    let deviceName: String

    enum CodingKeys: String, CodingKey {
        case code
        case deviceName = "device_name"
    }
}

struct PairInitResponse: Codable, Sendable {
    let success: Bool
    let code: String
}

struct HealthResponse: Codable, Sendable {
    let status: String?
    let service: String?
    let name: String?
    let version: String?
}

struct DiscoveredServer: Identifiable, Hashable, Sendable {
    var id: String { url }
    let name: String
    let url: String
    let version: String?
    let isOnline: Bool
}

struct WatchlistCheckResponse: Codable, Sendable {
    let inWatchlist: Bool
}

struct PlaybackTarget: Identifiable, Equatable {
    let tconst: String
    let release: TorrentRelease
    var title: String? = nil
    let season: Int?
    let episode: Int?
    var qualityGroups: [QualityGroup] = []
    var resumeSeconds: Double = 0.0
    var autoResume: Bool = false

    var id: String { "\(tconst)_\(release.effectiveHash)_\(season ?? 0)_\(episode ?? 0)_\(resumeSeconds)" }

    static func == (lhs: PlaybackTarget, rhs: PlaybackTarget) -> Bool {
        lhs.id == rhs.id
    }
}

struct SeasonProgressSummary: Codable, Sendable {
    let seasonNumber: Int
    let totalEpisodes: Int
    let watchedEpisodes: Int
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case totalEpisodes = "total_episodes"
        case watchedEpisodes = "watched_episodes"
        case isCompleted = "is_completed"
    }
}

struct EpisodeProgressStatus: Codable, Sendable {
    let seasonNumber: Int
    let episodeNumber: Int
    let positionSeconds: Double
    let durationSeconds: Double
    let playbackPercent: Double
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case positionSeconds = "position_seconds"
        case durationSeconds = "duration_seconds"
        case playbackPercent = "playback_percent"
        case isCompleted = "is_completed"
    }
}

struct SeriesProgressResponse: Codable, Sendable {
    let imdbId: String
    let totalEpisodes: Int
    let totalWatched: Int
    let isCompleted: Bool
    let hasUnwatchedPrior: Bool
    let latestWatchedSeason: Int?
    let latestWatchedEpisode: Int?
    let seasons: [String: SeasonProgressSummary]
    let episodes: [String: EpisodeProgressStatus]

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case totalEpisodes = "total_episodes"
        case totalWatched = "total_watched"
        case isCompleted = "is_completed"
        case hasUnwatchedPrior = "has_unwatched_prior"
        case latestWatchedSeason = "latest_watched_season"
        case latestWatchedEpisode = "latest_watched_episode"
        case seasons, episodes
    }
}

struct MarkWatchedRequest: Codable, Sendable {
    let imdbId: String
    let mode: String
    let title: String?
    let season: Int?
    let episode: Int?
    let upToSeason: Int?
    let upToEpisode: Int?
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case mode, title, season, episode
        case upToSeason = "up_to_season"
        case upToEpisode = "up_to_episode"
        case completed
    }
}
