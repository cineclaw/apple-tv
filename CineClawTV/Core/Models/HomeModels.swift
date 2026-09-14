import Foundation

func resolveImageURL(_ path: String?, prefix: String = "https://image.tmdb.org/t/p/w500") -> URL? {
    guard let path = path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return URL(string: path)
    }
    if path.hasPrefix("/poster/") {
        return nil
    }
    let full = path.hasPrefix("/") ? "\(prefix)\(path)" : "\(prefix)/\(path)"
    return URL(string: full)
}

struct HomePayload: Codable, Sendable {
    let hero: [HomeItem]?
    let shelves: [HomeShelf]
}

struct HomeShelf: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let type: String?
    let badge: String?
    let actionRoute: String?
    var items: [HomeItem]
    let page: Int?
    let totalPages: Int?
    let totalResults: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, type, badge, actionRoute, items, page, totalPages, totalResults
        case mediaType
    }

    init(
        id: String,
        title: String,
        type: String? = "poster",
        badge: String? = nil,
        actionRoute: String? = nil,
        items: [HomeItem],
        page: Int? = nil,
        totalPages: Int? = nil,
        totalResults: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.badge = badge
        self.actionRoute = actionRoute
        self.items = items
        self.page = page
        self.totalPages = totalPages
        self.totalResults = totalResults
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.type = (try? c.decodeIfPresent(String.self, forKey: .type)) ?? (try? c.decodeIfPresent(String.self, forKey: .mediaType)) ?? "poster"
        self.badge = try? c.decodeIfPresent(String.self, forKey: .badge)
        self.actionRoute = try? c.decodeIfPresent(String.self, forKey: .actionRoute)
        self.items = (try? c.decode([HomeItem].self, forKey: .items)) ?? []
        self.page = try? c.decodeIfPresent(Int.self, forKey: .page)
        self.totalPages = try? c.decodeIfPresent(Int.self, forKey: .totalPages)
        self.totalResults = try? c.decodeIfPresent(Int.self, forKey: .totalResults)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(type, forKey: .type)
        try c.encodeIfPresent(badge, forKey: .badge)
        try c.encodeIfPresent(actionRoute, forKey: .actionRoute)
        try c.encode(items, forKey: .items)
        try c.encodeIfPresent(page, forKey: .page)
        try c.encodeIfPresent(totalPages, forKey: .totalPages)
        try c.encodeIfPresent(totalResults, forKey: .totalResults)
    }
}

