import SwiftUI
import NukeUI

struct ContinueWatchingRow: View {
    let shelf: HomeShelf
    let onSelect: (HomeItem) -> Void
    let onDelete: (HomeItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Text(shelf.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.textPrimary)

                TagBadge(text: "Продолжить", color: Color.emeraldPrimary.opacity(0.25), textColor: .emeraldPrimary)
            }
            .padding(.horizontal, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 36) {
                    ForEach(shelf.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            ContinueWatchingCard(item: item)
                        }
                        .buttonStyle(TVMediaCardButtonStyle())
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 36)
            }
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusSection()
    }
}

struct ContinueWatchingCard: View {
    @Environment(\.isFocused) private var isFocused
    let item: HomeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                LazyImage(url: item.effectiveCardImageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 420, height: 236, alignment: .top)
                            .clipped()
                    } else {
                        Color.obsidianElevated
                    }
                }
                .frame(width: 420, height: 236, alignment: .top)
                .clipped()

                // Top Next Up badge
                if item.isNextUp == true {
                    VStack {
                        HStack {
                            Spacer()
                            TagBadge(text: "Далее", color: .emeraldPrimary, textColor: .black)
                                .padding(12)
                        }
                        Spacer()
                    }
                }

                // Bottom gradient & progress
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.92)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)

                    // Emerald progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                            Rectangle()
                                .fill(Color.emeraldPrimary)
                                .frame(width: geo.size.width * CGFloat(min(100, max(0, item.playbackPercent ?? 0))) / 100.0)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .frame(width: 420, height: 236)
            .background(Color.obsidianCard)
            .tvCardFocusModifier(cornerRadius: 18, focusedScale: 1.06)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 24, weight: isFocused ? .heavy : .bold))
                    .foregroundColor(isFocused ? .white : .textPrimary)
                    .lineLimit(1)

                if item.isNextUp == true {
                    if let s = item.season, let e = item.episode {
                        Text("Сезон \(s), Серия \(e)\(item.episodeTitle.map { ": \($0)" } ?? "")")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.emeraldPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Следующая серия")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.emeraldPrimary)
                    }
                } else if let s = item.season, let e = item.episode {
                    Text("Сезон \(s), Серия \(e)\(item.timecode.map { " • \($0)" } ?? "")")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                } else if let tc = item.timecode, !tc.isEmpty {
                    Text("Остановлено: \(tc)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 420, alignment: .leading)
        }
        .frame(width: 420)
    }
}
