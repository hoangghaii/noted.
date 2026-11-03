import XCTest

/// Run only with a physical iPhone destination. Existing shared data is never cleared.
final class PhaseOneUITests: XCTestCase {
    private let app = XCUIApplication()
    private var runID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        runID = String(UUID().uuidString.prefix(8))
        app.launchArguments = ["--device-gate-fixtures"]
        app.launchEnvironment["NOTED_GATE_RUN_ID"] = runID
        app.launch()
        XCTAssertTrue(app.buttons["gateShareText"].waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Device gate failure"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Noted hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }

    func testSystemTextSharePersistsAfterRelaunch() throws {
        app.buttons["gateShareText"].tap()
        try saveThroughNotedExtension(host: app)
        app.buttons["gateShowInbox"].tap()
        let marker = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "NOTED DEVICE GATE TEXT " + runID)).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 15))
        attachScreenshot("Text received")
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(marker.waitForExistence(timeout: 15))
        attachScreenshot("Text survives relaunch")
    }

    func testLocalImageRenderingSettles() throws {
        app.buttons["gateSeedImage"].tap()
        XCTAssertTrue(app.staticTexts["Đã tạo ảnh thử trong vùng chung."].waitForExistence(timeout: 10))
        app.buttons["gateShowInbox"].tap()
        XCTAssertTrue(app.images["Ảnh đã lưu"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Đang đọc ảnh…"].exists)
        attachScreenshot("Local image has settled")
    }

    func testSystemURLShare() throws {
        app.buttons["gateShareURL"].tap()
        try saveThroughNotedExtension(host: app)
        app.buttons["gateShowInbox"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "noted-gate=" + runID)).firstMatch.waitForExistence(timeout: 15))
        attachScreenshot("URL received")
    }

    func testSystemPNGShare() throws {
        app.buttons["gateShareImage"].tap()
        try saveThroughNotedExtension(host: app)
        app.buttons["gateShowInbox"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "NOTED DEVICE GATE IMAGE " + runID)).firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["Ảnh đã lưu"].firstMatch.waitForExistence(timeout: 15))
        attachScreenshot("PNG received and decoded")
    }

    /// This additionally verifies Safari as the host when it is the default browser.
    /// Run separately; do not treat fixture-host tests as Safari/Photos evidence.
    func testSafariURLShare() throws {
        app.buttons["gateOpenBrowser"].tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20), "Safari must be the default browser for this fixture.")
        let hierarchy = XCTAttachment(string: safari.debugDescription)
        hierarchy.name = "Safari hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let share = safari.buttons.matching(NSPredicate(format: "identifier == 'Share' OR label == 'Share' OR label == 'Chia sẻ'")).firstMatch
        if !share.exists, safari.buttons["MoreMenuButton"].exists {
            safari.buttons["MoreMenuButton"].tap()
        }
        XCTAssertTrue(share.waitForExistence(timeout: 20), "Safari Share button unavailable; inspect screenshot rather than guessing coordinates.")
        share.tap()
        try saveThroughNotedExtension(host: safari, expectedPreview: "Liên kết")
        app.activate()
        app.buttons["gateShowInbox"].tap()
        let matching = app.links
            .matching(NSPredicate(format: "label CONTAINS %@", "noted-gate=" + runID))
        XCTAssertTrue(matching.firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(matching.count, 1, "One Safari URL Share must produce one URL entry.")
        attachScreenshot("Safari URL received")
    }

    func saveThroughNotedExtension(host hostApp: XCUIApplication, expectedPreview: String? = nil) throws {
        let service = XCUIApplication(bundleIdentifier: "com.apple.UIKit.ShareUIService")
        let host = service.state == .notRunning ? hostApp : service
        let hierarchy = XCTAttachment(string: host.debugDescription)
        hierarchy.name = "Share chooser hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let destination = host.descendants(matching: .any).matching(NSPredicate(format: "label == 'Noted.' OR label == 'Copy to Noted.' OR label == 'Sao chép vào Noted.'")).firstMatch
        let more = host.cells.matching(identifier: "shareCell")
            .matching(NSPredicate(format: "label == 'More' OR label == 'Thêm'")).firstMatch
        let activityCollection = host.collectionViews["activityCollectionView"]
        XCTAssertTrue(activityCollection.waitForExistence(timeout: 10))
        let appRow = activityCollection.scrollViews.firstMatch
        XCTAssertTrue(appRow.exists, "Share app row unavailable.")
        for _ in 0..<8 {
            if destination.exists && destination.isHittable { break }
            if more.exists && more.isHittable { more.tap(); break }
            // iOS 27 reports the remote Share row as having an empty visible frame.
            // Drag through its screen position using the host app's coordinate space.
            let y = min(0.9, max(0.1, appRow.frame.midY / host.frame.height))
            host.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: y))
                .press(forDuration: 0.05, thenDragTo: host.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: y)))
        }
        if !destination.exists {
            let appsList = host.tables["tableView"]
            if appsList.exists {
                for _ in 0..<8 {
                    if destination.exists && destination.isHittable { break }
                    appsList.swipeUp()
                }
            }
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Noted extension not visible in activity picker.")
        destination.tap()
        let preview = host.descendants(matching: .any).matching(identifier: "sharePreview").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "Share preview must appear before saving.")
        if let expectedPreview {
            XCTAssertTrue(preview.label.contains(expectedPreview), "Share preview must describe the selected content: \(preview.label)")
        }
        attachScreenshot("Share preview before save")
        let save = host.buttons["shareSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Extension did not open.")
        save.tap()
        XCTAssertTrue(host.staticTexts["Đã lưu trên iPhone"].waitForExistence(timeout: 20), "Extension did not confirm durable save.")
        attachScreenshot("Extension confirmed durable save")
        save.tap() // Same stable ID now labels the completion action “Xong”.
        if host.buttons["gateShowInbox"].waitForExistence(timeout: 3) { return }
        let close = host.buttons.matching(NSPredicate(format: "label == 'Close' OR label == 'Đóng' OR label == 'Cancel' OR label == 'Hủy'")).firstMatch
        if close.exists && close.isHittable { close.tap() }
    }

    func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
