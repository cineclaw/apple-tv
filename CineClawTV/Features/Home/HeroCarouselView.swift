import SwiftUI
import NukeUI

struct HeroCarouselView: View {
    let items: [HomeItem]
    let onPlay: (HomeItem) -> Void
    let onDetails: (HomeItem) -> Void

    @State private var currentIndex: Int = 0

    var currentHero: HomeItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    var body: some View {
        if let hero = currentHero {
            ZStack(alignment: .bottomLeading) {
                // Backdrop Image with edge-to-edge gradient overlays
                GeometryReader { geo in
                    ZStack {
                        LazyImage(url: hero.effectiveBackdropURL) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: 880, alignment: .top)
                                    .clipped()
                            } else {
                                Color.obsidianBackground
                            }
                        }
                        .frame(width: geo.size.width, height: 880, alignment: .top)
                        .clipped()

                        // Subtle top vignette for floating tvOS TabBar contrast
                        LinearGradient(
                            stops: [
                                .init(color: Color.obsidianBackground.opacity(0.45), location: 0.0),
                                .init(color: Color.obsidianBackground.opacity(0.15), location: 0.12),
                                .init(color: .clear, location: 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // Smooth vertical obsidian fade into background at bottom
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.45),
                                .init(color: Color.obsidianBackground.opacity(0.35), location: 0.70),
                                .init(color: Color.obsidianBackground.opacity(0.85), location: 0.90),
                                .init(color: Color.obsidianBackground, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // Gentle leading vignette for text legibility without muddying artwork
                        LinearGradient(
                            stops: [
                                .init(color: Color.obsidianBackground.opacity(0.65), location: 0.0),
                                .init(color: Color.obsidianBackground.opacity(0.35), location: 0.28),
                                .init(color: Color.obsidianBackground.opacity(0.10), location: 0.50),
                                .init(color: .clear, location: 0.70)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
                .frame(height: 880)

                // Foreground Content
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        TagBadge(text: "🔥 ТРЕНДЫ НЕДЕЛИ #\(currentIndex + 1)", color: .emeraldPrimary, textColor: .black)

                        if items.count > 1 {
                            HStack(spacing: 8) {
                                ForEach(0..<items.count, id: \.self) { idx in
                                    Circle()
                                        .fill(idx == currentIndex ? Color.emeraldPrimary : Color.white.opacity(0.35))
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                    }

                    Text(hero.title)
                        .font(.system(size: 56, weight: .black))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.9), radius: 12)

                    HStack(spacing: 16) {
                        if let rating = hero.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Text("★")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.ratingGold)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if let year = hero.year, year > 0 {
                            Text(String(year))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }

                        if let seeds = hero.seeds, seeds > 0 {
                            Text("🌱 \(seeds) сидов")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.emeraldPrimary)
                        }
                    }

                    if let overview = hero.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.textSecondary)
                            .lineSpacing(4)
                            .lineLimit(3)
                            .frame(maxWidth: 960, alignment: .leading)
                            .shadow(color: .black.opacity(0.7), radius: 6)
                    }

                    HStack(spacing: 24) {
                        Button {
                            onPlay(hero)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                Text("Смотреть")
                            }
                        }
                        .buttonStyle(EmeraldButtonStyle(isPrimary: true))

                        Button {
                            onDetails(hero)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                Text("Подробнее")
                            }
                        }
                        .buttonStyle(EmeraldButtonStyle(isPrimary: false))

                        if items.count > 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    currentIndex = (currentIndex + 1) % items.count
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(EmeraldButtonStyle(isPrimary: false))
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 880)
            .focusSection()
        }
    }
}
