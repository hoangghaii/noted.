import XCTest
import Security
@testable import Noted

@MainActor
final class RemoteLinkDigesterTests: XCTestCase {
    private var defaults: UserDefaults!
    private var requests: RequestRecorder!

    override func setUp() async throws {
        let suite = "RemoteLinkTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        requests = RequestRecorder()
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    }

    private var extractive: LinkDigestContent {
        LinkDigestContent(title: "Trồng cây", siteName: "Trang mẫu", summary: "Cách trồng cây trong nhà từ bài viết gốc.",
                          textForEmbedding: "Bằng chứng trích xuất", status: .complete)
    }

    private func payload() throws -> String {
        try XCTUnwrap(RemoteLinkDigester.payload(fields: LinkPageFields(ogDescription: "Cách trồng cây trong nhà từ bài viết gốc.", mainText: "Tưới nước vừa đủ."),
                                               url: URL(string: "https://example.com/private?secret=value")!, content: extractive))
    }

    private func generator(status: Int = 200, output: String = #"{"title":"Cây trong nhà","summary":"Tưới nước vừa đủ."}"#,
                           error: URLError? = nil) -> RemoteTextGenerator {
        let recorder = requests!
        let stubID = UUID().uuidString
        RemoteStubProtocol.registry.set(stubID) { request in
            try recorder.append(request)
            if let error { throw error }
            let envelope: [String: Any] = ["choices": [["finish_reason": "stop", "message": ["content": output]]]]
            return (try JSONSerialization.data(withJSONObject: envelope), status)
        }
        addTeardownBlock { RemoteStubProtocol.registry.remove(stubID) }
        return RemoteTextGenerator(defaults: defaults, key: { "test-secret-never-log" }, transport: { request in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [RemoteStubProtocol.self]
            var request = request
            request.setValue(stubID, forHTTPHeaderField: "X-Noted-Test-Stub")
            let download = BoundedMetadataDownload()
            let data = try await download.load(request, apiMode: true, configuration: configuration)
            return (data, download.httpStatus ?? 0)
        }, validate: { _ in })
    }

    func testDefaultOffSendsNothing() async throws {
        let client = generator()
        XCTAssertFalse(client.linksEnabled)
        do { _ = try await client.generateLink(payload: payload()); XCTFail("Disabled") } catch {}
        XCTAssertEqual(requests.count, 0)
    }

    func testPayloadBoundsAndRemovesURLs() throws {
        let fields = LinkPageFields(ogDescription: "Đọc https://example.com/private?secret=value để biết thêm. " + String(repeating: "\\\"", count: 800),
                                    mainText: String(repeating: "Cây 🌳 ", count: 2_000))
        let text = try XCTUnwrap(RemoteLinkDigester.payload(fields: fields, url: URL(string: "https://example.com/private?secret=value")!, content: extractive))
        XCTAssertLessThanOrEqual(text.count, 2_000)
        XCTAssertFalse(text.contains("secret"))
        XCTAssertFalse(text.contains("https://"))
        let value = try JSONDecoder().decode(RemoteLinkDigester.Payload.self, from: Data(text.utf8))
        XCTAssertEqual(value.domain, "example.com")
        XCTAssertFalse(value.mainText.isEmpty)
    }

    func testLoginWallAndTitleOnlyNeverSend() async throws {
        let client = generator(); client.setLinksEnabled(true)
        for status in [LinkDigestStatus.loginWall, .titleOnly] {
            var content = extractive; content.status = status
            XCTAssertNil(RemoteLinkDigester.payload(fields: LinkPageFields(ogDescription: "Đăng nhập để xem"), url: URL(string: "https://example.com")!, content: content))
            let result = await RemoteLinkDigester.rewrite(LinkDigestFetch(content: content, rawTitle: "", remotePayload: "unsafe"), using: client)
            XCTAssertNil(result)
        }
        XCTAssertEqual(requests.count, 0)
    }

