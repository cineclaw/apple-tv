import Foundation
import VideoToolbox

struct TorrentRelease: Codable, Sendable, Identifiable {
    let id: String?
    let title: String
    let infoHash: String?
    let hash: String?
    let size: Int64
    let seeds: Int
    let leeches: Int
    let tracker: String
    let resolution: String?
    let audioLabel: String?
    let videoCodec: String?
    let magnet: String?
    let tier: String?
    let bitrateMbps: Double?
    let streamUrl: String?
    let seasons: [Int]?

    var peers: Int { leeches }

    enum CodingKeys: String, CodingKey {
        case id, title, size, seeds, leeches, peers, tracker, resolution, magnet, tier
        case infoHash = "info_hash"
        case audioLabel = "audio_label"
        case videoCodec = "video_codec"
        case bitrateMbps = "bitrate_mbps"
        case streamUrl = "stream_url"
        case hash
        case seasons
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decodeIfPresent(String.self, forKey: .id)
        self.title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? "Раздача"
        self.infoHash = try? c.decodeIfPresent(String.self, forKey: .infoHash)
        self.hash = try? c.decodeIfPresent(String.self, forKey: .hash)
        self.size = (try? c.decodeIfPresent(Int64.self, forKey: .size)) ?? 0
        self.seeds = (try? c.decodeIfPresent(Int.self, forKey: .seeds)) ?? 0
        let l = try? c.decodeIfPresent(Int.self, forKey: .leeches)
        let p = try? c.decodeIfPresent(Int.self, forKey: .peers)
        self.leeches = l ?? p ?? 0
        self.tracker = (try? c.decodeIfPresent(String.self, forKey: .tracker)) ?? "rutor"
        self.resolution = try? c.decodeIfPresent(String.self, forKey: .resolution)
        self.audioLabel = try? c.decodeIfPresent(String.self, forKey: .audioLabel)
        self.videoCodec = try? c.decodeIfPresent(String.self, forKey: .videoCodec)
        self.magnet = try? c.decodeIfPresent(String.self, forKey: .magnet)
        self.tier = try? c.decodeIfPresent(String.self, forKey: .tier)
        self.bitrateMbps = try? c.decodeIfPresent(Double.self, forKey: .bitrateMbps)
        self.streamUrl = try? c.decodeIfPresent(String.self, forKey: .streamUrl)
        self.seasons = try? c.decodeIfPresent([Int].self, forKey: .seasons)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(infoHash, forKey: .infoHash)
        try container.encodeIfPresent(hash, forKey: .hash)
        try container.encode(size, forKey: .size)
        try container.encode(seeds, forKey: .seeds)
        try container.encode(leeches, forKey: .leeches)
        try container.encode(tracker, forKey: .tracker)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encodeIfPresent(audioLabel, forKey: .audioLabel)
        try container.encodeIfPresent(videoCodec, forKey: .videoCodec)
        try container.encodeIfPresent(magnet, forKey: .magnet)
        try container.encodeIfPresent(tier, forKey: .tier)
        try container.encodeIfPresent(bitrateMbps, forKey: .bitrateMbps)
        try container.encodeIfPresent(streamUrl, forKey: .streamUrl)
    }

    var effectiveHash: String {
        if let h = hash, !h.isEmpty { return h }
        if let ih = infoHash, !ih.isEmpty { return ih }
        return id ?? ""
    }

    var sizeFormatted: String {
        let gb = Double(size) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.2f ГБ", gb)
        }
        let mb = Double(size) / (1024.0 * 1024.0)
        return String(format: "%.0f МБ", mb)
    }

    var bitrateFormatted: String {
        guard let br = bitrateMbps, br > 0 else { return "" }
        return String(format: "%.1f Мбит/с", br)
    }

    var effectiveTier: String {
        if let t = tier, !t.isEmpty { return t }
        let r = (resolution ?? "").lowercased()
        let tLow = title.lowercased()
        if r == "4k" || r.contains("2160") || tLow.contains("2160p") || tLow.contains("4k uhd") || tLow.contains("4k") || tLow.contains("uhd") {
            return "4K UHD"
        }
        if r == "1080p" || r.contains("1080") || tLow.contains("1080p") || tLow.contains("1080i") || tLow.contains("fhd") {
            return "1080p"
        }
        if r == "720p" || r.contains("720") || tLow.contains("720p") || tLow.contains("hd") {
            return "720p"
        }
        return "SD"
    }

    var isHEVC: Bool {
        if let codec = videoCodec?.lowercased() {
            if codec.contains("hevc") || codec.contains("h.265") || codec.contains("h265") || codec.contains("x265") {
                return true
            }
            if codec.contains("h.264") || codec.contains("h264") || codec.contains("x264") || codec.contains("avc") {
                return false
            }
        }
        let lower = title.lowercased()
        return lower.contains("h.265") || lower.contains("h265") || lower.contains("hevc") || lower.contains("x265")
    }

    var codecBadge: String {
        if isHEVC { return "H.265" }
        let lower = title.lowercased()
        if let codec = videoCodec?.lowercased() {
            if codec.contains("h.264") || codec.contains("h264") || codec.contains("x264") || codec.contains("avc") {
                return "H.264"
            }
        }
        if lower.contains("h.264") || lower.contains("h264") || lower.contains("x264") || lower.contains("avc") {
            return "H.264"
        }
        if lower.contains("xvid") || lower.contains("divx") {
            return "XviD"
        }
        return "H.264"
    }
}

