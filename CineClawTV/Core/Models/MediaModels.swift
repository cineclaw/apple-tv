import Foundation

struct MovieMetadataResponse: Codable, Sendable {
    let tconst: String
    let title: String
    let originalTitle: String?
    let year: Int?
    let rating: Double?
    let voteCount: Int?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let genres: [String]?
    let runtimeMinutes: Int?
    let cast: [CastMember]?
    let crew: [CrewMember]?
    let backdrops: [String]?
    let trailerYoutubeId: String?

    var effectivePosterURL: URL? {
        resolveImageURL(posterPath, prefix: "https://image.tmdb.org/t/p/w500")
    }

    var effectiveBackdropURL: URL? {
        resolveImageURL(backdropPath, prefix: "https://image.tmdb.org/t/p/w1280")
    }
}

struct CastMember: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    var effectiveAvatarURL: URL? {
        resolveImageURL(profilePath, prefix: "https://image.tmdb.org/t/p/w185")
    }
}

struct CrewMember: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    var effectiveAvatarURL: URL? {
        resolveImageURL(profilePath, prefix: "https://image.tmdb.org/t/p/w185")
    }
}

struct SeriesSeasonsResponse: Codable, Sendable {
    let seasons: [SeasonInfo]
}

struct SeasonInfo: Codable, Sendable, Identifiable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let episodeCount: Int
    let airDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber
        case name
        case overview
        case posterPath
        case episodeCount
        case airDate
        case voteAverage
    }

    init(seasonNumber: Int, name: String, overview: String? = nil, posterPath: String? = nil, episodeCount: Int = 0, airDate: String? = nil, voteAverage: Double? = nil) {
        self.seasonNumber = seasonNumber
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.episodeCount = episodeCount
        self.airDate = airDate
        self.voteAverage = voteAverage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.seasonNumber = (try? c.decode(Int.self, forKey: .seasonNumber)) ?? (try? c.decode(Int.self, forKey: .id)) ?? 1
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Сезон \(self.seasonNumber)"
        self.overview = try? c.decodeIfPresent(String.self, forKey: .overview)
        self.posterPath = try? c.decodeIfPresent(String.self, forKey: .posterPath)
        self.episodeCount = (try? c.decode(Int.self, forKey: .episodeCount)) ?? 0
        self.airDate = try? c.decodeIfPresent(String.self, forKey: .airDate)
        self.voteAverage = try? c.decodeIfPresent(Double.self, forKey: .voteAverage)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seasonNumber, forKey: .seasonNumber)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(overview, forKey: .overview)
        try c.encodeIfPresent(posterPath, forKey: .posterPath)
        try c.encode(episodeCount, forKey: .episodeCount)
        try c.encodeIfPresent(airDate, forKey: .airDate)
        try c.encodeIfPresent(voteAverage, forKey: .voteAverage)
    }

    var effectivePosterURL: URL? {
        resolveImageURL(posterPath, prefix: "https://image.tmdb.org/t/p/w500")
    }
}

