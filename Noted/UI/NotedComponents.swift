import SwiftUI

/// Compatibility wrapper for screens migrating to the shared pill group.
struct NotedFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        NotedPill(title: title, selected: selected, action: action).frame(width: 96)
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
