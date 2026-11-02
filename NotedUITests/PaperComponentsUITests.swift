import XCTest

final class PaperComponentsUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if testRun?.failureCount ?? 0 > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    private func launch(_ variant: String, large: Bool = false) {
        app.launchEnvironment = ["NOTED_MOCK_FIXTURE": variant, "NOTED_MOCK_RUN": UUID().uuidString]
        app.launchArguments = ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN",
                               "-UIPreferredContentSizeCategoryName",
                               large ? "UICTContentSizeCategoryXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
    }

    private func assertEqualPills(_ ids: [String], container: XCUIElement) {
        let pills = ids.map { app.buttons[$0] }
        XCTAssertTrue(pills[0].waitForExistence(timeout: 20))
        let frames = pills.map(\.frame)
        for (pill, frame) in zip(pills, frames) {
            XCTAssertTrue(pill.isHittable)
            XCTAssertEqual(frame.width, frames[0].width, accuracy: 1)
            XCTAssertGreaterThanOrEqual(frame.height, 44)
        }
        for index in 1..<frames.count {
            XCTAssertEqual(frames[index].minX - frames[index - 1].maxX, 8, accuracy: 1)
        }
        XCTAssertEqual(frames.last!.maxX - frames[0].minX, container.frame.width, accuracy: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLibraryFilterWidthsAndTabs() {
        launch("library")
        assertEqualPills(["all", "inbox", "images", "links"].map { "libraryFilter_" + $0 },
                         container: app.scrollViews["libraryFilters"])
        app.scrollViews["libraryFilters"].swipeLeft()
        XCTAssertTrue(app.buttons["libraryFilter_pinned"].isHittable)
        app.buttons["libraryFilter_pinned"].tap()
        XCTAssertTrue(app.buttons["libraryFilter_pinned"].isSelected)
        app.buttons["searchTab"].tap()
        XCTAssertTrue(app.buttons["searchTab"].isSelected)
        app.buttons["collectionsTab"].tap()
        XCTAssertTrue(app.buttons["collectionCreate"].waitForExistence(timeout: 10))
        app.buttons["libraryTab"].tap()
        XCTAssertTrue(app.buttons["libraryTab"].isSelected)
    }

    func testCaptureModeWidths() {
        launch("capture")
        assertEqualPills(["note", "link", "photo"].map { "captureMode_" + $0 },
                         container: app.otherElements["captureMode"])
        app.buttons["captureMode_link"].tap()
        XCTAssertTrue(app.buttons["captureMode_link"].isSelected)
    }

    func testLargeTypeFilterWidths() {
        launch("library", large: true)
        assertEqualPills(["all", "inbox", "images", "links"].map { "libraryFilter_" + $0 },
                         container: app.scrollViews["libraryFilters"])
        app.scrollViews["libraryFilters"].swipeLeft()
        let pinned = app.buttons["libraryFilter_pinned"]
        XCTAssertTrue(pinned.isHittable)
        XCTAssertEqual(pinned.label, "Đã ghim")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLargeTypeCaptureWidths() {
        launch("capture", large: true)
        assertEqualPills(["note", "link", "photo"].map { "captureMode_" + $0 },
                         container: app.otherElements["captureMode"])
    }
    func testPaperRowsDateAndCardMenu() {
        launch("library")
        let noteID = "00000000-0000-0000-0000-000000000001"
        let ideaID = "00000000-0000-0000-0000-000000000037"
        let note = app.buttons["item_" + noteID]
        let idea = app.buttons["item_" + ideaID]
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        XCTAssertEqual(note.frame.minY, idea.frame.minY, accuracy: 1)
        XCTAssertEqual(note.frame.height, idea.frame.height, accuracy: 1)
        XCTAssertTrue(app.staticTexts["12 thg 4, 2024"].exists)
        app.buttons["itemMenu_" + noteID].tap()
        XCTAssertTrue(app.buttons["Ghim"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["itemDetail"].exists)
        app.buttons["Ghim"].tap()
        app.buttons["itemMenu_" + noteID].tap()
        XCTAssertTrue(app.buttons["Bỏ ghim"].waitForExistence(timeout: 5))
        app.buttons["Bỏ ghim"].tap()
        app.buttons["itemMenu_" + noteID].tap()
        app.buttons["Chuyển vào Thùng rác"].tap()
        XCTAssertFalse(note.exists)
        app.buttons["searchTab"].tap()
        let query = app.textFields["searchQuery"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.tap()
        query.typeText("Một góc yên tĩnh")
        XCTAssertTrue(app.staticTexts["Chưa tìm thấy"].waitForExistence(timeout: 10))
    }

    func testSearchPaperFiltersAndDetail() {
        launch("library")
        app.buttons["searchTab"].tap()
        XCTAssertTrue(app.textFields["searchQuery"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Phase 5 Search"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let kinds = ["all", "text", "image", "link"].map { app.buttons["searchKind_" + $0] }
        for pill in kinds { XCTAssertEqual(pill.frame.width, kinds[0].frame.width, accuracy: 1) }
        app.buttons["searchKind_link"].tap()
        XCTAssertTrue(app.staticTexts["Sống chậm một chút"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Một góc yên tĩnh"].exists)
        app.buttons["searchPeriod_today"].tap()
        XCTAssertTrue(app.staticTexts["Chưa có mục phù hợp"].waitForExistence(timeout: 5))
        app.buttons["searchClearFilters"].tap()
        app.buttons["searchCollection_00000000-0000-0000-0000-000000000103"].tap()
        XCTAssertTrue(app.staticTexts["Ý tưởng cuối tuần"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Một góc yên tĩnh"].exists)
        app.staticTexts["Ý tưởng cuối tuần"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["itemDetail"].waitForExistence(timeout: 5))
    }

}
