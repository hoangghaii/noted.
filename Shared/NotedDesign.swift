import SwiftUI

/// Visual foundations shared by the app and Share Extension.
enum NotedDesign {
    enum Palette {
        static let brand = adaptive(light: 0x285448, dark: 0xA6CDB7)
        static let brandSoft = adaptive(light: 0xE5EDE5, dark: 0x293D33)
        static let accent = adaptive(light: 0xE6B45B, dark: 0xE9BD70)
        static let accentText = adaptive(light: 0x302719, dark: 0x302719)
        static let paper = adaptive(light: 0xF6F2E9, dark: 0x191E1A)
        static let surface = adaptive(light: 0xFFFDF7, dark: 0x242C25)
        static let primaryText = adaptive(light: 0x27352C, dark: 0xF3F0E7)
        static let secondaryText = adaptive(light: 0x646D61, dark: 0xB6BFAF)
        static let border = adaptive(light: 0xDEDFD3, dark: 0x455044)
        static let error = adaptive(light: 0xA33F36, dark: 0xF3A499)
        static let errorSoft = adaptive(light: 0xFBECE7, dark: 0x462E29)

        // Explicit pairs keep selected controls and the capture panel independent of surfaces.
        static let onBrand = adaptive(light: 0xFFFDF7, dark: 0x192B21)
        static let hero = adaptive(light: 0x253F34, dark: 0x2B4437)
        static let heroText = adaptive(light: 0xFFFDF7, dark: 0xFFFDF7)
        static let heroMuted = adaptive(light: 0xC8D8BF, dark: 0xC8D8BF)

        private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1
                )
            })
        }
    }

    enum TypeStyle {
        static let display = Font.system(.largeTitle, design: .default, weight: .bold)
        static let title = Font.system(.title2, design: .default, weight: .semibold)
        static let heading = Font.system(.headline, design: .default, weight: .semibold)
        static let body = Font.system(.body)
        static let caption = Font.system(.caption)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        // Small media and decorative badges; actions use Capsule(), icon actions Circle().
        static let thumbnail: CGFloat = 8
        static let input: CGFloat = 14
        static let card: CGFloat = 20
    }
}
