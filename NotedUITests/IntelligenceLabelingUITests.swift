import XCTest

final class IntelligenceLabelingUITests: XCTestCase {
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
        XCTAssertTrue(app.buttons["intelligenceExportReport"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Chưa đủ nhãn để kết luận chất lượng."].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "DEBUG topic labeling on simulator"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
