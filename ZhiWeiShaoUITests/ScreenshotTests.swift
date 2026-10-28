import XCTest

final class ScreenshotTests: XCTestCase {
    private let media = "/Users/jjzhang/Library/Application Support/Cursor/AgentStores/cursor_agent_stores/bc-27deb740-f4aa-473a-b1c0-b6eb7676a07d/files/media"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWalkAndCapture() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-store", "-language", "zh", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans"]
        app.launch()

        XCTAssertTrue(see(app, "1,160", timeout: 8))
        XCTAssertTrue(app.images["product-spoon"].exists || app.images["智慧勺"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-home.png")

        let lunch = app.buttons.matching(NSPredicate(format: "label CONTAINS '午餐'")).firstMatch
        XCTAssertTrue(lunch.waitForExistence(timeout: 4))
        lunch.tap()
        XCTAssertTrue(see(app, "428"))
        settle()
        shot(app, "ios-detail.png")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(see(app, "1,160"))

        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(see(app, "1,160"))
        settle()
        shot(app, "ios-records.png")

        app.tabBars.buttons["商城"].tap()
        XCTAssertTrue(app.staticTexts["商城"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-shop.png")
        app.buttons["product-spoon-head"].tap()
        XCTAssertTrue(app.buttons["add-to-bag"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-shop-detail.png")
        app.buttons["返回"].firstMatch.tap()

        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["按你的方式记录"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-profile.png")

        app.buttons["profile-device"].tap()
        if !see(app, "还没有绑定", timeout: 4) {
            let dump = app.debugDescription
            try? dump.write(toFile: "/tmp/zhi-ax.txt", atomically: true, encoding: .utf8)
            XCTFail("device screen did not open")
        }
        if !app.buttons["device-primary"].waitForExistence(timeout: 4) {
            app.swipeUp()
            if !app.buttons["device-primary"].waitForExistence(timeout: 2) {
                let dump = app.debugDescription
                try? dump.write(toFile: "/tmp/zhi-ax.txt", atomically: true, encoding: .utf8)
                XCTFail("device-primary missing")
            }
        }
        app.buttons["device-primary"].tap()
        XCTAssertTrue(app.buttons["connect-local"].waitForExistence(timeout: 4))
        app.buttons["connect-local"].tap()
        XCTAssertTrue(app.staticTexts["可以开始用餐"].waitForExistence(timeout: 4))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已连接"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-device.png")

        app.buttons["device-primary"].tap()
        Thread.sleep(forTimeInterval: 2.2)
        app.buttons["device-primary"].tap()
        Thread.sleep(forTimeInterval: 2.2)
        app.buttons["返回"].firstMatch.tap()
        app.tabBars.buttons["今天"].tap()

        let lunchAgain = app.buttons.matching(NSPredicate(format: "label CONTAINS '午餐'")).firstMatch
        lunchAgain.tap()
        let check = app.buttons.matching(NSPredicate(format: "label CONTAINS '鸡肉的烹饪方式'")).firstMatch
        XCTAssertTrue(check.waitForExistence(timeout: 4))
        check.tap()
        app.buttons["option-pan"].tap()
        app.buttons["save-correction"].tap()
        XCTAssertTrue(see(app, "453"))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(see(app, "1,185"))
        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(see(app, "1,185"))
        app.tabBars.buttons["今天"].tap()

        app.buttons["primary-action"].tap()
        XCTAssertTrue(app.staticTexts["安心吃饭，餐后再看"].waitForExistence(timeout: 4))
        settle()
        shot(app, "ios-meal.png")
        app.buttons["返回"].firstMatch.tap()

        app.tabBars.buttons["我的"].tap()
        let hide = app.switches["hide-calories"]
        XCTAssertTrue(hide.waitForExistence(timeout: 4))
        hide.tap()
        app.tabBars.buttons["今天"].tap()
        XCTAssertTrue(app.staticTexts["热量已隐藏"].waitForExistence(timeout: 4))
        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["热量已隐藏"].waitForExistence(timeout: 4))
        app.buttons.matching(NSPredicate(format: "label CONTAINS '午餐'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已隐藏"].waitForExistence(timeout: 4))
    }

    func testLanguageShopAndSavingsShots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-store"]
        app.launch()

        let title = app.staticTexts["Ready for the next meal"]
        let copy = app.staticTexts["Check the record after."]
        let start = app.buttons["primary-action"]
        XCTAssertTrue(title.waitForExistence(timeout: 8))
        XCTAssertTrue(copy.waitForExistence(timeout: 4))
        XCTAssertEqual(start.label, "Start")
        let titleRight = max(title.frame.maxX, copy.frame.maxX)
        let linesMid = (min(title.frame.minY, copy.frame.minY) + max(title.frame.maxY, copy.frame.maxY)) / 2
        if start.frame.minX <= titleRight - 4 || abs(start.frame.midY - linesMid) > 22 {
            XCTFail("start \(start.frame) title \(title.frame) copy \(copy.frame)")
        }

        let savings = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "saved this month")).element(boundBy: 0)
        XCTAssertTrue(savings.waitForExistence(timeout: 4))
        XCTAssertGreaterThan(savings.frame.minY, start.frame.maxY + 8)
        XCTAssertTrue(savings.label.contains("saved this month"))
        XCTAssertFalse(savings.label.hasPrefix("0"))
        settle()
        shot(app, "ios-home-en.png")

        app.tabBars.buttons["Shop"].tap()
        let noon = app.buttons["product-spoon-head"]
        let morning = app.buttons["product-fork-head"]
        XCTAssertTrue(noon.waitForExistence(timeout: 4))
        XCTAssertTrue(morning.waitForExistence(timeout: 4))
        XCTAssertLessThan(abs(noon.frame.midY - morning.frame.midY), 24)
        settle()
        shot(app, "ios-shop-grid.png")
        noon.tap()
        let add = app.buttons["add-to-bag"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        XCTAssertEqual(add.label, "Add to bag")
        add.tap()
        app.buttons["Back"].firstMatch.tap()

        app.tabBars.buttons["Me"].tap()
        XCTAssertTrue(app.buttons["language-en"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["language-zh"].exists)
        settle()
        shot(app, "ios-settings-lang.png")

        app.buttons["language-zh"].tap()
        app.tabBars.buttons["今天"].tap()
        let zhTitle = app.staticTexts["准备好，开始下一餐"]
        let zhCopy = app.staticTexts["餐后查看记录，按需核对。"]
        XCTAssertTrue(zhTitle.waitForExistence(timeout: 4))
        XCTAssertTrue(zhCopy.waitForExistence(timeout: 4))
        XCTAssertEqual(app.buttons["primary-action"].label, "开始")
        XCTAssertGreaterThan(app.buttons["primary-action"].frame.minX, zhTitle.frame.maxX - 8)
        let zhSavings = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "本月少下来的")).element(boundBy: 0)
        XCTAssertTrue(zhSavings.waitForExistence(timeout: 4))
        XCTAssertTrue(zhSavings.label.contains("本月少下来的"))
        XCTAssertFalse(zhSavings.label.hasPrefix("0"))
        settle()
        shot(app, "ios-home-zh.png")
    }

    func testBluetoothScanShowsNoInventedDevices() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-store"]
        app.launch()
        app.buttons["device-chip"].tap()
        let status = app.staticTexts["ble-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["ble-empty"].waitForExistence(timeout: 4))
        let deadline = Date().addingTimeInterval(6)
        while status.label == "Asking for Bluetooth", Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertNotEqual(status.label, "Asking for Bluetooth")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ble-device-'")).count, 0)
        settle()
        shot(app, "ios-ble-scan.png")

        app.buttons["Back"].firstMatch.tap()
        app.tabBars.buttons["Me"].tap()
        app.buttons["profile-device"].tap()
        let next = app.staticTexts["device-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 6))
        XCTAssertFalse(next.label.isEmpty)
        settle()
        shot(app, "ios-ble-state.png")
    }

    func testShopSixPhotosAndPrices() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-store"]
        app.launch()
        app.tabBars.buttons["Shop"].tap()
        XCTAssertTrue(app.staticTexts["Shop"].waitForExistence(timeout: 8))

        let ids = ["spoon-head", "fork-head", "carry-sleeve", "midday-bowl", "morning-bowl", "five-middays"]
        let prices = ["¥49", "¥49", "¥29", "¥26", "¥16", "¥98"]
        let tabTop = app.tabBars.firstMatch.frame.minY
        var buttons: [XCUIElement] = []
        for (id, price) in zip(ids, prices) {
            let button = app.buttons["product-\(id)"]
            XCTAssertTrue(button.waitForExistence(timeout: 4), id)
            XCTAssertTrue(button.label.contains(price), "\(id) label \(button.label)")
            XCTAssertGreaterThan(button.frame.minY, 40, id)
            XCTAssertLessThan(button.frame.maxY, tabTop - 2, "\(id) price is below the tab bar \(button.frame)")
            buttons.append(button)
        }
        XCTAssertLessThan(abs(buttons[0].frame.midY - buttons[1].frame.midY), 24)
        XCTAssertLessThan(abs(buttons[2].frame.midY - buttons[3].frame.midY), 24)
        XCTAssertLessThan(abs(buttons[4].frame.midY - buttons[5].frame.midY), 24)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'product-'")).count, 6)
        settle()
        shot(app, "ios-shop-six.png")

        buttons[5].tap()
        XCTAssertTrue(see(app, "The single bowl is ¥26."))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '¥130'")).firstMatch.exists)
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(app.buttons["product-spoon-head"].waitForExistence(timeout: 4))
        app.buttons["product-spoon-head"].tap()
        let add = app.buttons["add-to-bag"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        XCTAssertEqual(add.label, "Add to bag")
        XCTAssertTrue(app.staticTexts["Spare steel spoon head, same mount."].exists)
        settle()
        shot(app, "ios-shop-detail-photo.png")
        add.tap()
    }

    private func see(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 6) -> Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.waitForExistence(timeout: timeout)
    }

    private func settle() {
        Thread.sleep(forTimeInterval: 0.8)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: media).appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: media), withIntermediateDirectories: true)
        do {
            try data.write(to: url)
        } catch {
            XCTFail("Could not write \(name): \(error)")
        }
    }
}
