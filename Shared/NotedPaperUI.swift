import SwiftUI

// Shared by the app and Share Extension; no dependency on the app's data model.
enum NotedButtonRole: Equatable {
    case primary, secondary, soft, quiet, destructive
}

struct NotedButtonStyle: ButtonStyle {
    let role: NotedButtonRole
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(role == .soft ? .regular : .semibold))
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
    var visualHeight: CGFloat = 36
    let action: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var touchHeight: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol) }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .frame(width: 44, height: 44)
                .background(NotedDesign.Palette.chip, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PaperCard<Content: View>: View {
    var tone: NotedDesign.PaperTone = .cream
    var curl = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(tone.foreground)
            .paperBackground(tone.color)
            .clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
            .overlay(alignment: .bottomTrailing) {
                if curl { PaperCurl(tone: tone).frame(width: 30, height: 30) }
            }
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

struct PaperCurl: View {
    let tone: NotedDesign.PaperTone

    var body: some View {
        Canvas { context, size in
            let fold = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addQuadCurve(to: CGPoint(x: size.width, y: 0), control: .zero)
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            context.fill(fold, with: .color(NotedDesign.Palette.paper))
            let flap = Path { path in
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addQuadCurve(to: CGPoint(x: size.width, y: 0), control: .zero)
                path.addQuadCurve(to: CGPoint(x: 0, y: size.height), control: CGPoint(x: size.width, y: size.height))
            }
            context.fill(flap, with: .linearGradient(
                Gradient(colors: [tone.color, NotedDesign.Palette.surface]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PaperField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 15)).foregroundStyle(NotedDesign.Palette.secondaryText)
            content()
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(NotedDesign.Palette.field, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(NotedDesign.Palette.border, lineWidth: 1) }
        }
    }
}

struct TagChip: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 15))
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
