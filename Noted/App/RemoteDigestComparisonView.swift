#if DEBUG
import Foundation
import SwiftUI

/// Link-understanding Phase 06 step 7: the user compares the API rewrite with the extractive digest on readable links.
/// Page text and both summaries stay on screen only; the exported file holds domains and verdicts.
enum DigestComparisonVerdict: String, Codable, CaseIterable {
    case api, same, extractive

    var label: String {
        switch self {
        case .api: "API tốt hơn"
        case .same: "Ngang nhau"
        case .extractive: "Trích xuất tốt hơn"
        }
    }
}

struct DigestComparisonRow: Identifiable {
    let id: UUID
    let domain: String
    let extractive: LinkDigestContent
    /// Nil when the API call failed or its JSON was rejected; the app would fall back to `extractive`.
    let api: LinkDigestContent?
    var verdict: DigestComparisonVerdict?
}

struct DigestComparisonReport: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var domain: String
        var apiFailed: Bool
        var verdict: DigestComparisonVerdict?
    }

    var generatedAt: Date
    var model: String
    var entries: [Entry]
    var compared: Int
    var apiFailed: Int
    var apiBetter: Int
    var same: Int
    var extractiveBetter: Int

    init(rows: [DigestComparisonRow], model: String, now: Date = Date()) {
        generatedAt = now
        self.model = model
        entries = rows.map { Entry(domain: $0.domain, apiFailed: $0.api == nil, verdict: $0.verdict) }
        compared = rows.count
        apiFailed = rows.filter { $0.api == nil }.count
        apiBetter = rows.filter { $0.verdict == .api }.count
        same = rows.filter { $0.verdict == .same }.count
        extractiveBetter = rows.filter { $0.verdict == .extractive }.count
    }

    /// Acceptance of Phase 05: the API wins on most links that were judged.
    var apiWinsMajority: Bool {
        let judged = apiBetter + same + extractiveBetter
        return judged > 0 && apiBetter * 2 > judged
    }

    static func fileURL(for libraryRoot: URL) -> URL {
        LinkDigestReport.fileURL(for: libraryRoot).deletingLastPathComponent()
            .appendingPathComponent("digest-comparison.json")
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

struct RemoteDigestComparisonView: View {
    let store: LibraryStore
    @Environment(\.linkDigestRunner) private var digestRunner
    @State private var generator = RemoteTextGenerator.shared
    @State private var rows: [DigestComparisonRow] = []
    @State private var progress: (done: Int, total: Int)?
    @State private var message: String?

    /// `example.com` is reserved for documentation; those items are test fixtures, not the user's links.
    private var candidates: [Item] {
        guard let digestRunner else { return [] }
        return store.items.filter { item in
            guard item.kind == "link", item.trashedAt == nil, let url = URL(string: item.originalURL),
                  ExtractiveLinkDigester.domain(for: url) != "example.com" else { return false }
            return digestRunner.digest(for: item)?.state == .complete
        }
    }

    private var reportURL: URL { DigestComparisonReport.fileURL(for: store.root) }

    var body: some View {
        Form {
            Section {
                LabeledContent("Link đọc được", value: "\(candidates.count)")
                LabeledContent("Request API hôm nay", value: "\(generator.usedToday)/\(RemoteTextGenerator.dailyLimit)")
                if !generator.linksEnabled {
                    Text("Hãy bật “Tóm tắt link bằng AI” và lưu khóa trong Dữ liệu & Backup → AI tùy chọn trước.")
                        .font(.footnote)
                }
                Button("So sánh \(candidates.count) link") { Task { await compare() } }
                    .disabled(progress != nil || !generator.linksEnabled || candidates.isEmpty
                              || generator.usedToday + candidates.count > RemoteTextGenerator.dailyLimit)
                    .accessibilityIdentifier("digestComparisonRun")
                if let progress {
                    ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1))) {
                        Text("Đang so \(progress.done)/\(progress.total)…")
                    }
                }
                if let message { Text(message).font(.footnote) }
            } footer: {
                Text("Mỗi link: đọc lại trang (1 request) rồi gửi dữ liệu đã trích lên API (1 request, tính vào hạn mức ngày). Kết quả API chỉ hiện ở đây, không ghi vào digest. File xuất chỉ có domain và lựa chọn của bạn.")
            }

            ForEach($rows) { $row in
                Section(row.domain) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trích xuất").font(.caption.weight(.semibold))
                        if let title = row.extractive.title { Text(title).font(.subheadline.weight(.semibold)) }
                        Text(row.extractive.summary ?? "—").font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API").font(.caption.weight(.semibold))
                        if let api = row.api {
                            if let title = api.title { Text(title).font(.subheadline.weight(.semibold)) }
                            Text(api.summary ?? "—").font(.subheadline)
                        } else {
                            Text("API lỗi hoặc trả sai định dạng; app sẽ dùng bản trích xuất.").font(.subheadline)
                        }
                    }
                    if row.api != nil {
                        Picker("Bản nào tốt hơn?", selection: $row.verdict) {
                            Text("Chưa chọn").tag(DigestComparisonVerdict?.none)
                            ForEach(DigestComparisonVerdict.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                        }
                    }
                }
            }

            if !rows.isEmpty {
                Section {
                    let report = DigestComparisonReport(rows: rows, model: generator.model)
                    Text("API tốt hơn \(report.apiBetter) · ngang \(report.same) · trích xuất tốt hơn \(report.extractiveBetter) · API lỗi \(report.apiFailed)")
                        .font(.footnote)
                    Button("Lưu kết quả") { save() }
                    if FileManager.default.fileExists(atPath: reportURL.path) {
                        ShareLink(item: reportURL) { Label("Xuất digest-comparison.json", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .navigationTitle("So sánh API")
        .onAppear { generator.refreshUsage() }
    }

    @MainActor
    private func compare() async {
        let items = candidates
        progress = (0, items.count)
        defer { progress = nil }
        var result: [DigestComparisonRow] = []
        for (index, item) in items.enumerated() {
            guard !Task.isCancelled, generator.linksEnabled, let url = URL(string: item.originalURL) else { break }
            if index > 0 { try? await Task.sleep(for: .milliseconds(1200)) }
            do {
                let fetch = try await Task.detached(priority: .utility) { try await LinkDigestRunner.fetch(url) }.value
                // The page may have changed since the digest; only links still readable are compared.
                if fetch.content.status == .complete {
                    result.append(DigestComparisonRow(id: item.id, domain: ExtractiveLinkDigester.domain(for: url),
                                                      extractive: fetch.content,
                                                      api: await RemoteLinkDigester.rewrite(fetch, using: generator)))
                }
            } catch {
                message = "Bỏ qua 1 link không đọc được: \(error.localizedDescription)"
            }
            progress = (index + 1, items.count)
        }
        rows = result
    }

    private func save() {
        do {
            try DigestComparisonReport(rows: rows, model: generator.model).save(to: reportURL)
            message = "Đã lưu digest-comparison.json."
        } catch {
            message = "Không lưu được: \(error.localizedDescription)"
        }
    }
}
#endif
