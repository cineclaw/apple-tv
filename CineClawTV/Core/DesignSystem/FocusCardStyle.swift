import SwiftUI

struct TVCardModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    var cornerRadius: CGFloat = 18
    var focusedScale: CGFloat = 1.07

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isFocused ? Color.white : Color.obsidianBorder.opacity(0.8),
                        lineWidth: isFocused ? 3.5 : 1.0
                    )
            )
            .shadow(
                color: isFocused ? Color.emeraldPrimary.opacity(0.45) : Color.clear,
                radius: isFocused ? 20 : 0,
                x: 0,
                y: isFocused ? 4 : 0
            )
            .shadow(
                color: isFocused ? Color.black.opacity(0.8) : Color.black.opacity(0.35),
                radius: isFocused ? 14 : 6,
                x: 0,
                y: isFocused ? 8 : 3
            )
            .scaleEffect(isFocused ? focusedScale : 1.0)
            .zIndex(isFocused ? 10 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isFocused)
    }
}

/// Button style for compound media cards (where artwork surface handles its own focus zoom/frame,
/// while metadata text sits below outside the border).
struct TVMediaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct TVCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    var cornerRadius: CGFloat = 16
    var focusedScale: CGFloat = 1.05

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isFocused ? Color.white : Color.obsidianBorder, lineWidth: isFocused ? 3.0 : 1.0)
            )
            .shadow(color: isFocused ? Color.emeraldPrimary.opacity(0.4) : Color.clear, radius: isFocused ? 18 : 0, y: isFocused ? 4 : 0)
            .scaleEffect(isFocused ? focusedScale : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isFocused)
    }
}

struct TVCircleButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    var size: CGFloat = 160
    var focusedScale: CGFloat = 1.08

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isFocused ? Color.white : Color.obsidianBorder, lineWidth: isFocused ? 3.5 : 1.5)
            )
            .shadow(color: isFocused ? Color.emeraldPrimary.opacity(0.4) : Color.clear, radius: isFocused ? 18 : 0, y: isFocused ? 4 : 0)
            .scaleEffect(isFocused ? focusedScale : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isFocused)
    }
}

extension View {
    func tvCardFocusModifier(cornerRadius: CGFloat = 18, focusedScale: CGFloat = 1.07) -> some View {
        modifier(TVCardModifier(cornerRadius: cornerRadius, focusedScale: focusedScale))
    }

    func tvCardStyle(cornerRadius: CGFloat = 16, focusedScale: CGFloat = 1.06) -> some View {
        modifier(TVCardModifier(cornerRadius: cornerRadius, focusedScale: focusedScale))
    }
}

struct EmeraldButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    var isPrimary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(isPrimary ? (isFocused ? .black : .white) : .white)
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? (isFocused ? Color.white : Color.emeraldPrimary) : (isFocused ? Color.obsidianElevated : Color.obsidianCard))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? Color.emeraldPrimary : Color.obsidianBorder, lineWidth: isFocused ? 3.5 : 1.5)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: isFocused ? Color.emeraldGlow : Color.clear, radius: 16)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isFocused)
    }
}

struct TagBadge: View {
    let text: String
    var color: Color = .obsidianElevated
    var textColor: Color = .textPrimary

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
            )
    }
}

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.obsidianCard,
                Color.obsidianElevated,
                Color.obsidianCard
            ]),
            startPoint: .init(x: phase - 1, y: 0.5),
            endPoint: .init(x: phase, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2.0
            }
        }
    }
}
