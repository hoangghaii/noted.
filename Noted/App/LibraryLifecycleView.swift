import SwiftUI
import UIKit

struct LibraryStartupView: View {
    @State private var store: LibraryStore?
    @State private var failure: String?
    @State private var incomingURL: URL?

    var body: some View {
        ZStack {
            if let store { MainLibraryView(store: store, externalURL: $incomingURL) }
            else if let failure {
                ContentUnavailableView {
                    Label("Chưa mở được thư viện", systemImage: "exclamationmark.shield")
                } description: {
                    Text(failure + "\nKhông gỡ app hoặc xóa dữ liệu. Hãy giữ bản backup.")
                } actions: {
                    Button("Thử lại") { openStore() }
                        .buttonStyle(NotedButtonStyle(role: .secondary))
                }
            } else { ProgressView("Đang mở ứng dụng Noted.").tint(NotedDesign.Palette.brand) }
        }
        .background(NotedDesign.Palette.paper)
        .background(KeyboardDismissObserver().frame(width: 0, height: 0))
        .task { if store == nil { openStore() } }
        .onOpenURL { incomingURL = $0 }
    }

    private func openStore() {
        do {
            #if DEBUG
            store = try MockFixtures.openIfRequested() ?? PhaseFourFixtures.openIfRequested() ?? LibraryStore()
            #else
            store = try LibraryStore()
            #endif
            failure = nil
        }
        catch { failure = error.localizedDescription }
    }
}

private struct MainLibraryView: View {
    let store: LibraryStore
    @Binding var externalURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    @State private var manageData = false
    @State private var enrichment = EnrichmentRunner()
    @State private var started = false
    @State private var importURL: URL?

    private var pendingSignature: String {
        store.items.map { "\($0.id):\($0.ocrStatus):\($0.previewStatus):\($0.trashedAt == nil)" }.joined(separator: ";")
    }

    var body: some View {
        RootView(store: store, onManageData: { importURL = nil; manageData = true })
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.isImporting {
                    NotedStatusBanner(message: "Đang nhập nội dung đã chia sẻ…", isLoading: true)
                } else if enrichment.running {
                    NotedStatusBanner(message: "Đang nhận diện chữ và cập nhật preview…", isLoading: true)
                }
            }
            .tint(NotedDesign.Palette.brand)
            .sheet(isPresented: $manageData) { DataManagementView(store: store, initialImportURL: importURL) }
            .task {
                guard !started else { return }
                started = true
                if let externalURL { importURL = externalURL; manageData = true; self.externalURL = nil }
                do {
                    try enrichment.recoverInterrupted(in: store)
                    try await store.importPending()
                    await enrichment.run(in: store)
                } catch { store.lastError = error.localizedDescription }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !manageData {
                    Task {
                        do { try await store.importPending() }
                        catch { store.lastError = error.localizedDescription }
                        await enrichment.run(in: store)
                    }
                }
            }
            .onChange(of: externalURL) { _, url in
                if let url { importURL = url; manageData = true; externalURL = nil }
            }
            .onChange(of: pendingSignature) { _, _ in
                if !manageData { Task { await enrichment.run(in: store) } }
            }
            .onChange(of: manageData) { _, presented in
                if !presented {
                    Task {
                        do {
                            if !enrichment.running { try enrichment.recoverInterrupted(in: store) }
                            try await store.importPending()
                        } catch { store.lastError = error.localizedDescription }
                        await enrichment.run(in: store)
                    }
                }
            }
    }
}



/// Observe taps without consuming button, picker, or navigation actions.
private struct KeyboardDismissObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissView { KeyboardDismissView() }
    func updateUIView(_ uiView: KeyboardDismissView, context: Context) {}
    static func dismantleUIView(_ uiView: KeyboardDismissView, coordinator: ()) { uiView.detach() }
}

private final class KeyboardDismissView: UIView, UIGestureRecognizerDelegate {
    private weak var observedWindow: UIWindow?
    private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        guard let window else { return }
        tap.cancelsTouchesInView = false
        // Deliver touchesEnded to the tapped view immediately; otherwise it waits for this
        // recognizer, whose keyboard dismissal reflows the layout first and the SwiftUI
        // control (e.g. the pin Toggle under an open keyboard) misses its own tap.
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        observedWindow = window
    }

    func detach() {
        observedWindow?.removeGestureRecognizer(tap)
        observedWindow = nil
    }

    // Dismiss after the current touch has been handled so the layout change cannot steal it.
    @objc private func dismissKeyboard() {
        DispatchQueue.main.async { [weak self] in self?.observedWindow?.endEditing(true) }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Ending editing inside a native alert can reposition it during the same
        // touch and swallow its action. Let modal controls own their keyboard.
        var responder: UIResponder? = touch.view
        while let candidate = responder {
            if candidate is UIAlertController { return false }
            responder = candidate.next
        }
        var view = touch.view
        while let candidate = view {
            // A tap inside any input must retain focus, including cursor selection.
            if candidate is UIControl || candidate is UITextView { return false }
            view = candidate.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}
