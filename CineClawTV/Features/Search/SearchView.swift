import SwiftUI
import NukeUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    let onSelectMedia: (HomeItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 300), spacing: 36)
    ]

    var body: some View {
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {
                    // Popular Suggestion Chips
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Популярные запросы")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 18) {
                                ForEach(viewModel.popularChips, id: \.self) { chip in
                                    Button {
                                        viewModel.setChipQuery(chip)
                                    } label: {
                                        Text(chip)
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundColor(.textPrimary)
                                            .padding(.horizontal, 26)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(Color.obsidianCard)
                                            )
                                    }
                                    .buttonStyle(TVCardButtonStyle(cornerRadius: 16, focusedScale: 1.06))
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focusSection()

                    // Results or Loading or Empty
                    if viewModel.isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.emeraldPrimary)
                                .scaleEffect(2.0)
                            Spacer()
                        }
                        .padding(.top, 80)
                    } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundColor(.textMuted)

                            Text("По запросу «\(viewModel.query)» ничего не найдено")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        LazyVGrid(columns: columns, spacing: 40) {
                            ForEach(viewModel.results) { item in
                                Button {
                                    let homeItem = HomeItem(
                                        id: item.tconst,
                                        tconst: item.tconst,
                                        mediaType: item.isTv ? "tv" : "movie",
                                        title: item.title,
                                        originalTitle: item.originalTitle,
                                        year: item.year,
                                        rating: item.rating,
                                        posterPath: item.posterPath
                                    )
                                    onSelectMedia(homeItem)
                                } label: {
                                    SearchResultCard(item: item)
                                }
                                .buttonStyle(TVMediaCardButtonStyle())
                            }
                        }
                        .padding(.horizontal, 80)
                        .frame(maxWidth: .infinity)
                        .focusSection()
                    }

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .searchable(text: $viewModel.query, prompt: "Поиск фильмов и сериалов...")
    }
}

struct SearchResultCard: View {
    @Environment(\.isFocused) private var isFocused
    let item: SearchResultItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                LazyImage(url: item.effectivePosterURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.obsidianElevated
                    }
                }
                .frame(width: 280, height: 420)
                .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.92)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                HStack(spacing: 8) {
                    if let rating = item.rating, rating > 0 {
                        Text("★ \(String(format: "%.1f", rating))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.ratingGold)
                    }
                    if let year = item.year, year > 0 {
                        Text("• \(String(year))")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(14)
            }
            .frame(width: 280, height: 420)
            .background(Color.obsidianCard)
            .tvCardFocusModifier(cornerRadius: 18, focusedScale: 1.07)

            Text(item.title)
                .font(.system(size: 24, weight: isFocused ? .bold : .semibold))
                .foregroundColor(isFocused ? .white : .textSecondary)
                .lineLimit(1)
                .frame(width: 280, alignment: .leading)
        }
        .frame(width: 280)
    }
}
