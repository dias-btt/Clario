import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        emptyStateStack()
    }

    @ViewBuilder
    private func emptyStateStack() -> some View {
        VStack(spacing: 14) {
            emptyStateIcon()
            emptyStateCopy()
        }
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func emptyStateIcon() -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Color(red: 0.42, green: 0.49, blue: 0.98))
            .frame(width: 68, height: 68)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 10)
    }

    @ViewBuilder
    private func emptyStateCopy() -> some View {
        Text(title)
            .font(.title3.weight(.semibold))

        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 260)
    }
}
