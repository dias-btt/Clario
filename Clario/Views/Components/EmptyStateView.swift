import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var breathe = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ClarioPalette.indigo.opacity(0.35),
                                ClarioPalette.calmGreen.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 56
                        )
                    )
                    .frame(width: 112, height: 112)
                    .scaleEffect(breathe ? 1.06 : 0.94)
                    .opacity(0.9)

                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ClarioPalette.indigo, ClarioPalette.calmGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(ClarioPalette.cardSurface(colorScheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(ClarioPalette.cardStroke(colorScheme), lineWidth: 1)
                            )
                    )
                    .shadow(color: ClarioPalette.indigo.opacity(0.12), radius: 18, y: 10)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(ClarioPalette.primaryText(colorScheme))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(ClarioPalette.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 280)
            }
        }
        .padding(.vertical, 52)
        .frame(maxWidth: .infinity)
    }
}
