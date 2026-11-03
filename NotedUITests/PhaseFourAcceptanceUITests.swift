import XCTest

/// Uses a DEBUG-only isolated library. Never mutates the personal library or shared queue.
final class PhaseFourAcceptanceUITests: XCTestCase {
    private let app = XCUIApplication()
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

    /// `isHittable` raises "Activation point invalid" (instead of returning false) for an
    /// element whose frame lies entirely off screen, e.g. a scrolled-out filter pill on the
    /// simulator. Only ask once the element's centre is inside the window and not under the keyboard.
    private func reachable(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        let centre = CGPoint(x: element.frame.midX, y: element.frame.midY)
        guard app.windows.firstMatch.frame.contains(centre) else { return false }
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists, keyboard.frame.contains(centre) { return false }
        return element.isHittable
    }

    private func filter(_ title: String) {
        let button = app.buttons[title].firstMatch
        let filters = app.scrollViews["libraryFilters"]
        for _ in 0..<5 {
            if reachable(button) { break }
            filters.swipeLeft()
        }
        XCTAssertTrue(reachable(button), "Filter must be reachable: " + title)
        button.tap()
    }

    private func scrollTo(_ element: XCUIElement, maximumSwipes: Int = 24) {
        let scroll = app.scrollViews["libraryScroll"]
        for _ in 0..<maximumSwipes {
            if reachable(element) { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(reachable(element), "Expected element was not reachable after scrolling")
    }

    /// The software keyboard (always shown on the simulator) can cover lower editor rows,
    /// and swiping the form does not dismiss it. Tap the navigation title to dismiss, as the
    /// test already does after typing title/body.
    private func dismissKeyboardIfShown() {
        guard app.keyboards.firstMatch.exists else { return }
        app.navigationBars["Chỉnh sửa"].staticTexts["Chỉnh sửa"].tap()
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
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
            if reachable(element) { return }
            dismissKeyboardIfShown()
            if reachable(element) { return }
            if upwards { form.swipeUp() } else { form.swipeDown() }
        }
        XCTAssertTrue(reachable(element), "Editor control must be reachable")
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
        app.buttons["captureMode_link"].tap()
        XCTAssertTrue(app.textFields["captureURL"].waitForExistence(timeout: 10))
        attachScreen("07 Capture link")
        app.buttons["captureMode_photo"].tap()
        XCTAssertTrue(app.buttons["capturePhotos"].waitForExistence(timeout: 10))
        attachScreen("08 Capture image")
        app.buttons["captureClose"].tap()

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
        // "Tùy chọn khác" sits at the bottom edge, under the keyboard and the pinned save bar.
        // Dismiss the keyboard (tap the sheet title) and scroll until the header clears the save bar.
        app.staticTexts["Lưu nhanh"].firstMatch.tap()
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
        let more = app.buttons["captureMoreOptions"]
        let saveBar = app.buttons["captureSave"]
        let form = app.scrollViews.containing(.textView, identifier: "captureBody").firstMatch
        for _ in 0..<4 where !(reachable(more) && more.frame.maxY < saveBar.frame.minY) { form.swipeUp() }
        XCTAssertTrue(reachable(more) && more.frame.maxY < saveBar.frame.minY, "Tùy chọn khác must clear the save bar")
        more.tap()
        let pin = app.switches["capturePinAfterSave"]
        // "Tùy chọn khác" expands with an animation; wait instead of reading existence immediately.
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        // The options open below the fold; a tap behind the pinned save bar would save instead of toggling.
        let clearOfSave = { self.reachable(pin) && pin.frame.maxY < saveBar.frame.minY }
        for _ in 0..<4 where !clearOfSave() { form.swipeUp() }
        XCTAssertTrue(clearOfSave(), "Pin switch must be above the save bar before tapping")
        // The switch element spans the whole labelled row; a centre tap lands on the label,
        // which does not toggle on iOS 18. Tap the switch side and confirm it turned on.
        let knob = pin.switches.firstMatch
        (knob.exists ? knob : pin).tap()
        // The value updates asynchronously and arrives as a number or string by runtime.
        let on = NSPredicate { element, _ in "\((element as? XCUIElement)?.value ?? "")" == "1" }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: on, evaluatedWith: pin)], timeout: 3), .completed,
                       "Pin-after-save must be on before saving")
        app.buttons["captureSave"].tap()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 10))
        filter("Đã ghim")
        XCTAssertTrue(app.staticTexts["Ghim thử trên iPhone"].waitForExistence(timeout: 10))
    }

    func testCaptureDraftAndMetadataSurviveRelaunch() throws {
        let titleText = "P7 capture " + UUID().uuidString.prefix(8)
        let bodyText = "Nội dung Phase 7"
        app.buttons["captureAdd"].tap()
        let title = app.textFields["captureTitle"]
        let body = app.textViews["captureBody"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText(titleText)
        body.tap()
        body.typeText(bodyText)
        app.buttons["captureClose"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["captureAdd"].waitForExistence(timeout: 20))
        app.buttons["captureAdd"].tap()
        XCTAssertEqual(title.value as? String, titleText)
        XCTAssertEqual(body.value as? String, bodyText)

        let form = app.scrollViews.containing(.textView, identifier: "captureBody").firstMatch
        let collection = app.buttons["captureCollection"]
        for _ in 0..<6 where !reachable(collection) { form.swipeUp() }
        XCTAssertTrue(reachable(collection))
        collection.tap()
        app.buttons["P4 collection"].tap()
        let tags = app.textFields["captureTags"]
        for _ in 0..<6 where !reachable(tags) { form.swipeUp() }
        XCTAssertTrue(reachable(tags))
        tags.tap()
        tags.typeText("p7tag,")
        let save = app.buttons["captureSave"]
        XCTAssertTrue(save.isHittable, "Save must remain reachable with the keyboard shown")
        save.tap()
        let note = app.staticTexts[titleText].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        XCTAssertTrue(app.staticTexts[bodyText].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["#p7tag"].exists)
        XCTAssertTrue(app.staticTexts["P4 collection"].exists)
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
        // The count row sits below the stage button and may be off-screen (lazy List) on taller layouts.
        let count = app.staticTexts["fixtureImportCount"]
        revealEditor(count, upwards: true)
        XCTAssertEqual(count.label, "57")
        XCUIDevice.shared.press(.home)
        app.activate()
        revealEditor(count, upwards: true)
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
        // Tapping while the confirmation sheet is still animating in dismisses it without
        // trashing; then the tab tap is swallowed by the closing sheet. Wait for each state.
        let confirm = app.buttons["Chuyển vào Thùng rác"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        XCTAssertTrue(app.scrollViews["itemDetail"].waitForNonExistence(timeout: 10), "Detail must close after trashing")
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
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isHittable)
        Thread.sleep(forTimeInterval: 0.6)
        confirm.tap()
        XCTAssertTrue(app.scrollViews["itemDetail"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 10))
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
        app.buttons["captureMode_note"].tap()
        let body = app.textViews["captureBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        body.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        body.typeText("P4 new empty library note")
        app.buttons["captureMode_link"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "Tapping outside the note editor should dismiss the keyboard")
        app.buttons["captureMode_note"].tap()
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
