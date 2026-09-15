import SwiftUI
import NukeUI

enum DetailsFocusField: Hashable {
    case back
    case play
    case watchlist
    case quality
    case critics
}

struct DetailsView: View {
    @State private var viewModel: DetailsViewModel
    @State private var showQualitySheet: Bool = false
    @State private var activePlayback: PlaybackTarget?
    @State private var pendingCatchUpEpisode: EpisodeInfo? = nil
    @State private var showCatchUpAlert: Bool = false
    @FocusState private var focusedField: DetailsFocusField?
    var onDismiss: (() -> Void)? = nil

    init(
        item: HomeItem,
        onDismiss: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: DetailsViewModel(item: item))
        self.onDismiss = onDismiss
    }

    init(
        tconst: String,
        initialTitle: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: DetailsViewModel(tconst: tconst, initialTitle: initialTitle))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.obsidianBackground.ignoresSafeArea()

            if let meta = viewModel.metadata {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 40) {
                        // Hero Backdrop Section (Edge-to-Edge 1920x880)
                        ZStack(alignment: .topLeading) {
                            LazyImage(url: meta.effectiveBackdropURL) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 1920, height: 880, alignment: .top)
                                        .clipped()
                                } else {
                                    Color.obsidianBackground
                                        .frame(width: 1920, height: 880)
                                }
                            }
                            .frame(width: 1920, height: 880, alignment: .top)

                            // Subtle top vignette for Back button contrast
                            LinearGradient(
                                stops: [
                                    .init(color: Color.obsidianBackground.opacity(0.45), location: 0.0),
                                    .init(color: Color.obsidianBackground.opacity(0.15), location: 0.12),
                                    .init(color: .clear, location: 0.25)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: 1920, height: 880)

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
                            .frame(width: 1920, height: 880)

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
                            .frame(width: 1920, height: 880)

                            // Top-left Back button inside backdrop
                            if let dismissAction = onDismiss {
                                Button {
                                    dismissAction()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 20, weight: .bold))
                                        Text("Назад")
                                            .font(.system(size: 22, weight: .semibold))
                                    }
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.obsidianElevated.opacity(0.85))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(TVCardButtonStyle(cornerRadius: 24, focusedScale: 1.08))
                                .focused($focusedField, equals: .back)
                                .disabled(showQualitySheet)
                                .padding(.top, 48)
                                .padding(.leading, 80)
                            }

                            // Title, Badges and Action Buttons
                            VStack(alignment: .leading, spacing: 20) {
                                Text(meta.title)
                                    .font(.system(size: 60, weight: .black))
                                    .foregroundColor(.textPrimary)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.9), radius: 12)

                                // Metadata row
                                HStack(spacing: 18) {
                                    if let rating = meta.rating, rating > 0 {
                                        HStack(spacing: 4) {
                                            Text("★")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.ratingGold)
                                            Text(String(format: "%.1f", rating))
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.black.opacity(0.65))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }

                                    if let year = meta.year, year > 0 {
                                        Text(String(year))
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(.textSecondary)
                                    }

                                    if let runtime = meta.runtimeMinutes, runtime > 0 {
                                        let h = runtime / 60
                                        let m = runtime % 60
                                        Text(h > 0 ? "\(h) ч \(m) мин" : "\(m) мин")
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                    }

                                    if let rel = viewModel.selectedRelease {
                                        TagBadge(text: rel.effectiveTier, color: .emeraldPrimary.opacity(0.25), textColor: .emeraldPrimary)
                                        if rel.seeds > 0 {
                                            Text("🌱 \(rel.seeds) сидов")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.emeraldPrimary)
                                        }
                                        if !rel.sizeFormatted.isEmpty {
                                            Text(rel.sizeFormatted)
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundColor(.textMuted)
                                        }
                                    }
                                }

                                if let ov = meta.overview, !ov.isEmpty {
                                    Text(ov)
                                        .font(.system(size: 22, weight: .regular))
                                        .foregroundColor(.textSecondary)
                                        .lineSpacing(6)
                                        .lineLimit(4)
                                        .frame(maxWidth: 980, alignment: .leading)
                                        .shadow(color: .black.opacity(0.7), radius: 6)
                                }

                                // Primary Action Buttons
                                HStack(spacing: 24) {
                                    Button {
                                        let s = viewModel.isTv ? viewModel.selectedSeasonNumber : nil
                                        let e = viewModel.isTv ? (viewModel.episodes.first?.episodeNumber ?? 1) : nil
                                        let rel: TorrentRelease? = {
                                            if let chosen = viewModel.selectedRelease {
                                                if let targetS = s {
                                                    if viewModel.seasonMatchScore(chosen, targetSeason: targetS) >= 0 {
                                                        return chosen
                                                    }
                                                } else {
                                                    return chosen
                                                }
                                            }
                                            if let targetS = s {
                                                return viewModel.selectBestRelease(forSeason: targetS)
                                            }
                                            return viewModel.selectBestRelease()
                                        }()
                                        if let r = rel {
                                            activePlayback = PlaybackTarget(
                                                tconst: viewModel.effectiveTconst,
                                                release: r,
                                                title: viewModel.metadata?.title ?? viewModel.initialTitle,
                                                season: s,
                                                episode: e,
                                                qualityGroups: viewModel.qualityGroups
                                            )
                                        }
                                    } label: {
                                        HStack(spacing: 14) {
                                            if viewModel.isLoadingTorrents {
                                                ProgressView()
                                                    .tint(.black)
                                                    .scaleEffect(1.0)
                                                Text("Поиск раздач...")
                                            } else if viewModel.selectedRelease != nil {
                                                Image(systemName: "play.fill")
                                                Text("Смотреть")
                                            } else {
                                                Image(systemName: "exclamationmark.triangle")
                                                Text("Раздачи не найдены")
                                            }
                                        }
                                    }
                                    .buttonStyle(EmeraldButtonStyle(isPrimary: true))
                                    .focused($focusedField, equals: .play)
                                    .disabled(viewModel.selectedRelease == nil && !viewModel.isLoadingTorrents)

                                    Button {
                                        Task { await viewModel.toggleWatchlist() }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: viewModel.inWatchlist ? "bookmark.fill" : "bookmark")
                                            Text(viewModel.inWatchlist ? "В списке" : "Буду смотреть")
                                        }
                                    }
                                    .buttonStyle(EmeraldButtonStyle(isPrimary: false))
                                    .focused($focusedField, equals: .watchlist)

                                    if !viewModel.qualityGroups.isEmpty {
                                        Button {
                                            showQualitySheet = true
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "slider.horizontal.3")
                                                Text(viewModel.selectedRelease?.effectiveTier ?? "Качество")
                                            }
                                        }
                                        .buttonStyle(EmeraldButtonStyle(isPrimary: false))
                                        .focused($focusedField, equals: .quality)
                                    }
                                }
                                .padding(.top, 16)
                            }
                            .padding(.horizontal, 80)
                            .padding(.bottom, 40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        }
                        .frame(width: 1920, height: 880, alignment: .topLeading)
                        .focusSection()

                        // AI Critics Consensus Section (Focusable)
                        Button {
                            if viewModel.hasCriticsFailed {
                                viewModel.retryCritics()
                            }
                        } label: {
                            AiCriticsCardView(
                                summary: viewModel.criticSummary,
                                isLoading: viewModel.isLoadingCritics,
                                hasFailed: viewModel.hasCriticsFailed,
                                onRetry: {
                                    viewModel.retryCritics()
                                }
                            )
                        }
                        .buttonStyle(TVCardButtonStyle(cornerRadius: 18, focusedScale: 1.02))
                        .focused($focusedField, equals: .critics)
                        .padding(.horizontal, 80)
                        .frame(maxWidth: .infinity)
                        .focusSection()

                        // TV Series Season & Episode Picker
                        if viewModel.isTv {
                            SeasonPickerView(
                                seasons: viewModel.seasons,
                                selectedSeason: viewModel.selectedSeasonNumber,
                                episodes: viewModel.episodes,
                                isLoadingEpisodes: viewModel.isLoadingEpisodes,
                                seriesProgress: viewModel.seriesProgress,
                                onSelectSeason: { sNum in
                                    viewModel.selectSeason(sNum)
                                },
                                onPlayEpisode: { ep in
                                    if viewModel.hasUnwatchedPrior(season: ep.seasonNumber, episode: ep.episodeNumber) {
                                        pendingCatchUpEpisode = ep
                                        showCatchUpAlert = true
                                    } else {
                                        startEpisodePlayback(ep)
                                    }
                                },
                                onToggleSeasonWatched: { sNum in
                                    Task {
                                        let isCompleted = viewModel.seasonSummary(seasonNumber: sNum)?.isCompleted == true
                                        await viewModel.markSeasonWatched(season: sNum, completed: !isCompleted)
                                    }
                                },
                                onToggleEpisodeWatched: { ep in
                                    Task {
                                        let isCompleted = ep.isPlayed == true
                                        await viewModel.markEpisodeWatched(season: ep.seasonNumber, episode: ep.episodeNumber, completed: !isCompleted)
                                    }
                                },
                                onMarkAllPriorWatched: { ep in
                                    Task {
                                        await viewModel.markAllUpTo(season: ep.seasonNumber, episode: ep.episodeNumber)
                                    }
                                }
                            )
                            .padding(.horizontal, 80)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focusSection()
                        }

                        // Cast & Crew Row (Focusable Buttons)
                        if let cast = meta.cast, !cast.isEmpty {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("В главных ролях")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.textPrimary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 32) {
                                        ForEach(cast.prefix(15)) { person in
                                            VStack(spacing: 12) {
                                                Button {
                                                    // Optional actor tap
                                                } label: {
                                                    LazyImage(url: person.effectiveAvatarURL) { state in
                                                        if let image = state.image {
                                                            image
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                        } else {
                                                            Rectangle()
                                                                .fill(Color.obsidianCard)
                                                        }
                                                    }
                                                }
                                                .buttonStyle(TVCircleButtonStyle(size: 160, focusedScale: 1.08))

                                                Text(person.name)
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(.textPrimary)
                                                    .lineLimit(1)

                                                if let char = person.character, !char.isEmpty {
                                                    Text(char)
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.textSecondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(width: 170)
                                        }
                                    }
                                    .padding(.vertical, 24)
                                }
                                .scrollClipDisabled()
                            }
                            .padding(.horizontal, 80)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .focusSection()
                        }
                    }
                    .padding(.bottom, 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .ignoresSafeArea(edges: [.horizontal, .top])
                .disabled(showQualitySheet)
            } else if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.emeraldPrimary)
                        .scaleEffect(2.0)
                    Text("Загрузка сведений...")
                        .font(.system(size: 26))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Quality Selection Modal Overlay
            if showQualitySheet {
                QualityAccordionView(
                    groups: viewModel.qualityGroups,
                    currentRelease: viewModel.selectedRelease,
                    onSelectRelease: { rel in
                        viewModel.selectedRelease = rel
                    },
                    onDismiss: {
                        showQualitySheet = false
                    }
                )
                .transition(.opacity)
            }
        }
        .defaultFocus($focusedField, .play)
        .onAppear {
            focusedField = .play
        }
        .onChange(of: showQualitySheet) { _, isShowing in
            if isShowing {
                focusedField = nil
            } else {
                focusedField = .quality
            }
        }
        .fullScreenCover(item: $activePlayback) { target in
            CinemaPlayerView(
                tconst: target.tconst,
                title: target.title,
                release: target.release,
                season: target.season,
                episode: target.episode,
                resumeSeconds: target.resumeSeconds,
                autoResume: target.autoResume,
                qualityGroups: target.qualityGroups,
                onDismiss: {
                    activePlayback = nil
                }
            )
            .id(target.id)
        }
        .onChange(of: activePlayback) { oldVal, newVal in
            if oldVal != nil && newVal == nil {
                NotificationCenter.default.post(name: .playbackProgressDidChange, object: nil)
                if viewModel.isTv {
                    Task { await viewModel.fetchSeriesProgress() }
                }
            }
        }
        .alert("Предыдущие серии не просмотрены", isPresented: $showCatchUpAlert) {
            Button("Пометить предыдущие и смотреть") {
                if let ep = pendingCatchUpEpisode {
                    Task {
                        await viewModel.markAllUpTo(season: ep.seasonNumber, episode: ep.episodeNumber)
                        startEpisodePlayback(ep)
                    }
                }
            }
            Button("Только смотреть") {
                if let ep = pendingCatchUpEpisode {
                    startEpisodePlayback(ep)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingCatchUpEpisode = nil
            }
        } message: {
            if let ep = pendingCatchUpEpisode {
                Text("Вы начинаете просмотр с \(ep.episodeNumber) серии (\(ep.seasonNumber) сезон). Пометить все предыдущие серии как просмотренные?")
            }
        }
        .onExitCommand {
            if showQualitySheet {
                showQualitySheet = false
            } else {
                onDismiss?()
            }
        }
        .task {
            await viewModel.loadDetails()
        }
    }

    private func startEpisodePlayback(_ ep: EpisodeInfo) {
        let rel: TorrentRelease? = {
            if let chosen = viewModel.selectedRelease {
                if viewModel.seasonMatchScore(chosen, targetSeason: ep.seasonNumber) >= 0 {
                    return chosen
                }
            }
            return viewModel.selectBestRelease(forSeason: ep.seasonNumber) ?? viewModel.selectedRelease
        }()
        if let r = rel {
            activePlayback = PlaybackTarget(
                tconst: viewModel.effectiveTconst,
                release: r,
                title: viewModel.metadata?.title ?? viewModel.initialTitle,
                season: ep.seasonNumber,
                episode: ep.episodeNumber,
                qualityGroups: viewModel.qualityGroups
            )
        }
    }
}
