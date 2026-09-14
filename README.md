# CineClaw Apple TV (`apple-tv`)

Native tvOS cinema client (`com.andvikt.cineclaw`) crafted in Swift 6 and SwiftUI with KSPlayer (FFmpeg + Metal).

## Tech Stack
- **Swift 6 & SwiftUI** (tvOS 18+)
- **KSPlayer**: Native audio/video playback engine with zero-copy Metal rendering.
- **XcodeGen**: Declarative Xcode project management (`project.yml`).

## Features
- **Infuse-Grade Living Room UI**: Obsidian cinema theme (`#07090E`), edge-to-edge ambient backdrop headers, card hover/focus scaling with glowing emerald borders.
- **Hardware-Accelerated Zero-Transcode Streaming**: Native MKV, Dolby Digital / DTS / TrueHD audio, WebVTT/ASS subtitle tracks directly from TorrServer MatriX.
- **Siri Remote Ergonomics**: D-Pad navigation, click-pad scrub gestures, interactive timeline deltas.
- **Grouped Quality & Audio Track Selectors**: Instant sub-100ms switching between 4K UHD, 1080p, 720p, and dubbed audio streams.

## Build & Install
```bash
# Generate Xcode project
xcodegen generate

# Build Debug app for physical Apple TV
xcodebuild -project CineClawTV.xcodeproj -scheme CineClawTV -destination "id=<DEVICE_ID>" -configuration Debug build

# Install to Apple TV via devicectl
xcrun devicectl device install app --device "<DEVICE_ID>" "<PATH_TO_APP>"
```
