import SwiftUI

struct DailyDigestCard: View {
    let summary: String

    @Bindable private var languageStore = AppLanguageStore.shared

    private let corner: CGFloat = 22

    var body: some View {
        digestCardContent()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
    }

    @ViewBuilder
    private func digestCardContent() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            digestTitleRow()
            digestSummaryText()
        }
    }

    @ViewBuilder
    private func digestTitleRow() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.95))
                .accessibilityHidden(true)

            Text(languageStore.localized("digest.title"))
                .font(.system(.title3, design: .rounded, weight: .semibold))

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func digestSummaryText() -> some View {
        Text(summary)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.primary.opacity(0.88))
            .fixedSize(horizontal: false, vertical: true)
    }
}
