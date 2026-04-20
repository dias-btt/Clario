import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(ClarioPalette.primaryText(colorScheme))

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
