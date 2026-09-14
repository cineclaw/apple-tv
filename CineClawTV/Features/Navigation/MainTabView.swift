import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var selectedMedia: HomeItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView { item in
                selectedMedia = item
            }
            .tabItem {
                Label("Главная", systemImage: "house.fill")
            }
            .tag(0)

            SearchView { item in
                selectedMedia = item
            }
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            .tag(1)

            WatchlistView { item in
                selectedMedia = item
            }
            .tabItem {
                Label("Буду смотреть", systemImage: "bookmark.fill")
            }
            .tag(2)

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .fullScreenCover(item: $selectedMedia) { item in
            DetailsView(
                item: item,
                onDismiss: {
                    selectedMedia = nil
                }
            )
        }
        .onChange(of: selectedMedia) { oldVal, newVal in
            if oldVal != nil && newVal == nil {
                NotificationCenter.default.post(name: .watchlistDidChange, object: nil)
                NotificationCenter.default.post(name: .playbackProgressDidChange, object: nil)
            }
        }
    }
}
