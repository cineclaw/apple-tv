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
