import SwiftUI

enum QualityFocusTarget: Hashable {
    case close
    case tier(String)
    case release(String)
}

struct QualityAccordionView: View {
    let groups: [QualityGroup]
    let currentRelease: TorrentRelease?
    let onSelectRelease: (TorrentRelease) -> Void
    let onDismiss: () -> Void

    @State private var expandedGroupIds: Set<String>
    @FocusState private var focusedItem: QualityFocusTarget?

    init(
        groups: [QualityGroup],
        currentRelease: TorrentRelease?,
        onSelectRelease: @escaping (TorrentRelease) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.groups = groups
        self.currentRelease = currentRelease
        self.onSelectRelease = onSelectRelease
        self.onDismiss = onDismiss

        let initialTier = groups.first(where: { g in
            guard let cur = currentRelease else { return false }
            return cur.effectiveTier.lowercased().contains(g.id.lowercased())
        })?.id ?? groups.first?.id ?? ""

        var initialSet = Set<String>()
        if !initialTier.isEmpty {
            initialSet.insert(initialTier)
        }
        _expandedGroupIds = State(initialValue: initialSet)
    }

    private var initialTarget: QualityFocusTarget {
        let initialTier = groups.first(where: { g in
            guard let cur = currentRelease else { return false }
            return cur.effectiveTier.lowercased().contains(g.id.lowercased())
        })?.id ?? groups.first?.id ?? ""
        return .tier(initialTier)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Выбор качества и релиза")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(TVCardButtonStyle(cornerRadius: 18, focusedScale: 1.15))
                    .focused($focusedItem, equals: .close)
                }
                .padding(.horizontal, 48)
                .padding(.top, 36)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        ForEach(groups) { group in
                            QualityTierAccordionSection(
                                group: group,
                                isExpanded: expandedGroupIds.contains(group.id),
                                currentRelease: currentRelease,
                                focusedItem: $focusedItem,
                                onToggle: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if expandedGroupIds.contains(group.id) {
                                            expandedGroupIds.remove(group.id)
                                        } else {
                                            expandedGroupIds.insert(group.id)
                                        }
                                    }
                                },
                                onSelect: { rel in
                                    onSelectRelease(rel)
                                    onDismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: 1280, maxHeight: 860)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.obsidianElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.obsidianBorder, lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.8), radius: 30)
        }
        .defaultFocus($focusedItem, initialTarget)
        .onAppear {
            let activeId: String = {
                if let cur = currentRelease,
                   let match = groups.first(where: { cur.effectiveTier.lowercased().contains($0.id.lowercased()) }) {
                    return match.id
                }
                return groups.first?.id ?? ""
            }()
            if !activeId.isEmpty {
                expandedGroupIds.insert(activeId)
                focusedItem = .tier(activeId)
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }
}

struct QualityTierAccordionSection: View {
    let group: QualityGroup
    let isExpanded: Bool
    let currentRelease: TorrentRelease?
    var focusedItem: FocusState<QualityFocusTarget?>.Binding
    let onToggle: () -> Void
    let onSelect: (TorrentRelease) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                onToggle()
            } label: {
                HStack(spacing: 16) {
                    Text(group.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.textPrimary)

                    TagBadge(text: "\(group.releases.count) релизов", color: Color.emeraldPrimary.opacity(0.2), textColor: .emeraldPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(Color.obsidianCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(TVCardButtonStyle(cornerRadius: 16, focusedScale: 1.02))
            .focused(focusedItem, equals: .tier(group.id))

            // Releases inside tier
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(group.releases) { rel in
                        Button {
                            onSelect(rel)
                        } label: {
                            HStack(spacing: 18) {
                                if currentRelease?.effectiveHash == rel.effectiveHash {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.emeraldPrimary)
                                        .font(.system(size: 24))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(rel.title)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)

                                    HStack(spacing: 12) {
                                        Text(rel.codecBadge)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(rel.isHEVC ? .purple : .cyan)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(rel.isHEVC ? Color.purple.opacity(0.2) : Color.cyan.opacity(0.2))
                                            )

                                        Text(rel.sizeFormatted)
                                            .font(.system(size: 18))
                                            .foregroundColor(.textSecondary)

                                        if !rel.bitrateFormatted.isEmpty {
                                            Text(rel.bitrateFormatted)
                                                .font(.system(size: 18))
                                                .foregroundColor(.textSecondary)
                                        }

                                        if let audio = rel.audioLabel, !audio.isEmpty {
                                            Text(audio)
                                                .font(.system(size: 18))
                                                .foregroundColor(.textMuted)
                                        }
                                    }
                                }

                                Spacer()

                                Text("🌱 \(rel.seeds)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.emeraldPrimary)
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.obsidianCard.opacity(0.65))
                            )
                        }
                        .buttonStyle(TVCardButtonStyle(cornerRadius: 14, focusedScale: 1.02))
                        .focused(focusedItem, equals: .release(rel.effectiveHash))
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 14)
            }
        }
    }
}
