import SwiftUI

enum NotedButtonRole: Equatable {
    case primary, secondary, quiet, destructive
}

struct NotedButtonStyle: ButtonStyle {
    let role: NotedButtonRole
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .padding(.horizontal, NotedDesign.Spacing.base)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(border, lineWidth: role == .quiet ? 0 : 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }

    private var foreground: Color {
        switch role {
        case .primary: NotedDesign.Palette.accentText
        case .secondary: NotedDesign.Palette.brand
        case .quiet: NotedDesign.Palette.brand
        case .destructive: NotedDesign.Palette.error
        }
    }

    private var background: Color {
        switch role {
        case .primary: NotedDesign.Palette.accent
        case .secondary: NotedDesign.Palette.brandSoft
        case .quiet: .clear
        case .destructive: NotedDesign.Palette.errorSoft
        }
    }

    private var border: Color {
        .clear
    }
}

struct NotedFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var width = 96

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: width)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? NotedDesign.Palette.onBrand : NotedDesign.Palette.secondaryText)
                .background(selected ? NotedDesign.Palette.brand : NotedDesign.Palette.paper, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct NotedStatusBanner: View {
    let message: String
    var isLoading = false

    var body: some View {
        HStack(spacing: NotedDesign.Spacing.sm) {
            if isLoading { ProgressView().tint(NotedDesign.Palette.brand) }
            else { Image(systemName: "exclamationmark.circle").foregroundStyle(NotedDesign.Palette.error) }
            Text(message)
                .font(.footnote)
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NotedDesign.Spacing.base)
        .frame(minHeight: 44)
        .background(NotedDesign.Palette.surface)
        .accessibilityElement(children: .combine)
    }
}

/// Keep progress visible when the form is scrolled or the keyboard is open.
extension View {
    func operationLoading(_ busy: Bool, message: String) -> some View {
        self.disabled(busy)
            .overlay {
                if busy {
                    ZStack {
                        Color.black.opacity(0.42).ignoresSafeArea()
                        VStack(spacing: NotedDesign.Spacing.sm) {
                            ProgressView().tint(NotedDesign.Palette.brand)
                            Text(message)
                                .font(NotedDesign.TypeStyle.heading)
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                            Text("Vui lòng đợi trong giây lát.")
                                .font(NotedDesign.TypeStyle.caption)
                                .foregroundStyle(NotedDesign.Palette.secondaryText)
                        }
                        .padding(NotedDesign.Spacing.lg)
                        .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("operationLoading")
                    }
                    .contentShape(Rectangle())
                }
            }
    }
}
