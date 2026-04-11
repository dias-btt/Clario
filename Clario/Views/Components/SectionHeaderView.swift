import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        headerRow()
    }

    @ViewBuilder
    private func headerRow() -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))

            Spacer()

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
