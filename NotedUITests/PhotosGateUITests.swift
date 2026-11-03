import XCTest
import Vision

extension PhaseOneUITests {
    /// Adds one synthetic fixture using add-only permission, then shares that newest image
    /// from Photos. Does not delete assets or request library read permission.
    @objc func testPhotosImageShare() throws {
        let noted = XCUIApplication(bundleIdentifier: "dev.nhhai7.Noted")
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        defer {
            if testRun?.hasSucceeded == false {
                let hierarchy = XCTAttachment(string: photos.debugDescription)
                hierarchy.name = "Photos gate hierarchy"
                hierarchy.lifetime = .keepAlways
                add(hierarchy)
            }
        }

        let permissionHandler = addUIInterruptionMonitor(withDescription: "Add synthetic image only") { alert in
            let allow = alert.buttons.matching(NSPredicate(format:
                "label == 'Allow Photos to Be Added' OR label == 'Allow Adding Photos' OR label == 'Allow' OR label == 'OK' OR label == 'Cho phép thêm ảnh' OR label == 'Cho phép'"
            )).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(permissionHandler) }

        noted.buttons["gateAddPhoto"].tap()
        // Handle an add-only permission alert directly as well as through XCTest's monitor.
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let allow = alert.buttons.matching(NSPredicate(format:
                "label == 'Allow Photos to Be Added' OR label == 'Allow Adding Photos' OR label == 'Allow' OR label == 'OK' OR label == 'Cho phép thêm ảnh' OR label == 'Cho phép'"
            )).firstMatch
            XCTAssertTrue(allow.exists, "Unexpected photo permission choices; do not grant broader access.")
            allow.tap()
        }
        let saved = noted.staticTexts["gatePhotoStatus"]
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        XCTAssertTrue(saved.label.contains("Đã thêm ảnh mẫu NOTED DEVICE GATE"), saved.label)

        photos.launch()
        XCTAssertTrue(photos.wait(for: .runningForeground, timeout: 15))
        let library = photos.buttons.matching(NSPredicate(format:
            "label == 'Library' OR label == 'Thư viện' OR label == 'All Photos' OR label == 'Tất cả ảnh'"
        )).firstMatch
        XCTAssertTrue(library.waitForExistence(timeout: 10), "Photos Library navigation unavailable; inspect hierarchy instead of opening an arbitrary asset.")
        library.tap()

        // Photos on iOS 27 exposes its Library as a scroll view, not a collection view.
        let grid = photos.scrollViews["content_scroll_view"]
        XCTAssertTrue(grid.waitForExistence(timeout: 10), "Photo grid unavailable.")
        // A newly created image has the current creation date and belongs at the end
        // of the chronological Library. Scroll to its end without opening other photos.
        for _ in 0..<4 { grid.swipeUp() }
        let thumbnails = grid.images.matching(NSPredicate(format:
            "label BEGINSWITH 'Photo,' OR label BEGINSWITH 'Ảnh,' OR label BEGINSWITH 'Photo ' OR label BEGINSWITH 'Ảnh '"
        ))
        XCTAssertGreaterThan(thumbnails.count, 0, "No identifiable photo thumbnail; do not guess a tap location.")
        thumbnails.element(boundBy: thumbnails.count - 1).tap()

        // Verify the opened asset is our synthetic fixture before invoking Share.
        var verifiedFixture = false
        for _ in 0..<8 {
            let screenshot = XCUIScreen.main.screenshot()
            let recognition = VNRecognizeTextRequest()
            recognition.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: screenshot.image.cgImage!, options: [:]).perform([recognition])
            let recognized = (recognition.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").uppercased()
            if recognized.contains("NOTED DEVICE GATE") { verifiedFixture = true; break }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(verifiedFixture, "Newest photo did not match the synthetic fixture; no content will be shared.")
        attachScreenshot("Synthetic fixture opened in Photos")

        let share = photos.buttons.matching(NSPredicate(format:
            "identifier == 'Share' OR label == 'Share' OR label == 'Chia sẻ'"
        )).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        try saveThroughNotedExtension(host: photos, expectedPreview: "1 ảnh")
        noted.activate()
        XCTAssertTrue(noted.buttons["gateShowInbox"].waitForExistence(timeout: 10))
        noted.buttons["gateShowInbox"].tap()
        XCTAssertTrue(noted.images["Ảnh đã lưu"].firstMatch.waitForExistence(timeout: 15))
        attachScreenshot("Photos image copied into Noted")
    }
}
