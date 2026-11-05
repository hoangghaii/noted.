import Foundation
import Darwin

enum LinkPreviewError: LocalizedError {
    case unsafeURL, oversized, invalidResponse
    var errorDescription: String? {
        switch self {
        case .unsafeURL: "Link này được giữ nguyên nhưng không được tải preview."
        case .oversized: "Preview vượt giới hạn tải. Link gốc vẫn được giữ."
        case .invalidResponse: "Không lấy được preview. Link gốc vẫn được giữ."
        }
    }
}

enum LinkMetadataService {
    static let maximumBytes = 512 * 1024

    static func title(for url: URL) async throws -> String {
        try await Task.detached(priority: .utility) { try PublicURLPolicy.validate(url) }.value
        let data = try await BoundedMetadataDownload().load(url)
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return title(fromHTML: html, url: url)
    }

    /// One request for the link digest, never over Low Data Mode (it runs in the background). Pages over `maximumBytes` keep their prefix instead of failing:
    /// meta tags sit in the first few KB (Threads pages are ~600 KB; link-understanding Phase 01).
    static func fetchPage(for url: URL) async throws -> LinkPage {
        try await Task.detached(priority: .utility) { try PublicURLPolicy.validate(url) }.value
        let download = BoundedMetadataDownload(keepPrefixWhenOversized: true, allowsConstrainedNetworkAccess: false)
        let data = try await download.load(url)
        // A truncated prefix may end mid-character, so it is decoded leniently.
        let html = String(data: data, encoding: .utf8)
            ?? (download.truncated ? String(decoding: data, as: UTF8.self) : String(data: data, encoding: .isoLatin1) ?? "")
        return LinkPage(url: url, finalURL: download.redirectURLs.last ?? url, html: html,
                        statusCode: download.httpStatus, truncated: download.truncated,
                        redirectCount: download.redirectURLs.count,
                        redirectedToLogin: download.redirectURLs.contains(where: ExtractiveLinkDigester.isLoginURL))
    }

    /// The `<title>` of a page, or the host when there is none. Behavior used by `EnrichmentRunner`.
    static func title(fromHTML html: String, url: URL) -> String {
        let pattern = "(?is)<title[^>]*>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return url.host ?? url.absoluteString }
        return String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(300).description
    }
}

/// One downloaded page (or its first `LinkMetadataService.maximumBytes`).
struct LinkPage: Sendable {
    let url: URL
    let finalURL: URL
    let html: String
    let statusCode: Int?
    let truncated: Bool
    let redirectCount: Int
    let redirectedToLogin: Bool
}

enum PublicURLPolicy {
    static func validate(_ url: URL) throws {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.user == nil, url.password == nil, let host = url.host?.lowercased(),
              !host.isEmpty, !isLocalName(host)
        else { throw LinkPreviewError.unsafeURL }
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { throw LinkPreviewError.unsafeURL }
        defer { freeaddrinfo(first) }
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let record = current {
            guard let address = record.pointee.ai_addr else { throw LinkPreviewError.unsafeURL }
            if record.pointee.ai_family == AF_INET {
                let value = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
                }
                guard isPublicIPv4(value) else { throw LinkPreviewError.unsafeURL }
            } else if record.pointee.ai_family == AF_INET6 {
                let bytes = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    withUnsafeBytes(of: $0.pointee.sin6_addr) { Array($0) }
                }
                let mapped = bytes.prefix(10).allSatisfy { $0 == 0 } && bytes[10] == 255 && bytes[11] == 255
                if mapped {
                    let ipv4 = bytes.suffix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
                    guard isPublicIPv4(ipv4) else { throw LinkPreviewError.unsafeURL }
                } else {
                    // Restrict to global-unicast 2000::/3 and reject known
                    // special-purpose/documentation and transition prefixes.
                    let globalUnicast = bytes[0] & 0xe0 == 0x20
                    let documentation = bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8
                    let special2001 = bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x00
                    let sixToFour = bytes[0] == 0x20 && bytes[1] == 0x02
                    guard globalUnicast, !documentation, !special2001, !sixToFour
                    else { throw LinkPreviewError.unsafeURL }
                }
            } else { throw LinkPreviewError.unsafeURL }
            current = record.pointee.ai_next
        }
    }

    static func isPublicIPv4(_ value: UInt32) -> Bool {
        let a = value >> 24, b = (value >> 16) & 255
        let c = (value >> 8) & 255
        // Exclude special-purpose, documentation, benchmarking, private and
        // shared-address ranges. Preview should only contact globally routed hosts.
        return a != 0 && a != 10 && a != 127 && (1...223).contains(a) &&
            !(a == 100 && (64...127).contains(b)) &&
            !(a == 169 && b == 254) &&
            !(a == 172 && (16...31).contains(b)) &&
            !(a == 192 && b == 0 && c == 0) &&
            !(a == 192 && b == 0 && c == 2) &&
            !(a == 192 && b == 88 && c == 99) &&
            !(a == 192 && b == 168) &&
            !(a == 198 && (18...19).contains(b)) &&
            !(a == 198 && b == 51 && c == 100) &&
            !(a == 203 && b == 0 && c == 113)
    }

    private static func isLocalName(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return normalized == "localhost" || normalized.hasSuffix(".localhost") ||
            normalized.hasSuffix(".local") || normalized.hasSuffix(".internal")
    }
}

