import SwiftUI

/// Visual foundations shared by the app and Share Extension.
enum NotedDesign {
    enum Palette {
        static let brand = adaptive(light: 0x224431, dark: 0xA6CDB7)
        static let brandSoft = adaptive(light: 0xDFE5D8, dark: 0x293D33)
        static let accent = adaptive(light: 0xEDB55E, dark: 0xE9BD70)
        static let accentText = adaptive(light: 0x302719, dark: 0x302719)
        static let paper = adaptive(light: 0xFAF6ED, dark: 0x191E1A)
        static let chip = adaptive(light: 0xEDE7DB, dark: 0x303A31)
        static let toneCream = adaptive(light: 0xFBF4E6, dark: 0x292E27)
        static let toneHoney = adaptive(light: 0xF2BF65, dark: 0xE0AE59)
        static let toneSage = adaptive(light: 0xDFE5D8, dark: 0x303F33)
        static let folderTab = adaptive(light: 0xEAB65E, dark: 0xE0AE59)
        static let field = adaptive(light: 0xF8F4EB, dark: 0x242C25)
        static let bar = adaptive(light: 0xF8F3EB, dark: 0x242C25)
        static let surface = adaptive(light: 0xFFFDF7, dark: 0x242C25)
        static let primaryText = adaptive(light: 0x1E2A23, dark: 0xF3F0E7)
        static let secondaryText = adaptive(light: 0x6B6A62, dark: 0xB6BFAF)
        static let border = adaptive(light: 0xDEDFD3, dark: 0x455044)
        static let error = adaptive(light: 0xA33F36, dark: 0xF3A499)
        static let errorSoft = adaptive(light: 0xFBECE7, dark: 0x462E29)

        // Explicit pairs keep selected controls and the capture panel independent of surfaces.
        static let onBrand = adaptive(light: 0xFFFDF7, dark: 0x192B21)
        static let hero = adaptive(light: 0x284739, dark: 0x2B4437)
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

    enum PaperTone: CaseIterable {
        case cream, honey, sage

        var color: Color {
            switch self {
            case .cream: Palette.toneCream
            case .honey: Palette.toneHoney
            case .sage: Palette.toneSage
            }
        }

        // Honey remains light in both themes, so it needs its own dark foreground.
        var foreground: Color { self == .honey ? Palette.accentText : Palette.primaryText }
        var secondaryForeground: Color {
            switch self {
            case .honey: Palette.accentText
            case .sage: Palette.primaryText
            case .cream: Palette.secondaryText
            }
        }
    }

    /// FNV-1a over the canonical uppercase UUID, stable across launches and platforms.
    static func stableHash(_ id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }

    static func tone(for id: UUID, kind: String) -> PaperTone {
        if kind == "link" { return .sage }
        if kind == "image" { return .cream }
        return stableHash(id) % 3 == 0 ? .honey : .cream
    }

    static func curls(for id: UUID, kind: String) -> Bool {
        kind != "image" && stableHash(id) % 8 == 3
    }

    static func folderTone(at index: Int) -> PaperTone { index.isMultiple(of: 2) ? .cream : .sage }

    static func folderSketch(for name: String, id: UUID) -> Sketch {
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "đ", with: "d")
        let rules: [([String], Sketch)] = [
            (["cam hung", "y tuong"], .folderLeaf),
            (["doc", "sach", "bai viet"], .folderBook),
            (["rieng", "yeu", "thich"], .folderHeart),
            (["di", "du lich", "chuyen"], .folderMountain)
        ]
        for (keywords, sketch) in rules where keywords.contains(where: { normalized.contains($0) }) { return sketch }
        let choices: [Sketch] = [.folderLeaf, .folderBook, .folderHeart, .folderMountain]
        return choices[Int(stableHash(id) % 4)]
    }

    enum Sketch: String, CaseIterable {
        case lightbulb = "SketchLightbulb"
        case folderLeaf = "SketchFolderLeaf"
        case folderBook = "SketchFolderBook"
        case folderHeart = "SketchFolderHeart"
        case folderMountain = "SketchFolderMountain"
        case folderPlain = "SketchFolderPlain"
        case note = "SketchNote"
        case photo = "SketchPhoto"
        case link = "SketchLink"

        var image: Image { Image(rawValue).renderingMode(.template) }
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
        static let input: CGFloat = 10
        static let folderTab: CGFloat = 6
        static let card: CGFloat = 12
    }
}

/// Static tiled grain: no per-frame noise generation or offscreen drawing group.
struct PaperBackground: ViewModifier {
    var color: Color = NotedDesign.Palette.paper
    var isHero = false

    func body(content: Content) -> some View {
        content.background {
            color.overlay {
                Image("PaperGrain")
                    .resizable(resizingMode: .tile)
                    // Soft light around neutral grey keeps the token colour (ΔE probes) and
                    // adds speckle only; strength matched to v3: hero ≫ cards > page.
                    .blendMode(.softLight)
                    .opacity(isHero ? 1 : 0.35)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    func paperBackground(_ color: Color = NotedDesign.Palette.paper, isHero: Bool = false) -> some View {
        modifier(PaperBackground(color: color, isHero: isHero))
    }
}