struct QualityGroup: Sendable, Identifiable {
    let id: String
    let tier: String
    let title: String
    let badge: String
    let releases: [TorrentRelease]
}

struct TmdbResolveResponse: Codable, Sendable {
    let tconst: String
    let titleRu: String?
    let titleOrig: String?
    let year: Int?
    let rating: Double?
}

struct MountTorrentRequest: Codable, Sendable {
    let tconst: String
    let title: String?
    let magnet: String?
    let hash: String?
    let type: String?
    let season: Int?
    let episode: Int?
}

struct PlayerInfoResponse: Codable, Sendable {
    let success: Bool?
    let error: String?
    let itemId: String?
    let title: String?
    let mediaType: String?
    let durationSeconds: Double?
    let resumeSeconds: Double?
    let isPlayed: Bool?
    let streamUrl: String?
    let directStreamUrl: String?
    let mediaSourceId: String?
    let audioTracks: [AudioTrackInfo]?
    let subtitles: [SubtitleTrackInfo]?
    let targetFileIdx: Int?
    let videoCodec: String?
    let width: Int?
    let height: Int?
    let transcodeProfiles: [TranscodeProfile]?
    let transcodeStreamUrl: String?

    var effectiveStreamUrl: String? {
        directStreamUrl ?? streamUrl
    }
}

struct TranscodeProfile: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let label: String
    let description: String?
    let maxHeight: Int?
    let bitrateKbps: Int?
    let isDirect: Bool?
}

struct AudioTrackInfo: Codable, Sendable, Identifiable {
    let index: Int
    let title: String
    let language: String?
    let codec: String?
    let channels: Int?
    let isDefault: Bool?

    var id: Int { index }
}

struct SubtitleTrackInfo: Codable, Sendable, Identifiable {
    let index: Int
    let title: String
    let language: String?
    let codec: String?
    let isDefault: Bool?

    var id: Int { index }
}

struct WatchlistAddRequest: Encodable, Sendable {
    let imdbId: String
    let mediaType: String
    let title: String
    let originalTitle: String?
    let year: Int?
    let rating: Double?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case imdbId = "imdb_id"
        case mediaType = "media_type"
        case title
        case originalTitle = "original_title"
        case year
        case rating
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

struct WatchlistItemResponse: Codable, Sendable {
    let imdbId: String
    let mediaType: String?
    let title: String
    let originalTitle: String?
    let year: Int?
    let rating: Double?
    let posterPath: String?
    let backdropPath: String?

    func toHomeItem() -> HomeItem {
        HomeItem(
            id: imdbId,
            tconst: imdbId,
            mediaType: mediaType,
            title: title,
            originalTitle: originalTitle,
            year: year,
            rating: rating,
            posterPath: posterPath,
            backdropPath: backdropPath
        )
    }
}

enum TorrentSelectionHelper {
    static let isHardwareHEVCSupported: Bool = {
        VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
    }()

    static func groupReleases(_ list: [TorrentRelease]) -> [QualityGroup] {
        var g4k: [TorrentRelease] = []
        var g1080: [TorrentRelease] = []
        var g720: [TorrentRelease] = []
        var gSD: [TorrentRelease] = []

        for r in list {
            let t = r.effectiveTier.lowercased()
            if t.contains("4k") || t.contains("2160") {
                g4k.append(r)
            } else if t.contains("1080") {
                g1080.append(r)
            } else if t.contains("720") {
                g720.append(r)
            } else {
                gSD.append(r)
            }
        }

        let releaseSorter: (TorrentRelease, TorrentRelease) -> Bool = { a, b in
            if !isHardwareHEVCSupported {
                let aHw = !a.isHEVC
                let bHw = !b.isHEVC
                if aHw != bHw {
                    return aHw
                }
            }
            return a.seeds > b.seeds
        }

        var groups: [QualityGroup] = []
        if !g4k.isEmpty {
            groups.append(QualityGroup(id: "4k", tier: "4K UHD", title: "4K Ultra HD", badge: "\(g4k.count)", releases: g4k.sorted(by: releaseSorter)))
        }
        if !g1080.isEmpty {
            groups.append(QualityGroup(id: "1080p", tier: "1080p", title: "1080p Full HD", badge: "\(g1080.count)", releases: g1080.sorted(by: releaseSorter)))
        }
        if !g720.isEmpty {
            groups.append(QualityGroup(id: "720p", tier: "720p", title: "720p HD", badge: "\(g720.count)", releases: g720.sorted(by: releaseSorter)))
        }
        if !gSD.isEmpty {
            groups.append(QualityGroup(id: "sd", tier: "SD", title: "SD Качество", badge: "\(gSD.count)", releases: gSD.sorted(by: releaseSorter)))
        }
        return groups
    }