/// Serial delegate bounds bytes as they arrive, rather than buffering an unbounded response.
/// Each instance performs one load; status and redirect targets stay readable afterwards for diagnostics.
final class BoundedMetadataDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let userAgent: String?
    private let acceptedMIMETypes: Set<String>
    private let keepPrefixWhenOversized: Bool
    private let allowsConstrainedNetworkAccess: Bool
    private let delegateQueue: OperationQueue = { let q = OperationQueue(); q.maxConcurrentOperationCount = 1; return q }()
    private let cancellationLock = NSLock()
    private var cancelRequested = false
    private var apiMode = false
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Data, Error>?
    private var data = Data()
    private var redirects = 0
    private(set) var httpStatus: Int?
    private(set) var redirectURLs: [URL] = []
    private(set) var truncated = false

    /// Defaults keep the production preview request unchanged (URLSession user agent, HTML only, fail when oversized).
    /// `keepPrefixWhenOversized` stops at the byte limit and returns the prefix: meta tags sit in the first few KB
    /// even when the page (e.g. Threads, ~600 KB) is larger than the limit.
    init(userAgent: String? = nil, acceptedMIMETypes: Set<String> = ["text/html", "application/xhtml+xml"],
         keepPrefixWhenOversized: Bool = false, allowsConstrainedNetworkAccess: Bool = true) {
        self.userAgent = userAgent
        self.acceptedMIMETypes = acceptedMIMETypes
        self.keepPrefixWhenOversized = keepPrefixWhenOversized
        self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
    }

    func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(acceptedMIMETypes.sorted().joined(separator: ","), forHTTPHeaderField: "Accept")
        if let userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
        return try await load(request, apiMode: false)
    }

    /// POST transport shares the byte bound, drops redirects (including same-host), cookies and cache.
    /// API status is returned to the caller, so 429 is handled without decoding/logging the error body.
    func load(_ request: URLRequest, apiMode: Bool,
              configuration: URLSessionConfiguration = .ephemeral) async throws -> Data {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegateQueue.addOperation {
                    self.apiMode = apiMode
                    self.continuation = continuation
                    self.cancellationLock.lock()
                    let cancelled = self.cancelRequested
                    self.cancellationLock.unlock()
                    if cancelled { self.finish(.failure(CancellationError())); return }
                    configuration.timeoutIntervalForRequest = apiMode ? 15 : 8
                    configuration.timeoutIntervalForResource = apiMode ? 15 : 12
                    configuration.httpShouldSetCookies = false
                    configuration.httpCookieStorage = nil
                    configuration.urlCredentialStorage = nil
                    configuration.urlCache = nil
                    configuration.allowsConstrainedNetworkAccess = self.allowsConstrainedNetworkAccess
                    self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: self.delegateQueue)
                    self.task = self.session?.dataTask(with: request)
                    self.task?.resume()
                }
            }
        } onCancel: {
            self.cancellationLock.lock()
            self.cancelRequested = true
            self.cancellationLock.unlock()
            self.delegateQueue.addOperation { self.finish(.failure(CancellationError())) }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        httpStatus = (response as? HTTPURLResponse)?.statusCode
        guard let http = response as? HTTPURLResponse, (apiMode || (200..<300).contains(http.statusCode)),
              (apiMode || acceptedMIMETypes.contains(response.mimeType ?? "")),
              keepPrefixWhenOversized || response.expectedContentLength <= LinkMetadataService.maximumBytes else {
            completionHandler(.cancel)
            finish(.failure(LinkPreviewError.invalidResponse))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive bytes: Data) {
        guard data.count + bytes.count <= LinkMetadataService.maximumBytes else {
            task?.cancel()
            if keepPrefixWhenOversized {
                data.append(bytes.prefix(LinkMetadataService.maximumBytes - data.count))
                truncated = true
                finish(.success(data))
            } else {
                finish(.failure(LinkPreviewError.oversized))
            }
            return
        }
        data.append(bytes)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        do {
            guard !apiMode else { throw LinkPreviewError.unsafeURL }
            redirects += 1
            guard redirects <= 3, let url = request.url else { throw LinkPreviewError.unsafeURL }
            redirectURLs.append(url)
            try PublicURLPolicy.validate(url)
            completionHandler(request)
        } catch {
            completionHandler(nil)
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) } else { finish(.success(data)) }
    }

    private func finish(_ result: Result<Data, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
        session?.invalidateAndCancel()
        session = nil
    }
}
