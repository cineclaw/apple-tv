import Foundation
import os

final class CineClawClient: Sendable {
    static let shared = CineClawClient()
    private let logger = Logger(subsystem: "com.cineclaw.tvos", category: "Network")

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: config)
    }()

    private let aiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    private var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return dec
    }

    private func makeURL(path: String, queryItems: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(string: APIConfig.shared.baseURL) else { return nil }
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }

    private func makeRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        if let token = SessionManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: - Home BFF
    func getHomeFeed(refresh: Bool = false) async throws -> HomePayload {
        guard let url = makeURL(path: "/api/home", queryItems: [
            URLQueryItem(name: "platform", value: "tv"),
            URLQueryItem(name: "refresh", value: refresh ? "true" : "false")
        ]) else {
            throw URLError(.badURL)
        }

        let req = makeRequest(url: url)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(HomePayload.self, from: data)
    }

    // MARK: - Search
    func search(query: String, limit: Int = 30) async throws -> [SearchResultItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        guard let url = makeURL(path: "/search", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]) else {
            throw URLError(.badURL)
        }

        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        let res = try decoder.decode(SearchResponse.self, from: data)
        return res.effectiveResults
    }

    // MARK: - Details & Metadata
    func getMovieMetadata(tconst: String) async throws -> MovieMetadataResponse {
        guard let url = makeURL(path: "/api/movie/\(tconst)/metadata") else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(MovieMetadataResponse.self, from: data)
    }

    func getSeriesSeasons(tconst: String) async throws -> [SeasonInfo] {
        guard let url = makeURL(path: "/api/series/\(tconst)/seasons") else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        let res = try decoder.decode(SeriesSeasonsResponse.self, from: data)
        // Purge specials (season 0)
        return res.seasons.filter { $0.seasonNumber > 0 }
    }

    func getSeriesEpisodes(tconst: String, season: Int = 1) async throws -> [EpisodeInfo] {
        guard let url = makeURL(path: "/api/series/\(tconst)/episodes", queryItems: [
            URLQueryItem(name: "season", value: "\(season)")
        ]) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode([EpisodeInfo].self, from: data)
    }

    // MARK: - Torrents & Streaming
    func getTorrents(imdbId: String?, query: String?) async throws -> [TorrentRelease] {
        var items: [URLQueryItem] = []
        if let id = imdbId, !id.isEmpty { items.append(URLQueryItem(name: "imdb_id", value: id)) }
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }

        guard let url = makeURL(path: "/torrents", queryItems: items) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode([TorrentRelease].self, from: data)
    }

    func resolveTmdb(mediaType: String, tmdbId: Int64) async throws -> TmdbResolveResponse {
        let type = mediaType.lowercased().contains("tv") ? "tv" : "movie"
        guard let url = makeURL(path: "/api/tmdb/\(type)/\(tmdbId)/movie") else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(TmdbResolveResponse.self, from: data)
    }

    func mountTorrent(tconst: String, title: String?, magnet: String?, hash: String?, type: String? = nil, season: Int? = nil, episode: Int? = nil) async throws -> Bool {
        guard let url = makeURL(path: "/api/stream/mount") else {
            throw URLError(.badURL)
        }
        let effectiveMagnet = magnet ?? (hash != nil ? "magnet:?xt=urn:btih:\(hash!)" : "")
        let effectiveType = type ?? (season != nil && season! > 0 ? "tvSeries" : "movie")
        let payload = MountTorrentRequest(
            tconst: tconst,
            title: title,
            magnet: effectiveMagnet,
            hash: hash,
            type: effectiveType,
            season: season,
            episode: episode
        )
        let body = try JSONEncoder().encode(payload)
        let req = makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            logger.error("Mount error response: \(msg)")
            return false
        }
        return true
    }

    func getPlayerInfo(tconst: String, season: Int? = nil, episode: Int? = nil) async throws -> PlayerInfoResponse {
        var queryItems = [URLQueryItem(name: "tconst", value: tconst)]
        if let s = season, s > 0 {
            queryItems.append(URLQueryItem(name: "season", value: "\(s)"))
        }
        if let e = episode, e > 0 {
            queryItems.append(URLQueryItem(name: "episode", value: "\(e)"))
        }

        guard let url = makeURL(path: "/api/stream/player/info", queryItems: queryItems) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            logger.error("getPlayerInfo error: \(msg)")
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(PlayerInfoResponse.self, from: data)
    }

    // MARK: - Playback Progress & Watchlist
    func reportProgress(
        tconst: String,
        title: String,
        isTv: Bool = false,
        season: Int? = nil,
        episode: Int? = nil,
        position: Double,
        duration: Double,
        percent: Double? = nil
    ) async {
        guard let url = makeURL(path: "/api/playback/progress") else { return }
        let calcPercent: Double = {
            if let p = percent { return p }
            if duration > 0 { return (position / duration) * 100.0 }
            return 0.0
        }()
        let payload = WatchProgressRequest(
            imdbId: tconst,
            title: title,
            mediaType: isTv ? "tv" : "movie",
            seasonNumber: season ?? 0,
            episodeNumber: episode ?? 0,
            positionSeconds: position,
            durationSeconds: duration,
            playbackPercent: calcPercent,
            isCompleted: calcPercent >= 90.0
        )
        guard let body = try? JSONEncoder().encode(payload) else { return }
        let req = makeRequest(url: url, method: "POST", body: body)
        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                logger.info("Reported progress for \(tconst): \(position)s/\(duration)s (\(Int(calcPercent))%)")
                await MainActor.run {
                    NotificationCenter.default.post(name: .playbackProgressDidChange, object: nil)
                }
            } else {
                let msg = String(data: data, encoding: .utf8) ?? ""
                logger.error("Failed to report progress: \(msg)")
            }
        } catch {
            logger.error("Network error reporting progress: \(error.localizedDescription)")
        }
    }

    func setAudioPreference(imdbId: String, title: String) async {
        guard let url = makeURL(path: "/api/playback/audio") else { return }
        let payload = AudioPreferenceRequest(imdbId: imdbId, preferredAudioTitle: title)
        guard let body = try? JSONEncoder().encode(payload) else { return }
        let req = makeRequest(url: url, method: "POST", body: body)
        _ = try? await session.data(for: req)
    }

    func deleteResumeItem(tconst: String) async throws {
        guard let url = makeURL(path: "/api/playback/delete", queryItems: [
            URLQueryItem(name: "imdb_id", value: tconst)
        ]) else { return }
        let req = makeRequest(url: url, method: "DELETE")
        _ = try await session.data(for: req)
        await MainActor.run {
            NotificationCenter.default.post(name: .playbackProgressDidChange, object: nil)
        }
    }

    func getSeriesProgress(imdbId: String) async throws -> SeriesProgressResponse {
        guard let url = makeURL(path: "/api/playback/series-progress", queryItems: [
            URLQueryItem(name: "imdb_id", value: imdbId)
        ]) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(SeriesProgressResponse.self, from: data)
    }

    func markWatched(
        imdbId: String,
        mode: String,
        title: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        upToSeason: Int? = nil,
        upToEpisode: Int? = nil,
        completed: Bool = true
    ) async throws {
        guard let url = makeURL(path: "/api/playback/mark-watched") else { return }
        let payload = MarkWatchedRequest(
            imdbId: imdbId,
            mode: mode,
            title: title,
            season: season,
            episode: episode,
            upToSeason: upToSeason,
            upToEpisode: upToEpisode,
            completed: completed
        )
        guard let body = try? JSONEncoder().encode(payload) else { return }
        let req = makeRequest(url: url, method: "POST", body: body)
        _ = try await session.data(for: req)
        await MainActor.run {
            NotificationCenter.default.post(name: .playbackProgressDidChange, object: nil)
        }
    }

    func getCriticSummary(tconst: String) async throws -> CriticSummaryResponse {
        guard let url = makeURL(path: "/api/ai/critics/\(tconst)") else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, response) = try await aiSession.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            logger.warning("getCriticSummary returned HTTP \(http.statusCode) for \(tconst, privacy: .public)")
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(CriticSummaryResponse.self, from: data)
    }

    func getWatchlist() async throws -> [HomeItem] {
        guard let url = makeURL(path: "/api/watchlist") else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        let items = try decoder.decode([WatchlistItemResponse].self, from: data)
        return items.map { $0.toHomeItem() }
    }

    func checkWatchlist(tconst: String) async throws -> Bool {
        guard let url = makeURL(path: "/api/watchlist/check", queryItems: [
            URLQueryItem(name: "imdb_id", value: tconst)
        ]) else { return false }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        let res = try decoder.decode(WatchlistCheckResponse.self, from: data)
        return res.inWatchlist
    }

    func addToWatchlist(item: HomeItem) async throws {
        guard let url = makeURL(path: "/api/watchlist") else { return }
        let payload = WatchlistAddRequest(
            imdbId: item.effectiveTconst,
            mediaType: item.isTv ? "tv" : "movie",
            title: item.title,
            originalTitle: item.originalTitle,
            year: item.year,
            rating: item.rating,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath
        )
        let body = try JSONEncoder().encode(payload)
        let req = makeRequest(url: url, method: "POST", body: body)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            logger.error("addToWatchlist error: \(msg)")
            throw URLError(.badServerResponse)
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .watchlistDidChange, object: nil)
        }
    }

    func removeFromWatchlist(tconst: String) async throws {
        guard let url = makeURL(path: "/api/watchlist", queryItems: [
            URLQueryItem(name: "imdb_id", value: tconst)
        ]) else { return }
        let req = makeRequest(url: url, method: "DELETE")
        _ = try await session.data(for: req)
        await MainActor.run {
            NotificationCenter.default.post(name: .watchlistDidChange, object: nil)
        }
    }

    func getShelfFeed(id: String, page: Int = 1) async throws -> HomeShelf {
        // 1. Hotlist tracker shelves
        if id.contains("4k") || id.contains("uhd") {
            return try await getHotlistShelf(type: "movie", quality: "4k", page: page, shelfId: id, title: "4K UHD Кинозал")
        }
        if id.contains("anime") {
            return try await getHotlistShelf(type: "anime", quality: nil, page: page, shelfId: id, title: "Аниме & Мультипликация")
        }
        if id.contains("doc") {
            return try await getHotlistShelf(type: "doc", quality: nil, page: page, shelfId: id, title: "Документальное кино")
        }
        if id.contains("new_movie") {
            return try await getHotlistShelf(type: "new_movie", quality: nil, page: page, shelfId: id, title: "Новинки кино")
        }
        if id.contains("new_tv") {
            return try await getHotlistShelf(type: "new_tv", quality: nil, page: page, shelfId: id, title: "Новинки сериалов")
        }

        // 2. Curated TMDB feeds
        guard let url = makeURL(path: "/api/feeds/\(id)", queryItems: [
            URLQueryItem(name: "page", value: "\(page)")
        ]) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(HomeShelf.self, from: data)
    }

    private func getHotlistShelf(type: String, quality: String?, page: Int, shelfId: String, title: String) async throws -> HomeShelf {
        var queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "30")
        ]
        if let q = quality {
            queryItems.append(URLQueryItem(name: "quality", value: q))
        }
        guard let url = makeURL(path: "/torrents/hotlist", queryItems: queryItems) else {
            throw URLError(.badURL)
        }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(HomeShelf.self, from: data)
    }

    func checkPairingStatus(code: String) async throws -> PairingStatusResponse {
        guard let url = makeURL(path: "/api/auth/pair/status", queryItems: [
            URLQueryItem(name: "code", value: code)
        ]) else { throw URLError(.badURL) }
        let req = makeRequest(url: url)
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(PairingStatusResponse.self, from: data)
    }

    func login(username: String, password: String, customBaseURL: String? = nil) async throws -> LoginResponse {
        let base = customBaseURL ?? APIConfig.shared.baseURL
        guard var components = URLComponents(string: base) else {
            throw URLError(.badURL)
        }
        components.path = "/api/auth/login"
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let body = try JSONEncoder().encode(LoginRequest(
            username: username,
            password: password,
            rememberMe: true
        ))

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = body
        req.timeoutInterval = 10

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 {
            throw NSError(domain: "CineClawAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Неверный логин или пароль"])
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CineClawAuth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Сервер ответил ошибкой (HTTP \(http.statusCode))"])
        }

        return try decoder.decode(LoginResponse.self, from: data)
    }

    func pingServer(baseURL: String? = nil) async -> Bool {
        let base = baseURL ?? APIConfig.shared.baseURL
        guard var components = URLComponents(string: base) else { return false }
        components.path = "/"
        guard let url = components.url else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 3
        do {
            let (_, response) = try await session.data(for: req)
            guard let code = (response as? HTTPURLResponse)?.statusCode else { return false }
            return (200...401).contains(code)
        } catch {
            return false
        }
    }

    // MARK: - Transcode Management
    func stopTranscoding(hash: String? = nil, session sessionID: String? = nil) async {
        guard let url = makeURL(path: "/api/stream/transcode/stop") else { return }
        var dict: [String: String] = [:]
        if let h = hash { dict["hash"] = h }
        if let s = sessionID { dict["session"] = s }
        guard let body = try? JSONSerialization.data(withJSONObject: dict) else { return }
        let req = makeRequest(url: url, method: "POST", body: body)
        _ = try? await session.data(for: req)
    }
}

extension Notification.Name {
    static let watchlistDidChange = Notification.Name("CineClawWatchlistDidChange")
    static let playbackProgressDidChange = Notification.Name("CineClawPlaybackProgressDidChange")
}

