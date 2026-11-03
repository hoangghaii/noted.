import SwiftUI

// Shared by the app and Share Extension; no dependency on the app's data model.
enum NotedButtonRole: Equatable {
    case primary, secondary, soft, quiet, destructive
}

/// A point size measured from the v3 mock that still follows Dynamic Type: at the default
/// size (L) it is exactly `size`; other sizes scale like `relativeTo`.
private struct ScaledFont: ViewModifier {
    // Scale a factor rather than the size: ScaledMetric rounds to the pixel grid, which would turn
    // 15.5 into 15.67 even at the default size and shift the measured layout.
    @ScaledMetric private var percent: CGFloat
    private let size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _percent = ScaledMetric(wrappedValue: 100, relativeTo: style)
        self.size = size
        self.weight = weight
    }

    func body(content: Content) -> some View { content.font(.system(size: size * percent / 100, weight: weight)) }
}

extension View {
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: style))
    }
}

struct NotedButtonStyle: ButtonStyle {
    let role: NotedButtonRole
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // v3 save button label: 18 pt semibold (measured); other buttons keep subheadline.
            .scaledFont(prominent && role == .primary ? 18 : 15, weight: role == .soft ? .regular : .semibold,
                        relativeTo: prominent && role == .primary ? .body : .subheadline)
            .frame(minHeight: prominent && role == .primary ? 50 : 44)
            .padding(.horizontal, 16)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    private var foreground: Color {
        switch role {
        case .primary: NotedDesign.Palette.accentText
        case .destructive: NotedDesign.Palette.error
        default: NotedDesign.Palette.brand
        }
    }

    private var background: Color {
        switch role {
        case .primary: NotedDesign.Palette.accent
        case .secondary: NotedDesign.Palette.brandSoft
        case .soft: NotedDesign.Palette.toneSage
        case .quiet: .clear
        case .destructive: NotedDesign.Palette.errorSoft
        }
    }
}

/// Every child receives the same width. Long groups scroll while the first
/// visibleCount children exactly fill the viewport, including their gaps.
struct EqualWidthPillGroup<Content: View>: View {
    let count: Int
    var visibleCount: Int? = nil
    var spacing: CGFloat = 8
    var visualHeight: CGFloat = 36
    var accessibilityID = ""
    @ViewBuilder let content: (Int) -> Content
    @ScaledMetric(relativeTo: .subheadline) private var touchHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let visible = max(1, min(visibleCount ?? count, count))
            let width = max(0, (geometry.size.width - CGFloat(visible - 1) * spacing) / CGFloat(visible))
            if count > visible {
                ScrollView(.horizontal, showsIndicators: false) {
                    row(width: width)
                }.accessibilityElement(children: .contain).accessibilityIdentifier(accessibilityID)
            } else {
                row(width: width).accessibilityElement(children: .contain).accessibilityIdentifier(accessibilityID)
            }
        }
        .frame(height: max(touchHeight, visualHeight))
    }

    private func row(width: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(0, count), id: \.self) { index in
                content(index).frame(width: width)
            }
        }
    }
}

