import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var selectedShelfForDetail: HomeShelf? = nil
    @State private var activePlayback: PlaybackTarget? = nil
    @State private var resumingItem: HomeItem? = nil
    @State private var resumeError: String? = nil

    let onSelectMedia: (HomeItem) -> Void

    var body: some View {
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()

            if let shelf = selectedShelfForDetail {
                ShelfDetailView(
                    shelf: shelf,
                    onSelectMedia: onSelectMedia,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedShelfForDetail = nil
                        }
                    }
                )
                .transition(.opacity)
            } else if viewModel.isLoading && viewModel.shelves.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.2)
                        .tint(.emeraldPrimary)
                    Text("Загрузка медиатеки...")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
            } else if let error = viewModel.errorMessage, viewModel.shelves.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundColor(.dangerRed)
                    Text(error)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Button("Повторить попытку") {
                        Task { await viewModel.loadHome(refresh: true) }
                    }
                    .buttonStyle(EmeraldButtonStyle(isPrimary: true))
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 48) {
                        // Hero Carousel Banner (True Edge-to-Edge)
                        if !viewModel.heroItems.isEmpty {
                            HeroCarouselView(
                                items: viewModel.heroItems,
                                onPlay: { item in
                                    onSelectMedia(item)
                                },
                                onDetails: { item in
                                    onSelectMedia(item)
                                }
                            )
                        }

                        // Continue Watching Shelf
                        if let cw = viewModel.continueWatching, !cw.items.isEmpty {
                            ContinueWatchingRow(
                                shelf: cw,
                                onSelect: { item in
                                    guard resumingItem == nil else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        resumingItem = item
                                        resumeError = nil
                                    }
                                    Task {
                                        do {
                                            let target = try await viewModel.preparePlayback(for: item)
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                resumingItem = nil
                                            }
                                            activePlayback = target
                                        } catch {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                resumingItem = nil
                                                resumeError = error.localizedDescription
                                            }
                                        }
                                    }
                                },
                                onDelete: { item in
                                    Task { await viewModel.deleteResume(tconst: item.effectiveTconst) }
                                }
                            )
                        }

                        // Curated & Hotlist Shelves
                        ForEach(viewModel.shelves) { shelf in
                            if !shelf.items.isEmpty {
                                ShelfRowView(
                                    shelf: shelf,
                                    onSelect: { item in
                                        onSelectMedia(item)
                                    },
                                    onLongPress: { item in
                                        Task { await viewModel.toggleWatchlist(item: item, currentlyIn: false) }
                                    },
                                    onShowMore: { s in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedShelfForDetail = s
                                        }
                                    }
                                )
                            }
                        }

                        Spacer(minLength: 120)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .ignoresSafeArea(edges: [.horizontal, .top])
            }

            // Resume loading overlay
            if let item = resumingItem {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()

                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(2.2)
                            .tint(.emeraldPrimary)

                        VStack(spacing: 8) {
                            Text("Запуск «\(item.title)»...")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.textPrimary)

                            if let s = item.season, let e = item.episode {
                                Text("Сезон \(s), серия \(e)\(item.episodeTitle.map { " — \($0)" } ?? "")")
                                    .font(.system(size: 20))
                                    .foregroundColor(.textSecondary)
                            }

                            if let tc = item.timecode, !tc.isEmpty {
                                Text("Возобновление с \(tc)")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(.emeraldPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                    .background(Color.obsidianElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.obsidianBorder, lineWidth: 1))
                }
                .transition(.opacity)
            }

            // Resume error notification
            if let err = resumeError {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.dangerRed)
                        Text(err)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.obsidianElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dangerRed.opacity(0.6), lineWidth: 1))
                    .padding(.top, 40)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation {
                        resumeError = nil
                    }
                }
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
                Task {
                    await viewModel.loadHome(refresh: true)
                }
            }
        }
        .task {
            await viewModel.loadHome()
        }
        .onAppear {
            Task {
                await viewModel.loadHome(refresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchlistDidChange)) { _ in
            Task {
                await viewModel.loadHome(refresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playbackProgressDidChange)) { _ in
            Task {
                await viewModel.loadHome(refresh: true)
            }
        }
    }
}
