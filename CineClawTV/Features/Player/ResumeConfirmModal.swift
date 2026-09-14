import SwiftUI

// MARK: - Infuse-Style Native tvOS Resume Modal
struct ResumeConfirmModal: View {
    let resumeSeconds: Double
    let onResume: () -> Void
    let onStartOver: () -> Void

    @FocusState private var focusedButton: ModalButton?

    enum ModalButton: Hashable {
        case resume
        case startOver
    }

    private var formattedTime: String {
        let total = Int(resumeSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Возобновить воспроизведение\nили начать проигрывание заново?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.top, 4)

                VStack(spacing: 14) {
                    Button {
                        onResume()
                    } label: {
                        Text("Возобновить (\(formattedTime))")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                    }
                    .buttonStyle(TvSystemModalButtonStyle())
                    .focused($focusedButton, equals: .resume)

                    Button {
                        onStartOver()
                    } label: {
                        Text("Начать заново")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                    }
                    .buttonStyle(TvSystemModalButtonStyle())
                    .focused($focusedButton, equals: .startOver)
                }
                .frame(width: 440)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.obsidianCard.opacity(0.96))
                    .shadow(color: .black.opacity(0.85), radius: 30)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .defaultFocus($focusedButton, .resume)
    }
}

// MARK: - Native tvOS Modal Button Style (White when focused, dark translucent when unfocused)
struct TvSystemModalButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isFocused ? .black : .white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isFocused ? Color.white : Color.white.opacity(0.12))
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .shadow(color: isFocused ? Color.black.opacity(0.4) : .clear, radius: 10, y: 4)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
