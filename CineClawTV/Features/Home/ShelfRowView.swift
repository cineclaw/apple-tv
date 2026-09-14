import SwiftUI
import NukeUI

struct ShelfRowView: View {
    let shelf: HomeShelf
    let onSelect: (HomeItem) -> Void
    var onLongPress: ((HomeItem) -> Void)? = nil
    var onShowMore: ((HomeShelf) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Text(shelf.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.textPrimary)

                if let badge = shelf.badge, !badge.isEmpty {
                    TagBadge(text: badge, color: Color.emeraldPrimary.opacity(0.2), textColor: .emeraldPrimary)
                }

                Spacer()

                if onShowMore != nil && !shelf.items.isEmpty {
                    Button {
                        onShowMore?(shelf)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Ещё")
                                .font(.system(size: 22, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.emeraldPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.obsidianElevated)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(TVCardButtonStyle(cornerRadius: 22, focusedScale: 1.08))
                }
            }
            .padding(.horizontal, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 36) {
                    ForEach(shelf.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            MediaCardView(item: item)
                        }
                        .buttonStyle(TVMediaCardButtonStyle())
                    }

                    if onShowMore != nil && !shelf.items.isEmpty {
                        Button {
                            onShowMore?(shelf)
                        } label: {
                            ShowMoreCardView(shelf: shelf)
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

struct ShowMoreCardView: View {
    @Environment(\.isFocused) private var isFocused
    let shelf: HomeShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Color.obsidianElevated

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.emeraldPrimary.opacity(0.15))
                            .frame(width: 84, height: 84)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.emeraldPrimary)
                    }

                    VStack(spacing: 8) {
                        Text("Показать все")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Text("Вся полка")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding()
            }
            .frame(width: 280, height: 420)
            .tvCardFocusModifier(cornerRadius: 18, focusedScale: 1.07)

            Text("Ещё →")
                .font(.system(size: 24, weight: isFocused ? .heavy : .bold))
                .foregroundColor(isFocused ? .white : .emeraldPrimary)
                .frame(width: 280, alignment: .leading)
        }
        .frame(width: 280)
    }
}

struct ShelfDetailView: View {
    let shelf: HomeShelf
    let onSelectMedia: (HomeItem) -> Void
    let onBack: () -> Void

    @State private var items: [HomeItem]
    @State private var currentPage: Int = 1
    @State private var isLoadingMore: Bool = false
    @State private var hasMore: Bool = true

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 300), spacing: 36)
    ]

    init(shelf: HomeShelf, onSelectMedia: @escaping (HomeItem) -> Void, onBack: @escaping () -> Void) {
        self.shelf = shelf
        self.onSelectMedia = onSelectMedia
        self.onBack = onBack
        _items = State(initialValue: shelf.items)
    }

    var body: some View {
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {
                    // Header Bar
                    HStack(spacing: 24) {
                        Button {
                            onBack()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Назад")
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 14)
                            .background(Color.obsidianElevated)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(TVCardButtonStyle(cornerRadius: 26, focusedScale: 1.08))

                        Text(shelf.title)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.textPrimary)

                        if let badge = shelf.badge, !badge.isEmpty {
                            TagBadge(text: badge, color: Color.emeraldPrimary.opacity(0.2), textColor: .emeraldPrimary)
                        }

                        Spacer()

                        Text("\(items.count) релизов")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focusSection()

                    // Media Grid
                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(items) { item in
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

                    // Load More Footer
                    if hasMore {
                        Button {
                            Task { await loadNextPage() }
                        } label: {
                            HStack(spacing: 14) {
                                if isLoadingMore {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 26))
                                }
                                Text(isLoadingMore ? "Загрузка..." : "Загрузить ещё (+30)")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 76)
                            .background(Color.emeraldPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(TVCardButtonStyle(cornerRadius: 18, focusedScale: 1.04))
                        .disabled(isLoadingMore)
                        .padding(.horizontal, 80)
                        .padding(.top, 28)
                        .frame(maxWidth: .infinity)
                        .focusSection()
                    }

                    Spacer(minLength: 80)
                }
            }
        }
        .onExitCommand(perform: onBack)
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        do {
            let nextShelf = try await CineClawClient.shared.getShelfFeed(id: shelf.id, page: nextPage)
            if nextShelf.items.isEmpty {
                hasMore = false
            } else {
                let existingIds = Set(items.map { $0.id })
                let newItems = nextShelf.items.filter { !existingIds.contains($0.id) }
                if newItems.isEmpty {
                    hasMore = false
                } else {
                    items.append(contentsOf: newItems)
                    currentPage = nextPage
                }
            }
        } catch {
            hasMore = false
        }
        isLoadingMore = false
    }
}

struct MediaCardView: View {
    @Environment(\.isFocused) private var isFocused
    let item: HomeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                LazyImage(url: item.effectivePosterURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if state.error != nil {
                        Color.obsidianElevated
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 56))
                                    .foregroundColor(.textMuted)
                            )
                    } else {
                        ShimmerView()
                    }
                }
                .frame(width: 280, height: 420)
                .clipped()

                // Bottom scrim gradient: rating & year & seeds
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.92)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 110)

                HStack(spacing: 8) {
                    if let rating = item.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Text("★")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.ratingGold)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .lineLimit(1)
                        .fixedSize()
                    }

                    if let year = item.year, year > 0 {
                        Text(String(year))
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    Spacer(minLength: 4)

                    if let seeds = item.seeds, seeds > 0 {
                        Text("🌱 \(seeds)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.emeraldPrimary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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
