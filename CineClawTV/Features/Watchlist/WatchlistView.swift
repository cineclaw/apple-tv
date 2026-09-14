import SwiftUI

@Observable
@MainActor
final class WatchlistViewModel {
    var items: [HomeItem] = []
    var isLoading: Bool = false

    func loadWatchlist() async {
        isLoading = true
        do {
            self.items = try await CineClawClient.shared.getWatchlist()
        } catch {
            // Empty on error
        }
        isLoading = false
    }

    func removeItem(_ item: HomeItem) async {
        do {
            try await CineClawClient.shared.removeFromWatchlist(tconst: item.effectiveTconst)
            await loadWatchlist()
        } catch {}
    }
}

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    let onSelectMedia: (HomeItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 300), spacing: 36)
    ]

    var body: some View {
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()

            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
                    .tint(.emeraldPrimary)
                    .scaleEffect(2.0)
            } else if viewModel.items.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 72))
                        .foregroundColor(.textMuted)

                    Text("Список пуст")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Text("Добавляйте фильмы и сериалы в «Буду смотреть» из карточек подробностей.")
                        .font(.system(size: 22))
                        .foregroundColor(.textSecondary)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Буду смотреть (\(viewModel.items.count))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 80)
                            .padding(.top, 32)

                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(viewModel.items) { item in
                                Button {
                                    onSelectMedia(item)
                                } label: {
                                    MediaCardView(item: item)
                                }
                                .buttonStyle(TVMediaCardButtonStyle())
                            }
                        }
                        .padding(.horizontal, 80)
                        .frame(maxWidth: .infinity)
                        .focusSection()

                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task {
            await viewModel.loadWatchlist()
        }
        .onAppear {
            Task {
                await viewModel.loadWatchlist()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchlistDidChange)) { _ in
            Task {
                await viewModel.loadWatchlist()
            }
        }
    }
}
