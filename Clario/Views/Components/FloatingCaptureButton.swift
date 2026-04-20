import SwiftUI

struct FloatingCaptureButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var ripple = false

    var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(ClarioPalette.indigo.opacity(0.35), lineWidth: 2)
                    .scaleEffect(ripple ? 1.45 : 1)
                    .opacity(ripple ? 0 : 0.8)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ClarioPalette.warmAmber)
                            .offset(x: 2, y: 2)
                    }
            }
            .frame(width: 60, height: 60)
            .background {
                Circle().fill(buttonFill)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(
                color: ClarioShadow.floatingButton(colorScheme: colorScheme).color,
                radius: ClarioShadow.floatingButton(colorScheme: colorScheme).radius,
                x: 0,
                y: ClarioShadow.floatingButton(colorScheme: colorScheme).y
            )
            .scaleEffect(isPressed ? 0.92 : 1)
            .offset(y: isPressed ? 1 : -2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                        isPressed = false
                    }
                }
        )
    }

    private var buttonFill: LinearGradient {
        LinearGradient(
            colors: [
                ClarioPalette.indigo,
                Color(hex: "7C3AED"),
                ClarioPalette.indigoDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func triggerRipple() {
        ripple = false
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.55)) {
                ripple = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            ripple = false
        }
    }
}
