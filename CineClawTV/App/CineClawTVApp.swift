import SwiftUI

@main
struct CineClawTVApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .background(Color.obsidianBackground)
        }
    }
}
