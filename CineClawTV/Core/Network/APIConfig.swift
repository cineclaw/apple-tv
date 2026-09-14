import Foundation
import SwiftUI
import VideoToolbox

enum DeviceCapabilities {
    static var isLegacyAppleTV: Bool {
        #if os(tvOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        // AppleTV5,3 is Apple TV HD (4th gen, A8 chip with NO hardware HEVC decoding)
        if identifier.starts(with: "AppleTV5") {
            return true
        }
        #endif
        return false
    }

    static var supportsHardwareHEVC: Bool {
        if isLegacyAppleTV { return false }
        if #available(tvOS 11.0, *) {
            return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        }
        return false
    }
}

enum PlaybackMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "auto"
    case transcodeH264 = "transcode_h264"
    case direct = "direct"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Авто (HEVC/4K транскод)"
        case .transcodeH264: return "Всегда H.264 (Apple TV HD)"
        case .direct: return "Прямой поток (Direct MKV)"
        }
    }
}

@Observable
final class APIConfig: @unchecked Sendable {
    static let shared = APIConfig()

    var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "cineclaw_base_url")
            NotificationCenter.default.post(name: .serverOrSessionDidChange, object: nil)
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

    var playbackMode: PlaybackMode {
        didSet {
            UserDefaults.standard.set(playbackMode.rawValue, forKey: "cineclaw_playback_mode")
        }
    }

    var transcodeQuality: String {
        didSet {
            UserDefaults.standard.set(transcodeQuality, forKey: "cineclaw_transcode_quality")
        }
    }

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "cineclaw_base_url") ?? "http://192.168.88.19:3000"
        self.defaultQuality = UserDefaults.standard.string(forKey: "cineclaw_default_quality") ?? "1080p"
        self.audioPassthrough = UserDefaults.standard.bool(forKey: "cineclaw_audio_passthrough")

        let modeRaw = UserDefaults.standard.string(forKey: "cineclaw_playback_mode") ?? PlaybackMode.auto.rawValue
        self.playbackMode = PlaybackMode(rawValue: modeRaw) ?? .auto
        self.transcodeQuality = UserDefaults.standard.string(forKey: "cineclaw_transcode_quality") ?? "1080p"
    }

    func setCleanBaseURL(_ url: String) {
        var clean = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            clean = "http://\(clean)"
        }
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        self.baseURL = clean
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

    func streamURL(for pathOrStream: String) -> URL? {
        if pathOrStream.hasPrefix("http://") || pathOrStream.hasPrefix("https://") {
            return URL(string: pathOrStream)
        }
        let clean = pathOrStream.hasPrefix("/") ? pathOrStream : "/\(pathOrStream)"
        if clean.hasPrefix("/api/") {
            // Proxied via Nginx / tracker-proxy on main baseURL (port 3000)
            return URL(string: "\(baseURL)\(clean)")
        }
        return torrServerURL(for: clean)
    }
}
