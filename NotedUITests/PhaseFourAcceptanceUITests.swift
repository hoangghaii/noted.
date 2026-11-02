import XCTest

/// Uses a DEBUG-only isolated library. Never mutates the personal library or shared queue.
final class PhaseFourAcceptanceUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "dev.nguyenhoanghai861.Noted")
    private let noteID = "00000000-0000-0000-0000-000000000001"
    private let imageID = "00000000-0000-0000-0000-000000000002"
    private let brokenID = "00000000-0000-0000-0000-000000000003"
    private let linkID = "00000000-0000-0000-0000-000000000004"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = []
        app.launchEnvironment = ["NOTED_PHASE4_RUN": UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
    }

    override func tearDownWithError() throws {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if testRun?.failureCount ?? 0 > 0 {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Phase 4 accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    private func item(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "item_" + id).firstMatch
    }

    private func filter(_ title: String) {
        let button = app.buttons[title].firstMatch
        let filters = app.scrollViews["libraryFilters"]
        for _ in 0..<5 {
            if button.exists && button.isHittable { break }
            filters.swipeLeft()
        }
        XCTAssertTrue(button.isHittable, "Filter must be reachable: " + title)
        button.tap()
    }

    private func scrollTo(_ element: XCUIElement, maximumSwipes: Int = 24) {
        let scroll = app.scrollViews["libraryScroll"]
        for _ in 0..<maximumSwipes {
            if element.exists && element.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Expected element was not reachable after scrolling")
    }

    private func openEditor(_ id: String) {
        XCTAssertTrue(item(id).waitForExistence(timeout: 10))
        item(id).tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemEdit"].tap()
        XCTAssertTrue(app.textFields["editTitle"].waitForExistence(timeout: 10))
    }

    private func revealEditor(_ element: XCUIElement, upwards: Bool) {
        let form = app.descendants(matching: .any).matching(identifier: "itemEditorForm").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 10))
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            if upwards { form.swipeUp() } else { form.swipeDown() }
        }
        XCTAssertTrue(element.isHittable, "Editor control must be reachable")
    }

    private func openTrash() {
        app.buttons["libraryOptions"].tap()
        app.buttons["Thùng rác"].tap()
        XCTAssertTrue(app.navigationBars["Thùng rác"].waitForExistence(timeout: 10))
    }

    private func attachScreen(_ title: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPhaseFiveVisualSurfaces() throws {
        XCTAssertTrue(app.staticTexts["P4 note 00"].waitForExistence(timeout: 10))
        attachScreen("01 Library")

        app.buttons["searchTab"].tap()
        XCTAssertTrue(app.textFields["searchQuery"].waitForExistence(timeout: 10))
        attachScreen("02 Search")

        app.buttons["collectionsTab"].tap()
        XCTAssertTrue(app.buttons["collectionCreate"].waitForExistence(timeout: 10))
        attachScreen("03 Collections")
        app.descendants(matching: .any)["collection_00000000-0000-0000-0000-000000000005"].tap()
        let collectionBack = app.navigationBars["P4 collection"].buttons.firstMatch
        XCTAssertTrue(collectionBack.waitForExistence(timeout: 10), "Collection must offer a back control")
        attachScreen("03a Collection detail")
        collectionBack.tap()

        app.buttons["libraryTab"].tap()
        item(noteID).tap()
        XCTAssertTrue(app.descendants(matching: .any)["itemDetail"].waitForExistence(timeout: 10))
        attachScreen("04 Note detail")
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemEdit"].tap()
        XCTAssertTrue(app.textFields["editTitle"].waitForExistence(timeout: 10))
        attachScreen("05 Note editor")
        app.buttons["Đóng"].tap()
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["captureAdd"].tap()
        XCTAssertTrue(app.textViews["captureBody"].waitForExistence(timeout: 10))
        attachScreen("06 Capture note")
        app.segmentedControls.buttons["Link"].tap()
        XCTAssertTrue(app.textFields["captureURL"].waitForExistence(timeout: 10))
        attachScreen("07 Capture link")
        app.segmentedControls.buttons["Ảnh"].tap()
        XCTAssertTrue(app.buttons["capturePhotos"].waitForExistence(timeout: 10))
        attachScreen("08 Capture image")
        app.buttons["Đóng"].tap()

        openTrash()
        XCTAssertTrue(app.staticTexts["Thùng rác trống"].waitForExistence(timeout: 10))
        attachScreen("09 Empty trash")
        app.buttons["Xong"].tap()

        app.buttons["libraryOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        XCTAssertTrue(app.buttons["backupExport"].waitForExistence(timeout: 10))
        attachScreen("10 Data and backup")
    }

    func testPhaseFiveHomeScreenIcon() throws {
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icons = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Noted.' OR label == 'Noted'"))
        func iconIsVisible() -> Bool {
            icons.allElementsBoundByIndex.contains { $0.isHittable }
        }
        // Leave App Library if that was the last Home destination.
        home.swipeRight()
        for _ in 0..<6 {
            if iconIsVisible() { break }
            home.swipeRight()
        }
        for _ in 0..<6 {
            if iconIsVisible() { break }
            home.swipeLeft()
        }
        XCTAssertTrue(iconIsVisible(), "Noted icon must be visible on a Home Screen page")
        attachScreen("00 Home Screen icon")
        app.activate()
    }

    func testCapturePinsSavedNoteOnce() throws {
        app.buttons["captureAdd"].tap()
        let body = app.textViews["captureBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        body.typeText("Ghim thử trên iPhone")
        let pin = app.switches["capturePinAfterSave"]
        XCTAssertTrue(pin.exists)
        pin.tap()
        app.buttons["captureSave"].tap()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 10))
        filter("Đã ghim")
        XCTAssertTrue(app.staticTexts["Ghim thử trên iPhone"].waitForExistence(timeout: 10))
    }

    func testPaginationFiltersOrderingAndPinAfterRelaunch() throws {
        filter("Ghi chú")
        let first = app.staticTexts["P4 note 00"].firstMatch
        let second = app.staticTexts["P4 note 01"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(second.exists)
        XCTAssertTrue(first.frame.minY < second.frame.minY || (abs(first.frame.minY - second.frame.minY) < 1 && first.frame.minX < second.frame.minX), "Newest note must precede the next note in grid order")
        let more = app.buttons["libraryLoadMore"]
        let scroll = app.scrollViews["libraryScroll"]
        for _ in 0..<24 {
            if more.exists && more.frame.minY >= scroll.frame.minY && more.frame.maxY <= 750 { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(more.exists && more.frame.minY >= scroll.frame.minY && more.frame.maxY <= 750,
                      "Load more must be visible above the destination bar")
        XCTAssertFalse(app.staticTexts["P4 note 53"].exists, "Last page must wait for pagination")
        more.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let last = app.staticTexts["P4 note 53"].firstMatch
        scrollTo(last, maximumSwipes: 10)
        last.tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["Ghim"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
        XCTAssertTrue(last.waitForExistence(timeout: 10), "Pinned old note must be promoted into the first page after relaunch")
        filter("Đã ghim")
        XCTAssertTrue(last.exists)
        XCTAssertFalse(app.staticTexts["P4 note 00"].exists)
        app.terminate()
        app.launch()
        filter("Ảnh")
        XCTAssertTrue(item(imageID).waitForExistence(timeout: 10))
        XCTAssertTrue(item(brokenID).exists)
        XCTAssertFalse(item(noteID).exists)
        filter("Link")
        XCTAssertTrue(item(linkID).waitForExistence(timeout: 10))
        XCTAssertFalse(item(imageID).exists)
    }

    func testEditorRetainsDraftAfterSaveFailureAndForegroundImport() throws {
        filter("Ghi chú")
        openEditor(noteID)
        let title = app.textFields["editTitle"]
        let body = app.textViews["editBody"]
        title.tap()
        title.typeText(" edited")
        body.tap()
        body.typeText(" body edit")
        // A tap outside the fields dismisses the shared keyboard without leaving the editor.
        app.navigationBars["Chỉnh sửa"].staticTexts["Chỉnh sửa"].tap()
        let expectedTitle = try XCTUnwrap(title.value as? String)
        let expectedBody = try XCTUnwrap(body.value as? String)
        let tags = app.textFields["editTags"]
        revealEditor(tags, upwards: true)
        tags.tap()
        tags.typeText("p4tag")
        revealEditor(app.buttons["editCollection"], upwards: true)
        app.buttons["editCollection"].tap()
        app.buttons["P4 collection"].tap()
        let fail = app.buttons["fixtureFailSave"]
        revealEditor(fail, upwards: true)
        fail.tap()
        app.buttons["editSave"].tap()
        let alert = app.alerts["Chưa lưu được"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["Đóng"].tap()
        revealEditor(title, upwards: false)
        XCTAssertEqual(title.value as? String, expectedTitle)
        revealEditor(body, upwards: true)
        XCTAssertEqual(body.value as? String, expectedBody)
        let incoming = app.buttons["fixtureStageIncoming"]
        revealEditor(incoming, upwards: true)
        incoming.tap()
        XCTAssertEqual(app.staticTexts["fixtureImportCount"].label, "57")
        XCUIDevice.shared.press(.home)
        app.activate()
        let count = app.staticTexts["fixtureImportCount"]
        expectation(for: NSPredicate(format: "label == '58'"), evaluatedWith: count)
        waitForExpectations(timeout: 20)
        revealEditor(title, upwards: false)
        XCTAssertEqual(title.value as? String, expectedTitle)
        revealEditor(body, upwards: true)
        XCTAssertEqual(body.value as? String, expectedBody)
        revealEditor(tags, upwards: true)
        XCTAssertEqual(tags.value as? String, "p4tag")
        app.buttons["editSave"].tap()
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        filter("Ghi chú")
        openEditor(noteID)
        XCTAssertEqual(title.value as? String, expectedTitle)
        revealEditor(body, upwards: true)
        XCTAssertEqual(body.value as? String, expectedBody)
        revealEditor(tags, upwards: true)
        XCTAssertEqual(tags.value as? String, "p4tag")
        let collection = app.buttons["editCollection"]
        revealEditor(collection, upwards: true)
        XCTAssertTrue(collection.label.contains("P4 collection") || (collection.value as? String)?.contains("P4 collection") == true)
    }

    func testTrashExcludesLibraryAndSearchThenRestoreAndConfirmPermanentDelete() throws {
        filter("Ghi chú")
        item(noteID).tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemTrash"].tap()
        app.buttons["Chuyển vào Thùng rác"].tap()
        XCTAssertFalse(item(noteID).exists)
        app.buttons["searchTab"].tap()
        let query = app.textFields["searchQuery"]
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        query.tap()
        query.typeText("P4 note 00")
        XCTAssertTrue(app.staticTexts["Chưa tìm thấy"].waitForExistence(timeout: 10))
        app.buttons["libraryTab"].tap()
        openTrash()
        let row = app.descendants(matching: .any).matching(identifier: "trashItem_" + noteID).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.buttons["trashRestore"].tap()
        XCTAssertFalse(row.exists)
        app.buttons["Xong"].tap()
        XCTAssertTrue(item(noteID).waitForExistence(timeout: 10))
        item(noteID).tap()
        app.buttons["Tùy chọn nội dung"].tap()
        app.buttons["itemTrash"].tap()
        app.buttons["Chuyển vào Thùng rác"].tap()
        openTrash()
        app.buttons["trashDelete"].tap()
        XCTAssertTrue(app.staticTexts["Xóa vĩnh viễn mục này?"].waitForExistence(timeout: 10))
        attachScreen("14 Trash confirmation")
        let cancel = app.buttons["trashConfirmCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(app.descendants(matching: .any)["trashConfirmDialog"].exists)
        XCTAssertTrue(row.exists, "Cancelling confirmation must preserve the item")
        app.buttons["trashDelete"].tap()
        app.buttons["trashConfirmDelete"].tap()
        XCTAssertTrue(app.staticTexts["Thùng rác trống"].waitForExistence(timeout: 10))
        app.buttons["Xong"].tap()
        app.terminate()
        app.launch()
        filter("Ghi chú")
        XCTAssertFalse(item(noteID).exists)
    }

    func testImageFallbackOriginalShareAndExplicitLinkOpening() throws {
        filter("Ảnh")
        XCTAssertTrue(item(brokenID).waitForExistence(timeout: 10))
        item(brokenID).tap()
        XCTAssertTrue(app.staticTexts["Không đọc được ảnh. Bản gốc vẫn được giữ."].waitForExistence(timeout: 15))
        app.terminate()
        app.launch()
        filter("Ảnh")
        item(imageID).tap()
        XCTAssertTrue(app.images["Ảnh đã lưu"].waitForExistence(timeout: 15))
        let share = app.buttons["detailShareOriginal"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(app.staticTexts["Lưu hình ảnh"].waitForExistence(timeout: 10), "System share sheet must offer the original image")
        let sheet = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sheet.name = "Original image system share sheet"
        sheet.lifetime = .keepAlways
        add(sheet)
        app.terminate()
        app.launch()
        filter("Link")
        item(linkID).tap()
        XCTAssertEqual(app.state, .runningForeground, "Opening detail must not automatically open the external URL")
        let open = app.descendants(matching: .any).matching(identifier: "detailOpenURL").firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        expectation(for: NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue), evaluatedWith: safari)
        waitForExpectations(timeout: 15)
        app.activate()
    }

    func testEmptyLibraryAndAddNoteWithKeyboard() throws {
        app.terminate()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchEnvironment["NOTED_PHASE4_EMPTY"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["Chỗ cho những điều muốn giữ"].waitForExistence(timeout: 20))
        app.buttons["captureAdd"].tap()
        app.segmentedControls.buttons["Ghi chú"].tap()
        let body = app.textViews["captureBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        body.typeText("P4 new empty library note")
        app.segmentedControls.buttons["Link"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "Tapping outside the note editor should dismiss the keyboard")
        app.segmentedControls.buttons["Ghi chú"].tap()
        app.buttons["captureSave"].tap()
        XCTAssertTrue(app.staticTexts["P4 new empty library note"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["P4 new empty library note"].firstMatch.waitForExistence(timeout: 15))
    }
    func testPendingImportErrorCanRetryAndDiscardWithConfirmation() throws {
        app.terminate()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchEnvironment["NOTED_PHASE4_PENDING"] = "1"
        app.launch()
        let banner = app.buttons["Có nội dung đang chờ xử lý"]
        XCTAssertTrue(banner.waitForExistence(timeout: 20))
        banner.tap()
        let retry = app.buttons["Thử nhập lại"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.tap()
        let discard = app.buttons["Bỏ lượt lưu này"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.tap()
        XCTAssertTrue(app.staticTexts["Bỏ lượt lưu đang chờ?"].waitForExistence(timeout: 10))
        app.sheets.buttons["Bỏ lượt lưu"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: banner)
        waitForExpectations(timeout: 10)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
        XCTAssertFalse(banner.exists, "Discarded pending capture must not reappear after relaunch")
    }

}
