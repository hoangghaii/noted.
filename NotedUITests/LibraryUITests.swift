import XCTest

final class LibraryUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = []
        app.launch()
    }

    override func tearDownWithError() throws {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Noted library device UI"
        attachment.lifetime = .keepAlways
        add(attachment)
        if testRun?.failureCount ?? 0 > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Library hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }

    func testCreateNoteSearchAndRelaunch() throws {
        let marker = "NOTED UI " + UUID().uuidString.prefix(8) + " Ca phe Da Nang"
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
        app.buttons["captureAdd"].tap()
        app.buttons["captureMode_note"].tap()
        let body = app.textViews["captureBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        body.typeText(marker)
        app.buttons["captureSave"].tap()
        let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        app.terminate()
        app.launch()
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        app.buttons["searchTab"].tap()
        let search = app.textFields["searchQuery"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(marker)
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Note found after relaunch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testEditDraftSurvivesRelaunchAndCanBeSaved() throws {
        let marker = "PHASE4 " + UUID().uuidString.prefix(8)
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
        app.buttons["captureAdd"].tap()
        app.buttons["captureMode_note"].tap()
        let body = app.textViews["captureBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        body.typeText(marker)
        app.buttons["captureSave"].tap()
        let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemEdit"].tap()
        let title = app.textFields["editTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let savedTitle = try XCTUnwrap(title.value as? String) + " Draft"
        title.tap()
        title.typeText(" Draft")
        app.buttons["Đóng"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemEdit"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, savedTitle)
        app.buttons["editSave"].tap()
        XCTAssertTrue(app.staticTexts[savedTitle].waitForExistence(timeout: 10))
    }

    func testBackupLocalFilesPicker() throws {
        XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 15))
        app.buttons["libraryOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        XCTAssertTrue(app.buttons["backupExport"].waitForExistence(timeout: 10))
        app.buttons["backupExport"].tap()
        let picker = XCTAttachment(string: app.debugDescription)
        picker.name = "Files export picker hierarchy"
        picker.lifetime = .keepAlways
        add(picker)
        let local = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'On My iPhone' OR label == 'Trên iPhone' OR label == 'Trên iPhone của tôi'")).firstMatch
        if !local.exists {
            let browse = app.buttons.matching(NSPredicate(format: "label == 'Browse' OR label == 'Duyệt'")).firstMatch
            if browse.waitForExistence(timeout: 10) { browse.tap() }
        }
        XCTAssertTrue(local.waitForExistence(timeout: 10), "Only a local Files location is allowed for this test.")
        local.tap()
        let save = app.buttons.matching(NSPredicate(format: "label == 'Save' OR label == 'Lưu' OR label == 'Move' OR label == 'Di chuyển'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        // On iOS 27 the picker can drop a Save tap while it is still navigating to the local folder.
        // A successful Save dismisses the picker, so tapping again only while it is still shown cannot export twice.
        let result = app.staticTexts["backupResult"]
        for _ in 0..<3 where !result.exists {
            let enabled = expectation(for: NSPredicate(format: "isEnabled == true AND isHittable == true"), evaluatedWith: save)
            wait(for: [enabled], timeout: 10)
            save.tap()
            if result.waitForExistence(timeout: 8) || !save.exists { break }
        }
        // "Kết quả" is the last List section; on a 844 pt screen it renders only after scrolling.
        for _ in 0..<4 where !result.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        XCTAssertTrue(result.label.hasPrefix("Đã xuất"), result.label)
        let fileName = try XCTUnwrap(result.label.split(whereSeparator: \.isWhitespace)
            .first(where: { $0.hasSuffix(".notedbackup") }).map(String.init))
        let stem = String(fileName.dropLast(".notedbackup".count))
        app.buttons["backupImport"].tap()
        // Match a Files document cell, never the export-result text underneath the sheet.
        let backup = app.cells.matching(NSPredicate(format: "label CONTAINS %@", stem)).firstMatch
        XCTAssertTrue(backup.waitForExistence(timeout: 15), "Exported local package not visible in Files picker.")
        backup.tap()
        let opened = app.buttons.matching(NSPredicate(format: "label == 'Open' OR label == 'Mở'")).firstMatch
        if opened.waitForExistence(timeout: 3) { opened.tap() }
        let restored = app.staticTexts["backupResult"]
        let merged = NSPredicate(format: "label BEGINSWITH 'Đã nhập'")
        expectation(for: merged, evaluatedWith: restored)
        waitForExpectations(timeout: 20)
        XCTAssertTrue(restored.label.contains("Đã nhập 0 mục"), "Same unchanged library should skip existing items: " + restored.label)
    }
}
