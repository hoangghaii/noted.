import XCTest

final class ExternalShareUITests: XCTestCase {
    private let noted = XCUIApplication()
    private let source = XCUIApplication(bundleIdentifier: ExternalShareUITests.gateHostBundleID)
    // Runner ID is $(NOTED_BUNDLE_ID).UITests; the host is $(NOTED_BUNDLE_ID)GateHost.
    private static let gateHostBundleID = Bundle(for: ExternalShareUITests.self).bundleIdentifier!
        .replacingOccurrences(of: ".UITests", with: "") + "GateHost"
    private var runID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        runID = String(UUID().uuidString.prefix(8))
        noted.launchArguments = []
        noted.launch()
        XCTAssertTrue(noted.buttons["captureAdd"].waitForExistence(timeout: 20), "Main library must be ready before testing external capture.")
        source.launchEnvironment["NOTED_GATE_RUN_ID"] = runID
        source.launch()
        XCTAssertTrue(source.buttons["externalShareText"].waitForExistence(timeout: 15))
    }

    override func tearDownWithError() throws {
        // hasSucceeded is still false while tearDown runs; failureCount reflects real failures.
        if (testRun?.failureCount ?? 0) > 0 {
            screenshot("External Share failure")
            // The share service exits after the sheet closes; snapshotting a stopped app throws.
            for app in [source, noted, XCUIApplication(bundleIdentifier: "com.apple.UIKit.ShareUIService")] where app.state != .notRunning {
                let attachment = XCTAttachment(string: app.debugDescription)
                attachment.name = "Hierarchy " + app.label
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testExternalTextPersistsAfterRelaunch() throws {
        source.buttons["externalShareText"].tap()
        try saveThroughExtension()
        noted.activate()
        let marker = noted.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "NOTED EXTERNAL TEXT " + runID)).firstMatch
        XCTAssertTrue(marker.waitForExistence(timeout: 20), "External text did not enter the real SwiftData library.")
        screenshot("External text in library")
        noted.terminate()
        noted.launch()
        XCTAssertTrue(marker.waitForExistence(timeout: 20), "External text was lost after terminate/relaunch.")
        screenshot("External text survives relaunch")
    }

    func testExternalImagePersistsAfterRelaunch() throws {
        source.buttons["externalShareImage"].tap()
        try saveThroughExtension()
        noted.activate()
        XCTAssertTrue(noted.buttons["captureAdd"].waitForExistence(timeout: 20))
        let image = noted.images["Ảnh đã lưu"].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 20), "Original image was not decoded in the library.")
        image.tap()
        let marker = noted.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "NOTED EXTERNAL IMAGE " + runID)).firstMatch
        if !marker.waitForExistence(timeout: 5) { noted.swipeUp() }
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "Image detail must retain this run's accompanying caption.")
        screenshot("External PNG detail")
        noted.terminate()
        noted.launch()
        let reopenedImage = noted.images["Ảnh đã lưu"].firstMatch
        XCTAssertTrue(reopenedImage.waitForExistence(timeout: 20))
        reopenedImage.tap()
        if !marker.waitForExistence(timeout: 5) { noted.swipeUp() }
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "External PNG or caption was lost after terminate/relaunch.")
        screenshot("External PNG survives relaunch")
    }

    private func saveThroughExtension() throws {
        let service = XCUIApplication(bundleIdentifier: "com.apple.UIKit.ShareUIService")
        let chooser = service.state == .notRunning ? source : service
        let destination = chooser.descendants(matching: .any).matching(NSPredicate(format:
            "label == 'Noted.' OR label == 'Copy to Noted.' OR label == 'Sao chép vào Noted.'")).firstMatch
        let more = chooser.cells.matching(identifier: "shareCell")
            .matching(NSPredicate(format: "label == 'More' OR label == 'Thêm'")).firstMatch
        let activityCollection = chooser.collectionViews["activityCollectionView"]
        XCTAssertTrue(activityCollection.waitForExistence(timeout: 10))
        let appRow = activityCollection.scrollViews.firstMatch
        XCTAssertTrue(appRow.exists, "Share app row unavailable.")
        for _ in 0..<8 {
            if destination.exists && destination.isHittable { break }
            if more.exists && more.isHittable { more.tap(); break }
            let y = min(0.9, max(0.1, appRow.frame.midY / chooser.frame.height))
            chooser.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: y))
                .press(forDuration: 0.05, thenDragTo: chooser.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: y)))
        }
        if !destination.exists || !destination.isHittable {
            let list = chooser.tables["tableView"]
            if list.exists {
                for _ in 0..<8 {
                    if destination.exists && destination.isHittable { break }
                    list.swipeUp()
                }
            }
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 10), "Noted is absent from the external app's Share picker.")
        destination.tap()
        let save = chooser.buttons["shareSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        XCTAssertTrue(chooser.staticTexts["Đã lưu trên iPhone"].waitForExistence(timeout: 20), "Extension did not confirm durable save.")
        screenshot("External Share confirmed")
        save.tap()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
