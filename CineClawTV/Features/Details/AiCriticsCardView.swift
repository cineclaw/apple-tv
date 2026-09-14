import SwiftUI

struct AiCriticsCardView: View {
    let summary: CriticSummaryResponse?
    let isLoading: Bool
    var hasFailed: Bool = false
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.emeraldPrimary)

                Text("Консенсус критиков")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.textPrimary)

                Spacer()

                if let s = summary {
                    TagBadge(text: toneTitle(for: s.tone), color: toneColor(for: s.tone).opacity(0.2), textColor: toneColor(for: s.tone))
                }
            }

            if isLoading {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ProgressView()
                            .tint(.emeraldPrimary)
                        Text("Анализируем рецензии критиков (Gemini 2.5 Flash)...")
                            .font(.system(size: 22))
                            .foregroundColor(.textSecondary)
                    }
                    ShimmerView()
                        .frame(height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if hasFailed && summary == nil {
                HStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 26))
                        .foregroundColor(.ratingGold)

                    Text("Не удалось собрать консенсус критиков")
                        .font(.system(size: 22))
                        .foregroundColor(.textSecondary)

                    Spacer()

                    if let retry = onRetry {
                        Button {
                            retry()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Повторить анализ")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.obsidianElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(TVCardButtonStyle(cornerRadius: 12, focusedScale: 1.05))
                    }
                }
                .padding(.vertical, 10)
            } else if let s = summary {
                // Scores row
                HStack(spacing: 28) {
                    if let rt = s.scores.rottenTomatoes {
                        HStack(spacing: 8) {
                            Text("🍅")
                                .font(.system(size: 24))
                            Text("\(rt)%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.textPrimary)
                        }
                    }

                    if let meta = s.scores.metacritic {
                        HStack(spacing: 8) {
                            Text("Metascore:")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.textSecondary)
                            Text("\(meta)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(meta >= 60 ? .emeraldPrimary : .ratingGold)
                        }
                    }

                    if let imdb = s.scores.imdb {
                        HStack(spacing: 8) {
                            Text("★")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.ratingGold)
                            Text(String(format: "%.1f", imdb))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            if let votes = s.scores.imdbVotes {
                                Text("(\(votes))")
                                    .font(.system(size: 18))
                                    .foregroundColor(.textMuted)
                            }
                        }
                    }
                }

                // Verdict Text
                Text(s.verdict)
                    .font(.system(size: 24))
                    .foregroundColor(.textPrimary)
                    .lineSpacing(6)

                // Pros & Cons
                if !s.pros.isEmpty || !s.cons.isEmpty {
                    HStack(alignment: .top, spacing: 36) {
                        if !s.pros.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Плюсы")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.emeraldPrimary)
                                ForEach(s.pros.prefix(3), id: \.self) { pro in
                                    Text("• \(pro)")
                                        .font(.system(size: 20))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }

                        if !s.cons.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Минусы")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.dangerRed)
                                ForEach(s.cons.prefix(3), id: \.self) { con in
                                    Text("• \(con)")
                                        .font(.system(size: 20))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                    }
                }

                if !s.targetAudience.isEmpty {
                    Text("Кому понравится: \(s.targetAudience)")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textMuted)
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.obsidianCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.obsidianBorder, lineWidth: 1.5)
        )
    }

    private func toneTitle(for tone: String) -> String {
        switch tone.lowercased() {
        case "positive", "acclaimed": return "Восторженный приём"
        case "mixed": return "Смешанные отзывы"
        case "negative": return "Сдержанный / Спорный"
        default: return "Положительный приём"
        }
    }

    private func toneColor(for tone: String) -> Color {
        switch tone.lowercased() {
        case "positive", "acclaimed": return .emeraldPrimary
        case "mixed": return .ratingGold
        case "negative": return .dangerRed
        default: return .emeraldPrimary
        }
    }
}
