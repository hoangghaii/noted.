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
        let pattern = "(?is)<title[^>]*>(.*?)</title>"
        let regex = try NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return url.host ?? url.absoluteString }
        return String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(300).description
    }
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
private final class BoundedMetadataDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<Data, Error>?
    private var data = Data()
    private var redirects = 0

    func load(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 12
            configuration.httpShouldSetCookies = false
            configuration.urlCache = nil
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
            var request = URLRequest(url: url)
            request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            task = session?.dataTask(with: request)
            task?.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              ["text/html", "application/xhtml+xml"].contains(response.mimeType ?? ""),
              response.expectedContentLength <= LinkMetadataService.maximumBytes else {
            completionHandler(.cancel)
            finish(.failure(LinkPreviewError.invalidResponse))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive bytes: Data) {
        guard data.count + bytes.count <= LinkMetadataService.maximumBytes else {
            task?.cancel()
            finish(.failure(LinkPreviewError.oversized))
            return
        }
        data.append(bytes)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        do {
            redirects += 1
            guard redirects <= 3, let url = request.url else { throw LinkPreviewError.unsafeURL }
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