struct HomeItem: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let tconst: String?
    let tmdbId: Int64?
    let mediaType: String?
    let title: String
    let originalTitle: String?
    let year: Int?
    let rating: Double?
    let voteCount: Int?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let season: Int?
    let episode: Int?
    let episodeTitle: String?
    let episodeStill: String?
    let positionSeconds: Int64?
    let durationSeconds: Int64?
    let playbackPercent: Double?
    let timecode: String?
    let isNextUp: Bool?
    let seeds: Int?
    let qualityBadge: String?

    enum CodingKeys: String, CodingKey {
        case id, tconst, tmdbId, mediaType, title, originalTitle, year, rating, voteCount
        case posterPath, backdropPath, overview, season, episode, episodeTitle, episodeStill
        case positionSeconds, durationSeconds, playbackPercent, timecode, isNextUp, seeds, qualityBadge
    }

    init(
        id: String,
        tconst: String? = nil,
        tmdbId: Int64? = nil,
        mediaType: String? = nil,
        title: String,
        originalTitle: String? = nil,
        year: Int? = nil,
        rating: Double? = nil,
        voteCount: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        episodeTitle: String? = nil,
        episodeStill: String? = nil,
        positionSeconds: Int64? = nil,
        durationSeconds: Int64? = nil,
        playbackPercent: Double? = nil,
        timecode: String? = nil,
        isNextUp: Bool? = nil,
        seeds: Int? = nil,
        qualityBadge: String? = nil
    ) {
        self.id = id
        self.tconst = tconst
        self.tmdbId = tmdbId
        self.mediaType = mediaType
        self.title = title
        self.originalTitle = originalTitle
        self.year = year
        self.rating = rating
        self.voteCount = voteCount
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.season = season
        self.episode = episode
        self.episodeTitle = episodeTitle
        self.episodeStill = episodeStill
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
        self.playbackPercent = playbackPercent
        self.timecode = timecode
        self.isNextUp = isNextUp
        self.seeds = seeds
        self.qualityBadge = qualityBadge
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // Decode ID either as String, Int64 or Int
        let rawId: String
        if let str = try? c.decode(String.self, forKey: .id) {
            rawId = str
        } else if let int64 = try? c.decode(Int64.self, forKey: .id) {
            rawId = "\(int64)"
        } else if let intVal = try? c.decode(Int.self, forKey: .id) {
            rawId = "\(intVal)"
        } else {
            rawId = UUID().uuidString
        }
        self.id = rawId

        self.tconst = try? c.decodeIfPresent(String.self, forKey: .tconst)

        if let tmdb = try? c.decodeIfPresent(Int64.self, forKey: .tmdbId) {
            self.tmdbId = tmdb
        } else if let tmdbInt = try? c.decodeIfPresent(Int.self, forKey: .tmdbId) {
            self.tmdbId = Int64(tmdbInt)
        } else if let intId = Int64(rawId), (self.tconst == nil || self.tconst?.isEmpty == true) {
            self.tmdbId = intId
        } else {
            self.tmdbId = nil
        }

        self.mediaType = try? c.decodeIfPresent(String.self, forKey: .mediaType)
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.originalTitle = try? c.decodeIfPresent(String.self, forKey: .originalTitle)
        self.year = try? c.decodeIfPresent(Int.self, forKey: .year)
        self.rating = try? c.decodeIfPresent(Double.self, forKey: .rating)
        self.voteCount = try? c.decodeIfPresent(Int.self, forKey: .voteCount)
        self.posterPath = try? c.decodeIfPresent(String.self, forKey: .posterPath)
        self.backdropPath = try? c.decodeIfPresent(String.self, forKey: .backdropPath)
        self.overview = try? c.decodeIfPresent(String.self, forKey: .overview)
        self.season = try? c.decodeIfPresent(Int.self, forKey: .season)
        self.episode = try? c.decodeIfPresent(Int.self, forKey: .episode)
        self.episodeTitle = try? c.decodeIfPresent(String.self, forKey: .episodeTitle)
        self.episodeStill = try? c.decodeIfPresent(String.self, forKey: .episodeStill)
        if let pos = try? c.decodeIfPresent(Int64.self, forKey: .positionSeconds) {
            self.positionSeconds = pos
        } else if let posDouble = try? c.decodeIfPresent(Double.self, forKey: .positionSeconds) {
            self.positionSeconds = Int64(posDouble)
        } else {
            self.positionSeconds = nil
        }

        if let dur = try? c.decodeIfPresent(Int64.self, forKey: .durationSeconds) {
            self.durationSeconds = dur
        } else if let durDouble = try? c.decodeIfPresent(Double.self, forKey: .durationSeconds) {
            self.durationSeconds = Int64(durDouble)
        } else {
            self.durationSeconds = nil
        }
        self.playbackPercent = try? c.decodeIfPresent(Double.self, forKey: .playbackPercent)
        self.timecode = try? c.decodeIfPresent(String.self, forKey: .timecode)
        self.isNextUp = try? c.decodeIfPresent(Bool.self, forKey: .isNextUp)
        self.seeds = try? c.decodeIfPresent(Int.self, forKey: .seeds)
        self.qualityBadge = try? c.decodeIfPresent(String.self, forKey: .qualityBadge)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(tconst, forKey: .tconst)
        try c.encodeIfPresent(tmdbId, forKey: .tmdbId)
        try c.encodeIfPresent(mediaType, forKey: .mediaType)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(originalTitle, forKey: .originalTitle)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(voteCount, forKey: .voteCount)
        try c.encodeIfPresent(posterPath, forKey: .posterPath)
        try c.encodeIfPresent(backdropPath, forKey: .backdropPath)
        try c.encodeIfPresent(overview, forKey: .overview)
        try c.encodeIfPresent(season, forKey: .season)
        try c.encodeIfPresent(episode, forKey: .episode)
        try c.encodeIfPresent(episodeTitle, forKey: .episodeTitle)
        try c.encodeIfPresent(episodeStill, forKey: .episodeStill)
        try c.encodeIfPresent(positionSeconds, forKey: .positionSeconds)
        try c.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try c.encodeIfPresent(playbackPercent, forKey: .playbackPercent)
        try c.encodeIfPresent(timecode, forKey: .timecode)
        try c.encodeIfPresent(isNextUp, forKey: .isNextUp)
        try c.encodeIfPresent(seeds, forKey: .seeds)
        try c.encodeIfPresent(qualityBadge, forKey: .qualityBadge)
    }

    var effectiveTconst: String {
        if let t = tconst, !t.isEmpty { return t }
        if let id = tmdbId, id > 0 { return "tmdb_\(id)" }
        return id
    }

    var isTv: Bool {
        mediaType?.lowercased() == "tv"
    }

    var effectivePosterURL: URL? {
        resolveImageURL(posterPath, prefix: "https://image.tmdb.org/t/p/w500")
    }

    var effectiveBackdropURL: URL? {
        resolveImageURL(backdropPath, prefix: "https://image.tmdb.org/t/p/w1280")
    }

    var effectiveStillURL: URL? {
        resolveImageURL(episodeStill, prefix: "https://image.tmdb.org/t/p/w780")
    }

    var effectiveCardImageURL: URL? {
        effectiveStillURL ?? effectiveBackdropURL ?? effectivePosterURL
    }
}
