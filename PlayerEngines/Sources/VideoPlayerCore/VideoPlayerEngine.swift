import Foundation
import UIKit
import SwiftUI

public struct AudioTrackOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let language: String
    public let codec: String
    public let channels: String

    public init(id: String, title: String, language: String, codec: String, channels: String) {
        self.id = id
        self.title = title
        self.language = language
        self.codec = codec
        self.channels = channels
    }

    public var displayName: String {
        var parts: [String] = []
        if !language.isEmpty && language != "und" {
            parts.append(language.uppercased())
        }
        if !title.isEmpty {
            parts.append(title)
        }
        if !codec.isEmpty {
            parts.append(codec.uppercased())
        }
        if !channels.isEmpty {
            parts.append(channels)
        }
        return parts.isEmpty ? "Аудиодорожка \(id)" : parts.joined(separator: " • ")
    }
}

public struct SubtitleTrackOption: Identifiable, Hashable, Sendable {
    public let id: String // "off" for disabled
    public let title: String
    public let language: String

    public init(id: String, title: String, language: String) {
        self.id = id
        self.title = title
        self.language = language
    }

    public var displayName: String {
        if id == "off" {
            return "Выключить субтитры"
        }
        var parts: [String] = []
        if !language.isEmpty && language != "und" {
            parts.append(language.uppercased())
        }
        if !title.isEmpty {
            parts.append(title)
        }
        return parts.isEmpty ? "Субтитры \(id)" : parts.joined(separator: " • ")
    }
}

@MainActor
public protocol VideoPlayerEngine: AnyObject {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var audioTracks: [AudioTrackOption] { get }
    var subtitleTracks: [SubtitleTrackOption] { get }
    var currentAudioTrackId: String { get }
    var currentSubtitleTrackId: String { get }

    var onVideoViewReady: ((UIView) -> Void)? { get set }
    var videoSurfaceView: UIView? { get }

    func load(url: URL, initialSeek: Double?)
    func load(url: URL, initialSeek: Double?, preferredAudio: String?)
    func switchStream(url: URL, initialSeek: Double?)
    func switchStream(url: URL, initialSeek: Double?, preferredAudio: String?)
    func play()
    func pause()
    func togglePlayPause()
    func seek(to seconds: Double)
    func selectAudio(trackId: String)
    func selectSubtitle(trackId: String)
    func stop()
}

public extension VideoPlayerEngine {
    func load(url: URL, initialSeek: Double?) {
        load(url: url, initialSeek: initialSeek, preferredAudio: nil)
    }

    func load(url: URL, initialSeek: Double?, preferredAudio: String?) {
        load(url: url, initialSeek: initialSeek)
    }

    func switchStream(url: URL, initialSeek: Double?) {
        switchStream(url: url, initialSeek: initialSeek, preferredAudio: nil)
    }

    func switchStream(url: URL, initialSeek: Double?, preferredAudio: String?) {
        load(url: url, initialSeek: initialSeek, preferredAudio: preferredAudio)
    }
}

