import SwiftUI

struct CinemaPlayerView: View {
    @State private var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var onDismiss: (() -> Void)? = nil

    init(
        tconst: String,
        title: String? = nil,
        release: TorrentRelease,
        season: Int? = nil,
        episode: Int? = nil,
        resumeSeconds: Double = 0.0,
        autoResume: Bool = false,
        qualityGroups: [QualityGroup] = [],
        onDismiss: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: PlayerViewModel(
            tconst: tconst,
            title: title,
            release: release,
            season: season,
            episode: episode,
            resumeSeconds: resumeSeconds,
            autoResume: autoResume,
            qualityGroups: qualityGroups
        ))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isMounting {
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(2.2)
                        .tint(.white)

                    Text(viewModel.mountStatusText)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black, radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
            } else if let err = viewModel.errorMessage {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.red)

                    Text(err)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)

                    HStack(spacing: 20) {
                        Button("Повторить") {
                            Task { await viewModel.start() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Закрыть") {
                            closePlayer()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
            } else {
                // Native UIKit tvOS Player Controller with UIMenu system popover menus
                NativeVLCPlayerView(viewModel: viewModel, onDismiss: {
                    closePlayer()
                })
                .ignoresSafeArea()
            }
        }
        .task {
            await viewModel.start()
        }
    }

    private func closePlayer() {
        viewModel.stop()
        dismiss()
        onDismiss?()
    }
}
