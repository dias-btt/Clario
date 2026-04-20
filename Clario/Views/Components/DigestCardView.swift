import SwiftUI

struct DigestCardView: View {
    let greeting: String
    let summary: String
    let spotlightTasks: [TaskItem]

    @Bindable private var languageStore = AppLanguageStore.shared
    @Environment(\.colorScheme) private var colorScheme

    private let corner: CGFloat = ClarioRadius.digest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            digestHeader()
            Text(summary)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(ClarioPalette.primaryText(colorScheme).opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            if !spotlightTasks.isEmpty {
                spotlightSection()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(digestBackground)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.9),
                            ClarioPalette.indigo.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clarioCardShadow(colorScheme: colorScheme)
    }

    @ViewBuilder
    private func digestHeader() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ClarioPalette.warmAmber, ClarioPalette.indigo],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .accessibilityHidden(true)

                Text(languageStore.localized("digest.title"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
                    .textCase(.uppercase)
                    .tracking(1.1)

                Spacer(minLength: 0)
            }

            Text(greeting)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(ClarioPalette.primaryText(colorScheme))
        }
    }

    @ViewBuilder
    private func spotlightSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(languageStore.localized("digest.spotlight.title"))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme))

            VStack(spacing: 8) {
                ForEach(spotlightTasks.prefix(2)) { task in
                    spotlightRow(task)
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func spotlightRow(_ task: TaskItem) -> some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(task.priorityTag.accentColor)
                .frame(width: 4, height: 22)

            Text(task.title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(ClarioPalette.primaryText(colorScheme).opacity(0.92))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ClarioPalette.glassHighlight(colorScheme))
        )
    }

    private var digestBackground: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ClarioPalette.indigo.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                ClarioPalette.calmGreen.opacity(colorScheme == .dark ? 0.08 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

private extension TaskPriorityTag {
    var accentColor: Color {
        switch self {
        case .urgent: ClarioPalette.roseGlow
        case .important: ClarioPalette.warmAmber
        case .lowPriority: ClarioPalette.calmGreen.opacity(0.85)
        }
    }
}
