import XCTest

/// Every launch uses a fresh, isolated DEBUG library, queue and capture draft.
final class MockFidelityUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Mock fixture failure hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    private func capture(_ variant: String, ready: (XCUIApplication) -> XCUIElement) {
        app.launchEnvironment = ["NOTED_MOCK_FIXTURE": variant, "NOTED_MOCK_RUN": UUID().uuidString]
        app.launchArguments = ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(ready(app).waitForExistence(timeout: 20))
        // Allow native sheet transitions and image decoding to settle before taking evidence.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "v3-" + variant
        attachment.lifetime = .keepAlways
        add(attachment)
        // Element frames for the weighted geometry checklist (paper-ui-spec.md), evidence only.
        let frames = XCTAttachment(string: app.debugDescription)
        frames.name = "v3-" + variant + "-hierarchy"
        frames.lifetime = .keepAlways
        add(frames)
    }

    func testPersonalLibraryCountIsUnchanged() {
        func personalCount() -> String {
            app.terminate()
            app.launchEnvironment = [:]
            app.launchArguments = ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
            app.launch()
            XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 20))
            let count = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+ mục")).firstMatch
            XCTAssertTrue(count.waitForExistence(timeout: 20))
            return count.label
        }
        let before = personalCount()
        for variant in ["library", "collections", "capture"] {
            app.terminate()
            capture(variant) { variant == "capture" ? $0.textViews["captureBody"] : $0.buttons["libraryTab"] }
        }
        XCTAssertEqual(personalCount(), before, "Fixture launches must preserve the personal library count")
    }

    func testLibrary() {
        capture("library") { $0.staticTexts["Một góc yên tĩnh"].firstMatch }
        XCTAssertTrue(app.staticTexts["Ý tưởng cuối tuần"].firstMatch.exists)
    }

    func testCollections() {
        capture("collections") { $0.buttons["collectionCreate"] }
        for title in ["Cảm hứng", "Đọc sau", "Góc riêng", "Chuyến đi"] {
            XCTAssertTrue(app.staticTexts[title].firstMatch.exists)
        }
    }

    func testCollectionLifecycleAndOptions() {
        capture("collections") { $0.buttons["collectionCreate"] }
        app.buttons["collectionsOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        XCTAssertTrue(app.buttons["backupExport"].waitForExistence(timeout: 10))
        app.buttons["Xong"].tap()
        app.buttons["collectionsOptions"].tap()
        app.buttons["Thùng rác"].tap()
        XCTAssertTrue(app.navigationBars["Thùng rác"].waitForExistence(timeout: 10))
        app.buttons["Xong"].tap()
        app.buttons["collectionCreate"].tap()
        let alert = app.alerts["Bộ sưu tập mới"]
        alert.textFields.firstMatch.tap()
        alert.textFields.firstMatch.typeText("AAA Test")
        // Native alert repositions after keyboard input; wait for its frame to settle.
        Thread.sleep(forTimeInterval: 0.6)
        alert.buttons["Tạo"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        let row = app.staticTexts["AAA Test"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["AAA Test"].waitForExistence(timeout: 10))
        app.navigationBars["AAA Test"].buttons.firstMatch.tap()
        row.press(forDuration: 1.2)
        app.buttons["Đổi tên"].tap()
        let rename = app.alerts["Đổi tên"]
        rename.textFields.firstMatch.tap()
        rename.textFields.firstMatch.typeText(" renamed")
        Thread.sleep(forTimeInterval: 0.6)
        rename.buttons["Lưu"].tap()
        XCTAssertTrue(rename.waitForNonExistence(timeout: 5))
        let renamed = app.staticTexts["AAA Test renamed"].firstMatch
        XCTAssertTrue(renamed.waitForExistence(timeout: 10))
        renamed.press(forDuration: 1.2)
        app.buttons["Xóa bộ sưu tập"].tap()
        let confirm = app.buttons["Xóa bộ sưu tập"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(renamed.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Cảm hứng"].firstMatch.exists)
    }

    func testCapture() {
        capture("capture") { $0.textViews["captureBody"] }
        XCTAssertTrue((app.textViews["captureBody"].value as? String)?.contains("Đi Đà Lạt") == true)
    }
}