    func testPreviewExactlyMatchesSentDataAndKeyOnlyInHeader() async throws {
        let preview = try payload()
        let client = generator(); client.setLinksEnabled(true)
        let content = try await client.generateLink(payload: preview)
        XCTAssertNotNil(RemoteLinkDigester.validate(content, extractive: extractive))
        let request = try XCTUnwrap(requests.values.first)
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("test-secret"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret-never-log")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.last?["content"], "<page_data>\n" + preview + "\n</page_data>")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(client.usedToday, 1)
    }

    func testSchemaAndLengthValidation() throws {
        for output in [#"{"title":"x","summary":"ok","extra":"ignore"}"#, #"{"title":3,"summary":"ok"}"#,
                       #"{"title":" ","summary":"ok"}"#, #"{"title":"x","summary":null}"#,
                       "```json\n{}\n```", #"{"title":"<script>","summary":"ok"}"#,
                       "{\"title\":\"\(String(repeating: "a", count: 81))\",\"summary\":\"ok\"}",
                       "{\"title\":\"ok\",\"summary\":\"\(String(repeating: "a", count: 301))\"}"] {
            XCTAssertNil(RemoteLinkDigester.validate(output, extractive: extractive), output)
        }
        let valid = try XCTUnwrap(RemoteLinkDigester.validate(#"{"title":"Cây trong nhà","summary":"Tưới nước vừa đủ."}"#, extractive: extractive))
        XCTAssertEqual(valid.textForEmbedding, extractive.textForEmbedding)
        XCTAssertEqual(valid.siteName, extractive.siteName)
    }

    func test429TimeoutOfflineAndBadSchemaFallbackWithoutRetry() async throws {
        let fetch = LinkDigestFetch(content: extractive, rawTitle: "", remotePayload: try payload())
        for client in [generator(status: 429), generator(error: URLError(.timedOut)),
                       generator(error: URLError(.notConnectedToInternet)), generator(output: "{}") ] {
            let previous = requests.count
            client.setLinksEnabled(true)
            let result = await RemoteLinkDigester.rewrite(fetch, using: client)
            XCTAssertNil(result)
            XCTAssertEqual(requests.count, previous + 1)
        }
    }

    func testDailyBudgetSharedAndPersists() async throws {
        defaults.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: "remote.usage.day")
        defaults.set(49, forKey: "remote.usage.count")
        let first = generator(); first.setLinksEnabled(true)
        _ = try await first.generateLink(payload: payload())
        let second = generator()
        XCTAssertEqual(second.usedToday, 50)
        do { _ = try await second.generateLink(payload: payload()); XCTFail("Quota") } catch {}
        XCTAssertEqual(requests.count, 1)
    }

    func test429StopsFollowingRequests() async throws {
        let client = generator(status: 429); client.setLinksEnabled(true)
        for _ in 0..<2 { do { _ = try await client.generateLink(payload: payload()); XCTFail("429") } catch {} }
        XCTAssertEqual(requests.count, 1)
    }

    func testDisableCancelsInFlightAndReenableDropsOldResult() async throws {
        let started = expectation(description: "started")
        let cancelled = expectation(description: "cancelled")
        let client = RemoteTextGenerator(defaults: defaults, key: { "fake" }, transport: { _ in
            started.fulfill()
            do { try await Task.sleep(for: .seconds(30)) }
            catch { cancelled.fulfill(); throw error }
            return (Data(), 200)
        }, validate: { _ in })
        client.setLinksEnabled(true)
        let payload = try payload()
        let task = Task { try await client.generateLink(payload: payload) }
        await fulfillment(of: [started], timeout: 2)
        client.setLinksEnabled(false)
        client.setLinksEnabled(true)
        await fulfillment(of: [cancelled], timeout: 2)
        do { _ = try await task.value; XCTFail("Old result") } catch {}
    }

    func testEndpointChangeDisablesConsentAndRejectsCredentials() throws {
        let client = generator(); client.setLinksEnabled(true)
        XCTAssertThrowsError(try client.configure(endpoint: "http://localhost", model: "a"))
        XCTAssertThrowsError(try client.configure(endpoint: "https://user:pass@example.com", model: "a"))
        try client.configure(endpoint: "https://api.example.com/v1/chat/completions", model: "another-model")
        XCTAssertFalse(client.linksEnabled)
        XCTAssertEqual(generator().model, "another-model")
    }

    func testBoundedPOSTWithURLProtocolAndHTTPStatus() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteStubProtocol.self]
        let download = BoundedMetadataDownload()
        var request = URLRequest(url: URL(string: "https://example.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        let data = try await download.load(request, apiMode: true, configuration: configuration)
        XCTAssertEqual(download.httpStatus, 429)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "{}")
    }

    func testRunnerUsesAPIThenRebuildsExtractiveWhenDisabledAndBackupExcludesKey() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try LibraryStore(root: root.appendingPathComponent("library"), queue: ShareGateStore(root: root.appendingPathComponent("queue")))
        try await library.captureLink(URL(string: "https://example.com/private")!)
        let item = try XCTUnwrap(library.items.first)
        item.previewStatus = "complete"
        try library.saveChanges()
        let intelligence = try IntelligenceStore(root: root.appendingPathComponent("library/Intelligence"))
        let fetched = LinkDigestFetch(content: extractive, rawTitle: item.title, remotePayload: try payload())
        let client = generator(); client.setLinksEnabled(true)
        let runner = LinkDigestRunner(intelligence: intelligence, loader: { _ in fetched }, remote: client)
        await runner.run(in: library)
        XCTAssertEqual(runner.digest(for: item)?.source, "api")
        XCTAssertEqual(runner.digest(for: item)?.summary, "Tưới nước vừa đủ.")
        let backup = try await BackupService().export(store: library)
        defer { try? FileManager.default.removeItem(at: backup.url.deletingLastPathComponent()) }
        let files = try XCTUnwrap(FileManager.default.enumerator(at: backup.url, includingPropertiesForKeys: [.isRegularFileKey]))
        let exportedFiles = files.allObjects.compactMap { $0 as? URL }
        for file in exportedFiles where (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            let text = String(decoding: try Data(contentsOf: file), as: UTF8.self)
            XCTAssertFalse(text.contains("test-secret-never-log"))
            XCTAssertFalse(text.contains("remote.links.enabled"))
        }
        client.setLinksEnabled(false)
        try runner.retry(itemID: item.id)
        await runner.run(in: library)
        XCTAssertEqual(runner.digest(for: item)?.source, "extractive")
        XCTAssertEqual(runner.digest(for: item)?.summary, extractive.summary)
        XCTAssertEqual(requests.count, 1)
    }

