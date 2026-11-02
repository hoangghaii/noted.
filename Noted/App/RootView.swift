import SwiftUI

struct RootView: View {
    let store: LibraryStore
    let onManageData: () -> Void
    @State private var showCapture = false
    @State private var showTrash = false
    @State private var selectedTab: Destination = .library

    private enum Destination: Hashable {
        case library, search, collections
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView(store: store, onManageData: onManageData,
                            onShowTrash: { showTrash = true }, onCapture: openCapture)
            }
            .tabItem { Label("Thư viện", systemImage: "square.grid.2x2") }
            .toolbar(.hidden, for: .tabBar)
            .tag(Destination.library)
            NavigationStack {
                SearchView(store: store)
            }
            .tabItem { Label("Tìm kiếm", systemImage: "magnifyingglass") }
            .toolbar(.hidden, for: .tabBar)
            .tag(Destination.search)
            NavigationStack {
                CollectionsView(store: store)
            }
            .tabItem { Label("Bộ sưu tập", systemImage: "folder") }
            .toolbar(.hidden, for: .tabBar)
            .tag(Destination.collections)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { destinationBar }
        .tint(NotedDesign.Palette.brand)
        .sheet(isPresented: $showCapture) { CaptureSheet(store: store) }
        .sheet(isPresented: $showTrash) { NavigationStack { TrashView(store: store) } }
    }

    private var destinationBar: some View {
        HStack(spacing: 0) {
            destinationButton(.library, title: "Thư viện", symbol: "square.grid.2x2", id: "libraryTab")
            destinationButton(.search, title: "Tìm kiếm", symbol: "magnifyingglass", id: "searchTab")
            destinationButton(.collections, title: "Bộ sưu tập", symbol: "folder", id: "collectionsTab")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, NotedDesign.Spacing.sm)
        .padding(.bottom, NotedDesign.Spacing.xs)
        .background {
            NotedDesign.Palette.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { NotedDesign.Palette.border.frame(height: 1) }
        }
    }

    private func destinationButton(_ destination: Destination, title: String, symbol: String, id: String) -> some View {
        Button {
            selectedTab = destination
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular))
                    .frame(height: 24)
                Text(title).font(.system(size: 11, weight: selectedTab == destination ? .bold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedTab == destination ? NotedDesign.Palette.brand : NotedDesign.Palette.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selectedTab == destination ? .isSelected : [])
    }

    private func openCapture() {
        guard !showCapture else { return }
        showCapture = true
    }
}
