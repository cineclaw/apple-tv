import Foundation
import SwiftUI

@Observable
final class APIConfig: @unchecked Sendable {
    static let shared = APIConfig()

    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "cineclaw_base_url")
        }
    }

    var defaultQuality: String {
        didSet {
            UserDefaults.standard.set(defaultQuality, forKey: "cineclaw_default_quality")
        }
    }

    var audioPassthrough: Bool {
        didSet {
            UserDefaults.standard.set(audioPassthrough, forKey: "cineclaw_audio_passthrough")
        }
    }

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "cineclaw_base_url") ?? "http://192.168.88.126:3000"
        self.defaultQuality = UserDefaults.standard.string(forKey: "cineclaw_default_quality") ?? "1080p"
        self.audioPassthrough = UserDefaults.standard.bool(forKey: "cineclaw_audio_passthrough")
    }

    func torrServerURL(for pathOrStream: String) -> URL? {
        if pathOrStream.hasPrefix("http://") || pathOrStream.hasPrefix("https://") {
            return URL(string: pathOrStream)
        }
        guard var components = URLComponents(string: baseURL) else { return nil }
        // TorrServer direct on port 8092 gives lowest latency and keyframe seek speed
        components.port = 8092
        let directBase = components.string ?? baseURL

        let clean = pathOrStream.hasPrefix("/") ? pathOrStream : "/\(pathOrStream)"
        // TorrServer native port 8092 does not have "/torr" prefix (which is Nginx-only)
        let pathFor8092 = clean.hasPrefix("/torr/") ? String(clean.dropFirst(5)) : clean
        return URL(string: "\(directBase)\(pathFor8092)")
    }
}