    func testKeychainRoundTripUsesDeviceOnlyAccessibility() throws {
        let service = "Noted.RemoteKeyTest." + UUID().uuidString
        let store = APIKeyStore(service: service)
        defer { try? store.delete() }
        XCTAssertNil(try store.read())
        try store.save("test-secret-never-log")
        XCTAssertEqual(try store.read(), "test-secret-never-log")
        try store.save("replacement-synthetic-key")
        XCTAssertEqual(try store.read(), "replacement-synthetic-key")
        var result: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecReturnAttributes as String: true]
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertFalse(attributes[kSecAttrSynchronizable as String] as? Bool ?? false)
        try store.delete()
        XCTAssertNil(try store.read())
    }

    func testServerErrorsRetryAtMostTwice() async throws {
        let client = generator(status: 503); client.setLinksEnabled(true)
        do { _ = try await client.generateLink(payload: payload()); XCTFail("503") } catch {}
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(client.usedToday, 3)
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    var values: [URLRequest] { lock.lock(); defer { lock.unlock() }; return storage }
    var count: Int { values.count }
    func append(_ input: URLRequest) throws {
        var request = input
        // URLSession delivers POST bodies to URLProtocol as a stream on device.
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count >= 0 else { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
                if count == 0 { break }
                data.append(contentsOf: buffer.prefix(count))
                guard data.count <= LinkMetadataService.maximumBytes else { throw URLError(.dataLengthExceedsMaximum) }
            }
            request.httpBody = data
        }
        lock.lock(); defer { lock.unlock() }; storage.append(request)
    }
}

private final class RemoteStubProtocol: URLProtocol {
    static let registry = StubRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (data, status) = try Self.registry.response(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class StubRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [String: @Sendable (URLRequest) throws -> (Data, Int)] = [:]
    func set(_ id: String, handler: @escaping @Sendable (URLRequest) throws -> (Data, Int)) {
        lock.lock(); defer { lock.unlock() }; handlers[id] = handler
    }
    func remove(_ id: String) { lock.lock(); defer { lock.unlock() }; handlers.removeValue(forKey: id) }
    func response(_ request: URLRequest) throws -> (Data, Int) {
        lock.lock()
        let handler = handlers[request.value(forHTTPHeaderField: "X-Noted-Test-Stub") ?? ""]
        lock.unlock()
        return try handler?(request) ?? (Data("{}".utf8), 429)
    }
}
