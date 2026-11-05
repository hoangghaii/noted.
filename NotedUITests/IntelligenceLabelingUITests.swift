import XCTest

final class IntelligenceLabelingUITests: XCTestCase {
    func testLinkDigestCardsAndDetails() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchArguments = ["--link-digest-ui-fixtures"]
        app.launch()
        let summary = app.staticTexts["cardLinkSummary_00000000-0000-0000-0000-000000000004"]
        XCTAssertTrue(summary.waitForExistence(timeout: 20))
        summary.tap()
        XCTAssertTrue(app.staticTexts["detailLinkSummary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Trích từ trang"].exists)
        XCTAssertTrue(app.buttons["detailRetryLink"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Link digest detail synthetic"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["P4 login wall"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Không đọc được nội dung (cần đăng nhập)"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Thêm ghi chú"].exists)
    }

    func testLinkDigestWithAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchArguments = ["--link-digest-ui-fixtures", "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let summary = app.staticTexts["cardLinkSummary_00000000-0000-0000-0000-000000000004"]
        for _ in 0..<10 {
            if summary.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(summary.isHittable)
        XCTAssertEqual(summary.label, "Tưới cây vừa đủ và đặt cây gần cửa sổ có ánh sáng dịu.")
        app.swipeUp()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Link digest accessibility text synthetic"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let summaryLabel = summary.label
        summary.tap()
        let detail = app.staticTexts["detailLinkSummary"]
        for _ in 0..<8 {
            if detail.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(detail.isHittable)
        XCTAssertEqual(detail.label, summaryLabel)
    }

    func testLinkDigestAppearsInLabelingSheet() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchArguments = ["--link-digest-ui-fixtures", "--link-digest-labeling-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 20))
        app.buttons["libraryOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        app.buttons["intelligenceLabeling"].tap()
        let summary = app.staticTexts["labelingLinkSummary"]
        for _ in 0..<8 {
            if summary.exists && summary.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(summary.isHittable)
        XCTAssertEqual(summary.label, "Tưới cây vừa đủ và đặt cây gần cửa sổ có ánh sáng dịu.")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Link digest labeling synthetic"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDebugLabelingScreenShowsLocalLibraryCounts() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 20))
        app.buttons["libraryOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        let link = app.buttons["intelligenceLabeling"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.staticTexts["Thống kê thư viện"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Ảnh có OCR"].exists)
        XCTAssertTrue(app.staticTexts["Đã gán nhãn"].exists)
        let evaluate = app.buttons["intelligenceRunEvaluation"]
        XCTAssertTrue(evaluate.exists)
        evaluate.tap()
        // Wait for computation separately from locating rows in the lazy Form.
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: evaluate)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 180), .completed)
        let export = app.buttons["intelligenceExportReport"]
        for _ in 0..<5 {
            if export.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(export.isHittable)
        XCTAssertTrue(app.staticTexts["Chưa đủ nhãn để kết luận chất lượng."].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "DEBUG topic labeling on simulator"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
