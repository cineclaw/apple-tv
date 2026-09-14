import Foundation

struct CriticSummaryResponse: Codable, Sendable {
    let tconst: String
    let verdict: String
    let tone: String
    let scores: CriticScores
    let pros: [String]
    let cons: [String]
    let targetAudience: String
    let model: String?
    let cached: Bool?

    var isCached: Bool { cached ?? false }

    enum CodingKeys: String, CodingKey {
        case tconst
        case verdict
        case tone
        case scores
        case pros
        case cons
        case targetAudience
        case model
        case cached
    }

    init(
        tconst: String = "",
        verdict: String = "",
        tone: String = "positive",
        scores: CriticScores = CriticScores(),
        pros: [String] = [],
        cons: [String] = [],
        targetAudience: String = "",
        model: String? = nil,
        cached: Bool? = false
    ) {
        self.tconst = tconst
        self.verdict = verdict
        self.tone = tone
        self.scores = scores
        self.pros = pros
        self.cons = cons
        self.targetAudience = targetAudience
        self.model = model
        self.cached = cached
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tconst = (try? container.decodeIfPresent(String.self, forKey: .tconst)) ?? ""
        self.verdict = (try? container.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
        self.tone = (try? container.decodeIfPresent(String.self, forKey: .tone)) ?? "positive"
        self.scores = (try? container.decodeIfPresent(CriticScores.self, forKey: .scores)) ?? CriticScores()
        self.pros = (try? container.decodeIfPresent([String].self, forKey: .pros)) ?? []
        self.cons = (try? container.decodeIfPresent([String].self, forKey: .cons)) ?? []
        self.targetAudience = (try? container.decodeIfPresent(String.self, forKey: .targetAudience)) ?? ""
        self.model = try? container.decodeIfPresent(String.self, forKey: .model)
        self.cached = (try? container.decodeIfPresent(Bool.self, forKey: .cached)) ?? false
    }
}

struct CriticScores: Codable, Sendable {
    let rottenTomatoes: Int?
    let metacritic: Int?
    let imdb: Double?
    let imdbVotes: String?
    let awards: String?

    enum CodingKeys: String, CodingKey {
        case rottenTomatoes
        case metacritic
        case imdb
        case imdbVotes
        case awards
    }

    init(
        rottenTomatoes: Int? = nil,
        metacritic: Int? = nil,
        imdb: Double? = nil,
        imdbVotes: String? = nil,
        awards: String? = nil
    ) {
        self.rottenTomatoes = rottenTomatoes
        self.metacritic = metacritic
        self.imdb = imdb
        self.imdbVotes = imdbVotes
        self.awards = awards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rottenTomatoes = try? container.decodeIfPresent(Int.self, forKey: .rottenTomatoes)
        self.metacritic = try? container.decodeIfPresent(Int.self, forKey: .metacritic)
        self.imdb = try? container.decodeIfPresent(Double.self, forKey: .imdb)
        self.imdbVotes = try? container.decodeIfPresent(String.self, forKey: .imdbVotes)
        self.awards = try? container.decodeIfPresent(String.self, forKey: .awards)
    }
}