struct EpisodeInfo: Codable, Sendable, Identifiable {
    var id: String { "\(seasonNumber)_\(episodeNumber)" }
    let seasonNumber: Int
    let episodeNumber: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let airDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let resumeSeconds: Double?
    let isPlayed: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber
        case episodeNumber
        case name
        case overview
        case stillPath
        case airDate
        case runtime
        case voteAverage
        case resumeSeconds
        case isPlayed
    }

    init(seasonNumber: Int, episodeNumber: Int, name: String, overview: String? = nil, stillPath: String? = nil, airDate: String? = nil, runtime: Int? = nil, voteAverage: Double? = nil, resumeSeconds: Double? = nil, isPlayed: Bool? = nil) {
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.overview = overview
        self.stillPath = stillPath
        self.airDate = airDate
        self.runtime = runtime
        self.voteAverage = voteAverage
        self.resumeSeconds = resumeSeconds
        self.isPlayed = isPlayed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.seasonNumber = (try? c.decode(Int.self, forKey: .seasonNumber)) ?? 1
        self.episodeNumber = (try? c.decode(Int.self, forKey: .episodeNumber)) ?? 1
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Серия \(self.episodeNumber)"
        self.overview = try? c.decodeIfPresent(String.self, forKey: .overview)
        self.stillPath = try? c.decodeIfPresent(String.self, forKey: .stillPath)
        self.airDate = try? c.decodeIfPresent(String.self, forKey: .airDate)
        self.runtime = try? c.decodeIfPresent(Int.self, forKey: .runtime)
        self.voteAverage = try? c.decodeIfPresent(Double.self, forKey: .voteAverage)
        self.resumeSeconds = try? c.decodeIfPresent(Double.self, forKey: .resumeSeconds)
        self.isPlayed = try? c.decodeIfPresent(Bool.self, forKey: .isPlayed)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seasonNumber, forKey: .seasonNumber)
        try c.encode(episodeNumber, forKey: .episodeNumber)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(overview, forKey: .overview)
        try c.encodeIfPresent(stillPath, forKey: .stillPath)
        try c.encodeIfPresent(airDate, forKey: .airDate)
        try c.encodeIfPresent(runtime, forKey: .runtime)
        try c.encodeIfPresent(voteAverage, forKey: .voteAverage)
        try c.encodeIfPresent(resumeSeconds, forKey: .resumeSeconds)
        try c.encodeIfPresent(isPlayed, forKey: .isPlayed)
    }

    var effectiveStillURL: URL? {
        resolveImageURL(stillPath, prefix: "https://image.tmdb.org/t/p/w500")
    }
}

struct SearchResponse: Codable, Sendable {
    let query: String?
    let totalHits: Int?
    let tookMs: Double?
    let hits: [SearchHit]?
    let results: [SearchResultItem]?

    var effectiveResults: [SearchResultItem] {
        if let h = hits, !h.isEmpty {
            return h.map { $0.toSearchResultItem() }
        }
        return results ?? []
    }
}

struct SearchHit: Codable, Sendable {
    let movie: SearchMovieDoc
    let posterPath: String?
    let backdropPath: String?
    let score: Double?

    func toSearchResultItem() -> SearchResultItem {
        let displayTitle = (movie.titleRu?.isEmpty == false ? movie.titleRu : nil)
            ?? (movie.russianTitles?.first(where: { !$0.isEmpty }))
            ?? (movie.titlePrimary?.isEmpty == false ? movie.titlePrimary : nil)
            ?? movie.titleOrig
            ?? "Без названия"

        let isTvType = (movie.titleType?.lowercased().contains("tv") == true)
            || (movie.titleType?.lowercased().contains("series") == true)

        return SearchResultItem(
            tconst: movie.tconst,
            title: displayTitle,
            originalTitle: movie.titleOrig,
            year: movie.year,
            rating: movie.rating,
            posterPath: posterPath,
            mediaType: isTvType ? "tv" : "movie",
            seasonsCount: nil
        )
    }
}

struct SearchMovieDoc: Codable, Sendable {
    let tconst: String
    let titleRu: String?
    let titleOrig: String?
    let titlePrimary: String?
    let russianTitles: [String]?
    let year: Int?
    let titleType: String?
    let rating: Double?
    let numVotes: Int?
    let genres: [String]?
    let runtimeMinutes: Int?
}

struct SearchResultItem: Codable, Sendable, Identifiable {
    let tconst: String
    let title: String
    let originalTitle: String?
    let year: Int?
    let rating: Double?
    let posterPath: String?
    let mediaType: String?
    let seasonsCount: Int?

    var id: String { tconst }

    var isTv: Bool {
        mediaType?.lowercased() == "tv" || (seasonsCount ?? 0) > 0
    }

    var effectivePosterURL: URL? {
        resolveImageURL(posterPath, prefix: "https://image.tmdb.org/t/p/w500")
    }
}
