import SwiftUI
import NukeUI

struct SeasonPickerView: View {
    let seasons: [SeasonInfo]
    let selectedSeason: Int
    let episodes: [EpisodeInfo]
    let isLoadingEpisodes: Bool
    let seriesProgress: SeriesProgressResponse?
    let onSelectSeason: (Int) -> Void
    let onPlayEpisode: (EpisodeInfo) -> Void
    let onToggleSeasonWatched: (Int) -> Void
    let onToggleEpisodeWatched: (EpisodeInfo) -> Void
    let onMarkAllPriorWatched: (EpisodeInfo) -> Void

    private var currentSeasonSummary: SeasonProgressSummary? {
        seriesProgress?.seasons["\(selectedSeason)"]
    }

    private var isCurrentSeasonCompleted: Bool {
        currentSeasonSummary?.isCompleted == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 24) {
                Text("Сезоны и серии")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.textPrimary)

                Spacer()

                // Mark entire season button
                Button {
                    onToggleSeasonWatched(selectedSeason)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isCurrentSeasonCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isCurrentSeasonCompleted ? .emeraldPrimary : .textSecondary)
                        Text(isCurrentSeasonCompleted ? "Сезон просмотрен" : "Отметить сезон как просмотренный")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isCurrentSeasonCompleted ? .emeraldPrimary : .textSecondary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.obsidianCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isCurrentSeasonCompleted ? Color.emeraldPrimary.opacity(0.6) : Color.obsidianBorder, lineWidth: 1.5)
                    )
                }
                .buttonStyle(TVCardButtonStyle(cornerRadius: 14, focusedScale: 1.05))
            }

            // Season Chips Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(seasons) { s in
                        let summary = seriesProgress?.seasons["\(s.seasonNumber)"]
                        SeasonChipButton(
                            season: s,
                            summary: summary,
                            isSelected: selectedSeason == s.seasonNumber,
                            onFocusOrSelect: {
                                onSelectSeason(s.seasonNumber)
                            }
                        )
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()

            // Episodes Horizontal Row
            if isLoadingEpisodes && episodes.isEmpty {
                HStack(spacing: 14) {
                    ProgressView()
                        .tint(.emeraldPrimary)
                    Text("Загрузка серий...")
                        .font(.system(size: 24))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 32)
            } else if episodes.isEmpty {
                Text("В этом сезоне серии пока не найдены")
                    .font(.system(size: 22))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 32) {
                        ForEach(episodes) { ep in
                            Button {
                                onPlayEpisode(ep)
                            } label: {
                                EpisodeCardView(episode: ep)
                            }
                            .buttonStyle(TVMediaCardButtonStyle())
                            .contextMenu {
                                Button {
                                    onToggleEpisodeWatched(ep)
                                } label: {
                                    Label(
                                        (ep.isPlayed == true) ? "Снять отметку о просмотре" : "Отметить как просмотренную",
                                        systemImage: (ep.isPlayed == true) ? "arrow.counterclockwise" : "checkmark.circle"
                                    )
                                }
                                Button {
                                    onMarkAllPriorWatched(ep)
                                } label: {
                                    Label("Пометить все серии до этой", systemImage: "checklist.checked")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 32)
                }
                .scrollClipDisabled()
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
            }
        }
    }
}

struct SeasonChipButton: View {
    let season: SeasonInfo
    let summary: SeasonProgressSummary?
    let isSelected: Bool
    let onFocusOrSelect: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            onFocusOrSelect()
        } label: {
            HStack(spacing: 10) {
                Text("\(season.seasonNumber) Сезон")
                    .font(.system(size: 24, weight: .semibold))

                if summary?.isCompleted == true {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.emeraldPrimary)
                } else if let watched = summary?.watchedEpisodes, watched > 0 {
                    Text("(\(watched)/\(season.episodeCount))")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.emeraldPrimary.opacity(0.9))
                } else {
                    Text("(\(season.episodeCount) сер.)")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.emeraldPrimary.opacity(0.35) : Color.obsidianCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.emeraldPrimary : Color.obsidianBorder, lineWidth: 2)
            )
        }
        .buttonStyle(TVCardButtonStyle(cornerRadius: 16, focusedScale: 1.05))
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocusOrSelect()
            }
        }
    }
}

struct EpisodeCardView: View {
    @Environment(\.isFocused) private var isFocused
    let episode: EpisodeInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                LazyImage(url: episode.effectiveStillURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.obsidianElevated
                    }
                }
                .frame(width: 400, height: 225)
                .clipped()

                // Bottom gradient & episode number
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.9)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)

                // Top Watched Badge
                if episode.isPlayed == true {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Просмотрено")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.85))
                            .foregroundColor(.emeraldPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.emeraldPrimary.opacity(0.6), lineWidth: 1)
                            )
                            .padding(10)
                        }
                        Spacer()
                    }
                }

                HStack {
                    Text("Серия \(episode.episodeNumber)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let dur = episode.resumeSeconds, dur > 0, episode.isPlayed != true {
                        Text("▶ \(Int(dur / 60)) мин")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.emeraldPrimary)
                    }
                }
                .padding(16)
            }
            .frame(width: 400, height: 225)
            .background(Color.obsidianCard)
            .tvCardFocusModifier(cornerRadius: 18, focusedScale: 1.06)

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.name)
                    .font(.system(size: 22, weight: isFocused ? .heavy : .semibold))
                    .foregroundColor(isFocused ? .white : .textPrimary)
                    .lineLimit(1)

                if let ov = episode.overview, !ov.isEmpty {
                    Text(ov)
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(4)
                }
            }
            .frame(width: 400, alignment: .leading)
        }
        .frame(width: 400)
    }
}
