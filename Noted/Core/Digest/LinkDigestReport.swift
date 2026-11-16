#if DEBUG
import Foundation

/// Link-understanding Phase 06: digest outcome per domain on the real library.
/// Contains only domains, counts and timings — never URLs, titles or page text.
struct LinkDigestDomainRow: Codable, Hashable {
    var domain: String
    var total = 0
    var complete = 0
    var titleOnly = 0
    var loginWall = 0
    var unreachable = 0
    var failed = 0
    /// No current digest yet, or still pending/running.
    var notRead = 0
    /// Of `complete`, how many were written by the optional API.
    var api = 0
    var measured = 0
    var p50Milliseconds: Double?
    var p95Milliseconds: Double?
}

struct LinkDigestReport: Codable {
    var generatedAt: Date
    var engineVersion: String
    /// Facebook, Instagram and Threads first (reported separately), then the other domains by count.
    var rows: [LinkDigestDomainRow]
    var overall: LinkDigestDomainRow

    struct Entry {
        var domain: String
        var state: LinkDigestState?
        var source: LinkDigestSource
        var milliseconds: Double?
    }

    static let priorityDomains = ["facebook", "instagram", "threads"]

    static func make(_ entries: [Entry], now: Date = Date(),
                     engineVersion: String = ExtractiveLinkDigester.engineVersion) -> LinkDigestReport {
        let grouped = Dictionary(grouping: entries, by: \.domain)
        let rows = grouped.map { row(domain: $0.key, $0.value) }.sorted { lhs, rhs in
            let left = priorityDomains.firstIndex(of: lhs.domain) ?? priorityDomains.count
            let right = priorityDomains.firstIndex(of: rhs.domain) ?? priorityDomains.count
            if left != right { return left < right }
            if lhs.total != rhs.total { return lhs.total > rhs.total }
            return lhs.domain < rhs.domain
        }
        return LinkDigestReport(generatedAt: now, engineVersion: engineVersion, rows: rows,
                                overall: row(domain: "all", entries))
    }

    /// Live link items (not trashed) with their current digest and this process's fetch timing.
    @MainActor
    static func make(items: [Item], runner: LinkDigestRunner, now: Date = Date()) -> LinkDigestReport {
        let entries = items.filter { $0.kind == "link" && $0.trashedAt == nil }.map { item in
            let digest = runner.digest(for: item)
            return Entry(domain: URL(string: item.originalURL).map(ExtractiveLinkDigester.domain(for:)) ?? "unknown",
                         state: digest?.state,
                         source: digest.flatMap { LinkDigestSource(rawValue: $0.source) } ?? .extractive,
                         milliseconds: runner.fetchMilliseconds[item.id])
        }
        return make(entries, now: now)
    }

    private static func row(domain: String, _ entries: [Entry]) -> LinkDigestDomainRow {
        var row = LinkDigestDomainRow(domain: domain, total: entries.count)
        for entry in entries {
            switch entry.state {
            case .complete:
                row.complete += 1
                if entry.source == .api { row.api += 1 }
            case .titleOnly: row.titleOnly += 1
            case .loginWall: row.loginWall += 1
            case .unreachable: row.unreachable += 1
            case .failed: row.failed += 1
            case .pending, .running, nil: row.notRead += 1
            }
        }
        let timings = entries.compactMap(\.milliseconds)
        row.measured = timings.count
        row.p50Milliseconds = percentile(timings, 0.5)
        row.p95Milliseconds = percentile(timings, 0.95)
        return row
    }

    /// Nearest-rank percentile, the same rule as `IntelligenceSpikeEvaluator.p95`.
    static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[max(Int(ceil(Double(sorted.count) * fraction)) - 1, 0)]
    }

    static func fileURL(for libraryRoot: URL) -> URL {
        LinkSourceSpike.reportURL(for: libraryRoot).deletingLastPathComponent()
            .appendingPathComponent("link-digest-report.json")
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
#endif