    static func seasonMatchScore(_ r: TorrentRelease, targetSeason: Int?) -> Int {
        guard let targetSeason = targetSeason, targetSeason > 0 else { return 0 }
        if let seasons = r.seasons, !seasons.isEmpty {
            if seasons.count == 1 && seasons.contains(targetSeason) { return 20 }
            if seasons.contains(targetSeason) { return 10 }
            return -100
        }
        let lower = r.title.lowercased()
        let sToken = String(format: "s%02d", targetSeason)
        let altToken = "сезон \(targetSeason)"
        let isSingleSeason = (lower.contains(sToken) || lower.contains(altToken) || lower.contains("сезон: \(targetSeason)")) &&
            !lower.contains("s01-") && !lower.contains("сезон 1-") && !lower.contains("сезоны 1-")
        if isSingleSeason { return 20 }
        if lower.contains("s01-") || lower.contains("сезон 1-") || lower.contains("сезоны 1-") { return 10 }
        let otherSeasonFound = (1...20).contains { other in
            other != targetSeason && (lower.contains(String(format: "s%02d", other)) || lower.contains("сезон \(other)"))
        }
        if otherSeasonFound { return -100 }
        return 5
    }

    static func selectBestRelease(from torrents: [TorrentRelease], targetSeason: Int? = nil, preferredQuality: String? = nil) -> TorrentRelease? {
        if torrents.isEmpty { return nil }

        // If device does not support hardware HEVC (e.g. Apple TV HD / Apple A8),
        // prioritize hardware-supported H.264 releases first to prevent CPU stuttering
        if !isHardwareHEVCSupported {
            let hwSupported = torrents.filter { !$0.isHEVC }
            if !hwSupported.isEmpty, let bestHw = selectBestReleaseInternal(from: hwSupported, targetSeason: targetSeason, preferredQuality: preferredQuality) {
                return bestHw
            }
        }

        return selectBestReleaseInternal(from: torrents, targetSeason: targetSeason, preferredQuality: preferredQuality)
    }

    private static func selectBestReleaseInternal(from torrents: [TorrentRelease], targetSeason: Int? = nil, preferredQuality: String? = nil) -> TorrentRelease? {
        if torrents.isEmpty { return nil }
        let prefTier = (preferredQuality ?? APIConfig.shared.defaultQuality).lowercased()
        let targetTiers: [String] = {
            if prefTier.contains("4k") || prefTier.contains("2160") {
                return ["4k", "1080p", "720p", "sd"]
            } else if prefTier.contains("720") {
                return ["720p", "1080p", "sd", "4k"]
            } else if prefTier.contains("sd") {
                return ["sd", "720p", "1080p", "4k"]
            } else {
                return ["1080p", "720p", "4k", "sd"]
            }
        }()

        // Pass 1: find in cascade tiers matching target season (score >= 10)
        for tier in targetTiers {
            let inTier = torrents.filter { $0.effectiveTier.lowercased().contains(tier) && seasonMatchScore($0, targetSeason: targetSeason) >= 10 }
            if let best = inTier.max(by: { (seasonMatchScore($0, targetSeason: targetSeason), $0.seeds) < (seasonMatchScore($1, targetSeason: targetSeason), $1.seeds) }) {
                return best
            }
        }

        // Pass 2: find in cascade tiers with general season matching (score >= 0)
        for tier in targetTiers {
            let inTier = torrents.filter { $0.effectiveTier.lowercased().contains(tier) && seasonMatchScore($0, targetSeason: targetSeason) >= 0 }
            if let best = inTier.max(by: { $0.seeds < $1.seeds }) {
                return best
            }
        }

        // Pass 3: find in preferred tiers regardless of season
        for tier in targetTiers {
            let inTier = torrents.filter { $0.effectiveTier.lowercased().contains(tier) }
            if let best = inTier.max(by: { $0.seeds < $1.seeds }) {
                return best
            }
        }

        // Fallback: highest seeds overall
        return torrents.max(by: { $0.seeds < $1.seeds })
    }
}
