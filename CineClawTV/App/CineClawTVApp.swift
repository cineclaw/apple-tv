import SwiftUI

@main
struct CineClawTVApp: App {
    @State private var session = SessionManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.obsidianBackground.ignoresSafeArea()

                if session.isPaired {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: session.isPaired)
            .preferredColorScheme(.dark)
        }
    }
}
