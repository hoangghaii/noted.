#if DEBUG
import Foundation
import SwiftUI
import UIKit
import ImageIO

/// Evaluation labels stay outside library.store and are never included in a backup.
struct IntelligenceLabel: Codable, Equatable {
    let itemID: UUID
    var topic: String
    var secondaryTopics: [String]? = nil
    var desiredTags: [String]
    let split: String
    var labeledAt: Date
}

struct IntelligenceLabelFile: Codable {
    let schemaVersion: Int
    let splitSeed: String
    var labels: [IntelligenceLabel]
}

enum IntelligenceLabelStorage {
    static let splitSeed = "noted-topic-evaluation-v1"

    static func fileURL(for libraryRoot: URL) -> URL {
        libraryRoot.deletingLastPathComponent()
            .appendingPathComponent("IntelligenceEvaluation", isDirectory: true)
            .appendingPathComponent("labels.json")
    }

    static func split(for id: UUID) -> String {
        // A fixed hash assigns holdout before any threshold is calibrated.
        let bytes = Array((splitSeed + id.uuidString).utf8)
        let hash = bytes.reduce(UInt64(14_695_981_039_346_656_037)) { value, byte in
            (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return hash % 5 == 0 ? "holdout" : "calibration"
    }

    static func load(from url: URL) throws -> [UUID: IntelligenceLabel] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(IntelligenceLabelFile.self, from: Data(contentsOf: url))
        guard file.schemaVersion == 1, file.splitSeed == splitSeed else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return Dictionary(file.labels.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func save(_ labels: [UUID: IntelligenceLabel], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let file = IntelligenceLabelFile(schemaVersion: 1, splitSeed: splitSeed,
                                         labels: labels.values.sorted { $0.itemID.uuidString < $1.itemID.uuidString })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        // .atomic first writes a temporary file, then replaces the destination.
        try encoder.encode(file).write(to: url, options: .atomic)
    }
}

struct IntelligenceLabelingView: View {
    @Environment(\.linkDigestRunner) private var digestRunner
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var labels: [UUID: IntelligenceLabel] = [:]
    @State private var index = 0
    @State private var topic = "Không rõ"
    @State private var customTopic = ""
    @State private var secondaryTopics = ""
    @State private var desiredTags = ""
    @State private var error: String?
    @State private var isEvaluating = false
    @State private var evaluationReport: IntelligenceSpikeReport?
    @State private var reportURL: URL?
    @State private var isRequestingAssets = false
    @State private var assetStatus: String?
    @State private var linkReport = LinkSourceReport()
    @State private var linkPreviews: [UUID: LinkSourcePreview] = [:]
    @State private var linkProgress: (done: Int, total: Int)?
    /// False when an existing link-sources.json could not be read; measuring would overwrite earlier runs.
    @State private var linkReportReadable = true
    private let topics = ["Cà phê", "Tìm việc", "Carepath", "Kiếm thêm thu nhập", "Hài hước", "Không rõ", "Chủ đề khác…"]

    private var items: [Item] {
        store.items.filter { $0.trashedAt == nil }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var current: Item? { items.indices.contains(index) ? items[index] : nil }
    private var labelURL: URL { IntelligenceLabelStorage.fileURL(for: store.root) }
    private var linkReportURL: URL { LinkSourceSpike.reportURL(for: store.root) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thống kê thư viện") {
                    LabeledContent("Tổng đang lưu", value: "\(items.count)")
                    LabeledContent("Ảnh", value: "\(items.filter { $0.kind == "image" }.count)")
                    LabeledContent("Ảnh có OCR", value: "\(items.filter { $0.kind == "image" && !$0.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)")
                    LabeledContent("Ảnh không OCR", value: "\(items.filter { $0.kind == "image" && $0.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)")
                    LabeledContent("Link", value: "\(items.filter { $0.kind == "link" }.count)")
                    LabeledContent("Ghi chú", value: "\(items.filter { $0.kind == "text" }.count)")
                    LabeledContent("Đã gán nhãn", value: "\(items.filter { labels[$0.id] != nil }.count)")
                    Text("Nhãn chỉ lưu trên máy trong Application Support, ngoài library.store và backup.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if FileManager.default.fileExists(atPath: labelURL.path) {
                        ShareLink(item: labelURL) {
                            Label("Xuất nhãn để đánh giá", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("intelligenceExportLabels")
                    }
                }

                Section {
                    Button("Chạy đánh giá local") {
                        Task { await evaluate() }
                    }
                    .disabled(isEvaluating)
                    .accessibilityIdentifier("intelligenceRunEvaluation")
                    if isEvaluating { ProgressView("Đang đo, hãy giữ app mở…") }
                    if let report = evaluationReport {
                        Text("\(report.counts.labeled) nhãn · \(report.counts.holdout) holdout · \(report.visionProcessed) ảnh Vision")
                        Text(report.dataSource != "library" ? "Bộ mẫu tổng hợp do AI viết; không dùng để nghiệm thu gate."
                             : report.sufficientLabelsForGate ? "Đã đủ số nhãn tối thiểu; còn phải xem quality gate." : "Chưa đủ nhãn để kết luận chất lượng.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let reportURL {
                        ShareLink(item: reportURL) {
                            Label("Xuất báo cáo tổng hợp", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("intelligenceExportReport")
                    }
                    // Kept below the results so running/exporting stays in the same place.
                    Button("Tải model Natural Language tiếng Việt") {
                        Task { await requestContextualAssets() }
                    }
                    .disabled(isRequestingAssets || isEvaluating)
                    .accessibilityIdentifier("intelligenceRequestAssets")
                    if isRequestingAssets { ProgressView("Đang tải model của Apple…") }
                    if let assetStatus { Text(assetStatus).font(.footnote) }
                    Button("Chạy trên bộ mẫu tổng hợp") {
                        Task { await evaluate(synthetic: true) }
                    }
                    .disabled(isEvaluating)
                    .accessibilityIdentifier("intelligenceRunSynthetic")
                } header: {
                    Text("Đo trên máy · DEBUG")
                } footer: {
                    Text("Báo cáo chỉ chứa số đếm và kết quả theo nhóm, không chứa nội dung mục. Không gửi dữ liệu nếu bạn không chọn xuất.")
                }

                linkSourceSection

                if let item = current {
                    Section("Mục \(index + 1)/\(items.count) · \(IntelligenceLabelStorage.split(for: item.id))") {
                        if item.kind == "image", let attachment = item.attachments.first,
                           let image = Self.previewImage(at: store.attachmentURL(attachment)) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260)
                                .accessibilityLabel("Ảnh của mục đang gán nhãn")
                        }
                        Text(item.displayTitle).font(.headline)
                        if !item.body.isEmpty { Text(item.body).lineLimit(8) }
                        if !item.originalURL.isEmpty { Text(item.originalURL).font(.footnote).lineLimit(3) }
                        if item.kind == "link", let digest = digestRunner?.digest(for: item) {
                            if let summary = digest.visibleSummary {
                                if let title = digest.title { Text(title).font(.headline) }
                                if !digest.byline.isEmpty { Text(digest.byline).font(.subheadline) }
                                Text(summary).accessibilityIdentifier("labelingLinkSummary")
                            } else if digest.state == .loginWall {
                                Text("Không đọc được nội dung (cần đăng nhập). Bạn có thể thêm ghi chú trong chi tiết link.")
                            }
                        }
                        if !item.ocrText.isEmpty {
                            Text("OCR: \(item.ocrText)").font(.footnote).lineLimit(8)
                        }
                        Text("ID: \(item.id.uuidString)").font(.caption2).textSelection(.enabled)
                    }
                    Section("Nhãn mong muốn") {
                        Picker("Chủ đề chính", selection: $topic) {
                            ForEach(topics, id: \.self) { Text($0).tag($0) }
                        }
                        if topic == "Chủ đề khác…" {
                            TextField("Tên chủ đề", text: $customTopic)
                                .textInputAutocapitalization(.sentences)
                        }
                        TextField("Chủ đề phụ, tối đa 2, cách nhau dấu phẩy", text: $secondaryTopics)
                            .textInputAutocapitalization(.sentences)
                        TextField("Tag mong muốn, cách nhau bằng dấu phẩy", text: $desiredTags)
                            .textInputAutocapitalization(.never)
                        Button("Lưu nhãn và tiếp tục") { saveAndAdvance(item) }
                            .disabled(selectedTopic.isEmpty || secondaryCandidates.filter { $0 != selectedTopic }.count > 2)
                            .accessibilityIdentifier("intelligenceSaveLabel")
                    }
                    Section {
                        HStack {
                            Button("Trước") { select(index - 1) }.disabled(index == 0)
                            Spacer()
                            Button("Sau") { select(index + 1) }.disabled(index >= items.count - 1)
                        }
                    }
                } else {
                    Section { Text("Chưa có mục nào để gán nhãn.") }
                }
                if let error {
                    Section("Lỗi lưu nhãn") { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Gán nhãn chủ đề · DEBUG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
            .task { load() }
        }
    }

    @ViewBuilder private var linkSourceSection: some View {
        Section {
            Button("Đo nguồn link") { Task { await measureLinkSources() } }
                .disabled(linkProgress != nil || !linkReportReadable || items.allSatisfy { $0.kind != "link" })
                .accessibilityIdentifier("intelligenceMeasureLinkSources")
            if let linkProgress {
                ProgressView(value: Double(linkProgress.done), total: Double(max(linkProgress.total, 1))) {
                    Text("Đang đo \(linkProgress.done)/\(linkProgress.total), mỗi request cách nhau ~1 giây…")
                }
            }
            if let run = linkReport.runs.last {
                Text("\(linkReport.runs.count) lần đo · lần cuối \(run.measuredAt.formatted(date: .abbreviated, time: .shortened)) · \(run.results.count) link")
                    .font(.footnote)
                ForEach(run.summary.filter { $0.strategy != .linkPresentation }, id: \.self) { row in
                    LabeledContent("\(row.domain) · \(row.strategy.rawValue)",
                                   value: "\(row.usable)/\(row.attempted) dùng được · \(row.loginWall) login")
                        .font(.footnote)
                }
                NavigationLink("Xem và đánh giá từng link") {
                    LinkSourceReviewView(run: run, previews: linkPreviews, items: store.items,
                                         judgments: $linkReport.judgments) { saveLinkReport(linkReport) }
                }
            }
            if FileManager.default.fileExists(atPath: linkReportURL.path) {
                ShareLink(item: linkReportURL) { Label("Xuất link-sources.json", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("intelligenceExportLinkSources")
            }
        } header: {
            Text("Nguồn link · DEBUG")
        } footer: {
            Text("Mỗi link được gọi 1 lần cho mỗi chiến lược, không đăng nhập, không cookie. File chỉ chứa domain, cờ, độ dài và hash; nội dung trang chỉ hiển thị trên máy cho tới khi đóng màn này.")
        }
    }

    @MainActor
    private func measureLinkSources() async {
        guard linkProgress == nil, linkReportReadable else { return }
        let links = items.filter { $0.kind == "link" }.compactMap { item in
            URL(string: item.originalURL).map { (id: item.id, url: $0) }
        }
        linkProgress = (0, links.count * LinkSourceStrategy.allCases.count)
        defer { linkProgress = nil }
        let (run, previews) = await LinkSourceSpike.run(links: links) { done, total in linkProgress = (done, total) }
        var updated = linkReport
        updated.runs.append(run)
        linkPreviews = previews
        if saveLinkReport(updated) { linkReport = updated }
    }

    @discardableResult
    private func saveLinkReport(_ report: LinkSourceReport) -> Bool {
        do {
            try LinkSourceSpike.save(report, to: linkReportURL)
            return true
        } catch {
            self.error = "Không lưu được link-sources.json: \(error.localizedDescription)"
            return false
        }
    }

    private func load() {
        do {
            linkReport = try LinkSourceSpike.load(from: linkReportURL)
        } catch {
            linkReportReadable = false
            self.error = "Không đọc được link-sources.json: \(error.localizedDescription)"
        }
        do {
            labels = try IntelligenceLabelStorage.load(from: labelURL)
            error = nil
            index = items.firstIndex(where: { labels[$0.id] == nil }) ?? 0
            select(index)
        } catch {
            self.error = "Không đọc được file nhãn: \(error.localizedDescription). Nhãn cũ được giữ nguyên; chưa thể lưu thêm."
        }
    }

    private func select(_ next: Int) {
        guard items.indices.contains(next) else { return }
        index = next
        let label = labels[items[next].id]
        topic = label.map { topics.contains($0.topic) ? $0.topic : "Chủ đề khác…" } ?? "Không rõ"
        customTopic = topic == "Chủ đề khác…" ? (label?.topic ?? "") : ""
        secondaryTopics = label?.secondaryTopics?.joined(separator: ", ") ?? ""
        desiredTags = label?.desiredTags.joined(separator: ", ") ?? ""
    }

    private var secondaryCandidates: [String] {
        Array(Set(secondaryTopics.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
    }

    private var selectedTopic: String {
        topic == "Chủ đề khác…" ? customTopic.trimmingCharacters(in: .whitespacesAndNewlines) : topic
    }

    private func saveAndAdvance(_ item: Item) {
        guard error == nil else { return }
        let chosenTopic = selectedTopic
        let tags = Array(Set(desiredTags.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
        var updated = labels
        updated[item.id] = IntelligenceLabel(itemID: item.id, topic: chosenTopic,
                                             secondaryTopics: secondaryCandidates.filter { $0 != chosenTopic }, desiredTags: tags,
                                             split: IntelligenceLabelStorage.split(for: item.id), labeledAt: Date())
        do {
            try IntelligenceLabelStorage.save(updated, to: labelURL)
            labels = updated
            if index < items.count - 1 { select(index + 1) }
        } catch {
            self.error = "Không lưu được nhãn: \(error.localizedDescription)"
        }
    }

    /// Downloads only Apple's model asset; no library content leaves the device.
    @MainActor
    private func requestContextualAssets() async {
        guard !isRequestingAssets else { return }
        guard let engine = ContextualEmbeddingEngine() else {
            assetStatus = "iOS không có model tiếng Việt cho NLContextualEmbedding."
            return
        }
        guard !engine.hasAvailableAssets else {
            assetStatus = "Model đã có trên máy."
            return
        }
        isRequestingAssets = true
        defer { isRequestingAssets = false }
        do {
            switch try await engine.requestAssets() {
            case .available: assetStatus = "Đã tải model. Chạy lại đánh giá để đo."
            case .notAvailable: assetStatus = "Apple báo model hiện không có cho máy này."
            case .error: assetStatus = "Tải model lỗi."
            @unknown default: assetStatus = "Kết quả tải model không xác định."
            }
        } catch {
            assetStatus = "Tải model lỗi: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func evaluate(synthetic: Bool = false) async {
        guard !isEvaluating, error == nil else { return }
        isEvaluating = true
        defer { isEvaluating = false }
        let samples = synthetic ? IntelligenceSyntheticCorpus.samples()
            : IntelligenceSpikeEvaluator.snapshots(store: store, labels: labels, digests: digestRunner?.digests ?? [:])
        let source = synthetic ? IntelligenceSyntheticCorpus.version : "library"
        let report = await Task.detached(priority: .utility) {
            IntelligenceSpikeEvaluator.evaluate(samples, dataSource: source)
        }.value
        do {
            // Separate files so a synthetic run never overwrites the real-library report.
            let url = labelURL.deletingLastPathComponent()
                .appendingPathComponent(synthetic ? "report-synthetic.json" : "report.json")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: url, options: .atomic)
            evaluationReport = report
            reportURL = url
        } catch {
            self.error = "Không lưu được báo cáo đánh giá: \(error.localizedDescription)"
        }
    }

    private static func previewImage(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}

/// Lets the user judge, per link, whether what was fetched is enough to assign a topic.
/// Page text comes from the in-memory previews of the latest run only.
struct LinkSourceReviewView: View {
    let run: LinkSourceRun
    let previews: [UUID: LinkSourcePreview]
    let items: [Item]
    @Binding var judgments: [String: Bool]
    /// Persists the parent's whole report so runs and judgments stay in one file.
    let onJudge: () -> Void

    var body: some View {
        List {
            Section {
                let judged = run.results.filter { judgments[$0.itemID.uuidString] != nil }
                Text("\(judged.count)/\(run.results.count) link đã đánh giá · \(judged.filter { judgments[$0.itemID.uuidString] == true }.count) đủ để gán")
                if previews.isEmpty {
                    Text("Nội dung trang không được lưu. Chạy “Đo nguồn link” lại để xem nội dung lấy được.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            ForEach(run.results, id: \.itemID) { result in
                Section(result.domain) {
                    let preview = previews[result.itemID]
                    let item = items.first { $0.id == result.itemID }
                    Text(preview?.title.isEmpty == false ? preview!.title : (item?.displayTitle ?? "—")).font(.headline)
                    if let description = preview?.description, !description.isEmpty {
                        Text(description).font(.footnote).lineLimit(6)
                    }
                    if let url = item?.originalURL { Text(url).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                    Text(result.attempts.map { attempt in
                        "\(attempt.strategy.rawValue): \(attempt.httpStatus.map(String.init) ?? attempt.error ?? "-")"
                            + (attempt.loginWall ? " login" : "") + (attempt.usable ? " ✓" : "")
                    }.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                    Picker("Đủ để gán chủ đề?", selection: binding(for: result.itemID)) {
                        Text("Chưa đánh giá").tag(Bool?.none)
                        Text("Đủ").tag(Bool?.some(true))
                        Text("Không đủ").tag(Bool?.some(false))
                    }
                }
            }
        }
        .navigationTitle("Đánh giá nguồn link")
    }

    private func binding(for id: UUID) -> Binding<Bool?> {
        Binding(get: { judgments[id.uuidString] }, set: { value in
            judgments[id.uuidString] = value
            onJudge()
        })
    }
}
#endif
