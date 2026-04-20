import SwiftUI

// MARK: - HEX → Color

extension Color {
    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (alpha last).
    init(hex: String, opacity: Double = 1) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if string.hasPrefix("#") { string.removeFirst() }

        var value: UInt64 = 0
        guard Scanner(string: string).scanHexInt64(&value) else {
            self = .clear
            return
        }

        let r, g, b, a: Double
        switch string.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15
            g = Double((value >> 4) & 0xF) / 15
            b = Double(value & 0xF) / 15
            a = 1
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            self = .clear
            return
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a * opacity)
    }
}

// MARK: - Design tokens

enum ClarioPalette {
    static let slateDeep = Color(hex: "0F172A")
    static let slateSoft = Color(hex: "1E293B")
    static let mist = Color(hex: "F8FAFC")
    static let cloud = Color(hex: "EEF2FF")
    static let indigo = Color(hex: "6366F1")
    static let indigoDeep = Color(hex: "4F46E5")
    static let calmGreen = Color(hex: "22C55E")
    static let warmAmber = Color(hex: "F59E0B")
    static let roseGlow = Color(hex: "FB7185")

    static func canvasTop(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? slateDeep : Color(hex: "F1F5F9")
    }

    static func canvasBottom(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? slateSoft : mist
    }

    static func cardSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.72)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.95)
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "F1F5F9") : slateDeep
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }

    static func glassHighlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.45)
    }
}

enum ClarioRadius {
    static let card: CGFloat = 20
    static let digest: CGFloat = 22
    static let pill: CGFloat = 100
}

enum ClarioShadow {
    static func softCard(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        if colorScheme == .dark {
            return (Color.black.opacity(0.45), 28, 14)
        }
        return (Color(hex: "6366F1").opacity(0.12), 24, 12)
    }

    static func floatingButton(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (Color(hex: "4F46E5").opacity(colorScheme == .dark ? 0.55 : 0.35), 20, 10)
    }
}

extension View {
    func clarioCardShadow(colorScheme: ColorScheme) -> some View {
        let s = ClarioShadow.softCard(colorScheme: colorScheme)
        return shadow(color: s.color, radius: s.radius, x: 0, y: s.y)
    }

    func clarioScreenBackground(colorScheme: ColorScheme) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    ClarioPalette.canvasTop(colorScheme),
                    ClarioPalette.canvasBottom(colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ClarioPalette.indigo.opacity(colorScheme == .dark ? 0.18 : 0.14),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 280
                    )
                )
                .offset(x: 80, y: -120)
                .allowsHitTesting(false)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ClarioPalette.calmGreen.opacity(colorScheme == .dark ? 0.1 : 0.08),
                            Color.clear
                        ],
                        center: .bottomLeading,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .offset(x: -100, y: 200)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
