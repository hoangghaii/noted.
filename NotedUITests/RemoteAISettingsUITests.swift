import XCTest

final class RemoteAISettingsUITests: XCTestCase {
    func testSettingsDefaultOffAndConsentCanBeCancelled() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTED_PHASE4_RUN"] = UUID().uuidString
        app.launchArguments = ["--link-digest-ui-fixtures"]
        app.launch()
        XCTAssertTrue(app.buttons["libraryOptions"].waitForExistence(timeout: 20))
        app.buttons["libraryOptions"].tap()
        app.buttons["Dữ liệu & Backup"].tap()
        app.buttons["AI tùy chọn"].tap()
        let toggle = app.switches["remoteLinkToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Bật tóm tắt link bằng AI"].waitForExistence(timeout: 5))
        app.buttons["Hủy"].tap()
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        app.buttons["Bật tóm tắt link bằng AI"].tap()
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "AI settings default off synthetic"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
