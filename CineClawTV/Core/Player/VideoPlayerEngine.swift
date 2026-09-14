import Foundation
import SwiftUI

struct AudioTrackOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let language: String
    let codec: String
    let channels: String

    var displayName: String {
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

struct SubtitleTrackOption: Identifiable, Hashable, Sendable {
    let id: String // "off" for disabled
    let title: String
    let language: String

    var displayName: String {
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
protocol VideoPlayerEngine: AnyObject {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var audioTracks: [AudioTrackOption] { get }
    var subtitleTracks: [SubtitleTrackOption] { get }
    var currentAudioTrackId: String { get }
    var currentSubtitleTrackId: String { get }

    func load(url: URL, initialSeek: Double?)
    func play()
    func pause()
    func togglePlayPause()
    func seek(to seconds: Double)
    func selectAudio(trackId: String)
    func selectSubtitle(trackId: String)
    func stop()
}
