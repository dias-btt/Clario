import SwiftUI

struct DailyDigestCard: View {
    let summary: String

    @Bindable private var languageStore = AppLanguageStore.shared

    private let corner: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.95))
                    .accessibilityHidden(true)

                Text(languageStore.localized("digest.title"))
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                Spacer(minLength: 0)
            }

            Text(summary)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
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

    private func digestSection(titleKey: String, items: [String], moreHidden: Int, moreKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(languageStore.localized(titleKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if moreHidden > 0 {
                Text(languageStore.localizedFormat(moreKey, Int64(moreHidden)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private static func trimmed(_ text: String, limit: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > limit else { return t }
        let idx = t.index(t.startIndex, offsetBy: limit)
        return String(t[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }
}