struct NotedPill: View {
    let title: String
    let selected: Bool
    var symbol: String? = nil
    var symbolSize: CGFloat? = nil
    var visualHeight: CGFloat = 36
    let action: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var touchHeight: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol {
                    if let symbolSize { Image(systemName: symbol).scaledFont(symbolSize, relativeTo: .subheadline) } else { Image(systemName: symbol) }
                }
                Text(title).lineLimit(1).minimumScaleFactor(0.85)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: max(visualHeight, touchHeight - 8))
            .foregroundStyle(selected ? NotedDesign.Palette.onBrand : NotedDesign.Palette.primaryText)
            .background(selected ? NotedDesign.Palette.brand : NotedDesign.Palette.chip, in: Capsule())
            .frame(minHeight: touchHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CircleIconButton: View {
    let symbol: String
    let label: String
    /// Visual circle size; the hit target always stays 44 pt.
    var diameter: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .scaledFont(17, weight: .semibold, relativeTo: .body)
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .frame(width: diameter, height: diameter)
                .background(NotedDesign.Palette.chip, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension ToolbarContent {
    /// iOS 26 wraps every toolbar item in a shared Liquid Glass capsule. Items that already draw
    /// their own paper chip (NotedButtonStyle, CircleIconButton…) would otherwise show two outlines.
    @ToolbarContentBuilder
    func notedOwnBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

struct PaperCard<Content: View>: View {
    var tone: NotedDesign.PaperTone = .cream
    var curl = false
    @ViewBuilder var content: () -> Content

    private let foldSize: CGFloat = 30

    var body: some View {
        content()
            .foregroundStyle(tone.foreground)
            .paperBackground(tone.color)
            // The folded corner is cut out of the sheet so the page behind shows through.
            .clipShape(DogEarShape(radius: NotedDesign.Radius.card, fold: curl ? foldSize : 0))
            .overlay(alignment: .bottomTrailing) {
                if curl { PaperCurl(tone: tone).frame(width: foldSize, height: foldSize) }
            }
            .shadow(color: .black.opacity(0.06), radius: 2, y: 2) // v3: offset 0,2, blur 4 (CSS) = radius 2
    }
}

/// Rounded rectangle whose bottom-trailing corner is cut diagonally by `fold` points.
struct DogEarShape: Shape {
    let radius: CGFloat
    let fold: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        if fold > 0 {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
        } else {
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                        tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
        }
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

/// The corner flap folded back over the sheet: it mirrors the cut-out corner across
/// the crease, lifts slightly at the tip and casts a soft shadow onto the paper.
struct PaperCurl: View {
    let tone: NotedDesign.PaperTone
    /// Extra room so the flap's shadow is not cut off at the canvas edge.
    private let bleed: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) - bleed * 2
            context.translateBy(x: bleed, y: bleed)
            let topEnd = CGPoint(x: s, y: 0), bottomEnd = CGPoint(x: 0, y: s)
            let tip = CGPoint(x: s * 0.05, y: s * 0.05)
            let flap = Path { path in
                path.move(to: topEnd)
                // Edges bow inward a touch so the flap reads as lifted paper, not a flat sticker.
                path.addQuadCurve(to: tip, control: CGPoint(x: s * 0.42, y: s * 0.14))
                path.addQuadCurve(to: bottomEnd, control: CGPoint(x: s * 0.14, y: s * 0.42))
                path.closeSubpath()
            }
            let crease = CGPoint(x: s / 2, y: s / 2)

            context.drawLayer { layer in
                // The shadow lands only on the sheet, never in the cut-out corner past the crease.
                layer.clip(to: Path { path in
                    path.move(to: topEnd)
                    path.addLine(to: CGPoint(x: s, y: -bleed))
                    path.addLine(to: CGPoint(x: -bleed, y: -bleed))
                    path.addLine(to: CGPoint(x: -bleed, y: s))
                    path.addLine(to: bottomEnd)
                    path.closeSubpath()
                })
                layer.addFilter(.shadow(color: .black.opacity(0.16), radius: 2.5, x: -1, y: 1.5))
                layer.fill(flap, with: .color(tone.color))
            }
            // Back of the sheet: shaded at the crease, catching light toward the tip.
            context.fill(flap, with: .linearGradient(
                Gradient(colors: [.black.opacity(0.10), .white.opacity(0.28)]),
                startPoint: crease, endPoint: tip))
            context.stroke(Path { path in
                path.move(to: topEnd)
                path.addLine(to: bottomEnd)
            }, with: .color(.black.opacity(0.10)), lineWidth: 0.6)
        }
        .padding(-bleed)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PaperField<Content: View>: View {
    let label: String
    var spacing: CGFloat = 8
    var minHeight: CGFloat = 44
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            PaperFieldLabel(text: label)
            content()
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: minHeight)
                .background(NotedDesign.Palette.field, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(NotedDesign.Palette.border, lineWidth: 1) }
        }
    }
}

struct PaperFieldLabel: View {
    let text: String
    var body: some View {
        Text(text).scaledFont(15, relativeTo: .subheadline).foregroundStyle(NotedDesign.Palette.secondaryText)
    }
}

struct TagChip: View {
    let title: String
    var body: some View {
        Text(title).scaledFont(15, relativeTo: .subheadline)
            .foregroundStyle(NotedDesign.Palette.primaryText)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(NotedDesign.Palette.toneSage, in: Capsule())
    }
}

#Preview("Paper components") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(Array(NotedDesign.PaperTone.allCases.enumerated()), id: \.offset) { _, tone in
                PaperCard(tone: tone, curl: true) {
                    VStack(alignment: .leading) {
                        Text("Ý tưởng cuối tuần").font(.headline)
                        TagChip(title: "Cảm hứng")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
            }
            EqualWidthPillGroup(count: 3, visualHeight: 44) { index in
                NotedPill(title: ["Ghi chú", "Link", "Ảnh"][index], selected: index == 0, visualHeight: 44) {}
            }
            PaperField(label: "Tiêu đề") { TextField("Thêm tiêu đề", text: .constant("")) }
            CircleIconButton(symbol: "xmark", label: "Đóng") {}
            Button("Lưu nhanh") {}.buttonStyle(NotedButtonStyle(role: .primary, prominent: true))
            Button("Tạo bộ sưu tập") {}.buttonStyle(NotedButtonStyle(role: .soft))
        }.padding()
    }.paperBackground()
}
