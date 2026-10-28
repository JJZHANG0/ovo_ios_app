import XCTest
@testable import ZhiWeiShao

final class LogicTests: XCTestCase {
    private func fixedDate() -> Date {
        ZWFormat.calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9))!
    }

    private func lunch(in state: AppState, iso: String) -> Meal {
        state.meals.first { $0.date == iso && $0.name == "午餐" }!
    }

    private func chicken(in state: AppState, iso: String) -> FoodItem {
        Logic.mealFoods(lunch(in: state, iso: iso)).first { $0.name == "鸡胸肉" }!
    }

    func testSeedAndCorrectionStayOnOneStore() {
        let today = fixedDate()
        let iso = ZWFormat.formatISODate(today)
        XCTAssertEqual(iso, "2026-10-17")
        let seed = Logic.createInitial(today)
        let breakfast = seed.meals.first { $0.date == iso && $0.name == "早餐" }!
        XCTAssertEqual(Logic.mealKcal(breakfast), 732)
        XCTAssertEqual(Logic.mealKcal(lunch(in: seed, iso: iso)), 428)
        XCTAssertEqual(Logic.rollupDay(seed.meals, date: iso).kcal, 1160)
        XCTAssertEqual(Logic.rollupDay(seed.meals, date: iso).recordedLabel, "已记录早餐与午餐")
        XCTAssertEqual(Logic.openChecks(lunch(in: seed, iso: iso)).count, 1)

        let home = Present.home(seed, now: today)
        XCTAssertEqual(home.dateLine, "10月17日 · 周六")
        XCTAssertEqual(home.heroText, "1,160")
        XCTAssertEqual(home.heroMode, .value)
        XCTAssertEqual(home.helper, "已记录早餐与午餐")
        XCTAssertEqual(home.deviceLabel, "未绑定")
        XCTAssertEqual(home.meals[0].name, "午餐")
        XCTAssertEqual(home.meals[0].status, "待核对1项")
        XCTAssertTrue(home.meals[0].meta.contains("12:20"))
        XCTAssertTrue(home.meals[0].meta.contains("鸡肉蔬菜饭"))
        XCTAssertEqual(home.meals[0].kcalText, "428")
        XCTAssertEqual(home.meals[1].kcalText, "732")
        XCTAssertEqual(home.meals[1].status, "已确认")

        let empty = Logic.rollupDay(seed.meals, date: "2026-10-11")
        XCTAssertTrue(empty.empty)
        XCTAssertNil(empty.kcal)
        XCTAssertEqual(empty.placeholder, "没有记录")

        XCTAssertEqual(Logic.mealStartStep(seed)?.actionId, .bind)
        let linked = Logic.applyConnected(seed, bluetoothOpened: true)
        XCTAssertNil(linked.device.battery)
        XCTAssertEqual(linked.device.head, .none)
        XCTAssertFalse(linked.device.spoonLinked)
        let calibrated = Logic.applyCalibrated(linked)
        XCTAssertEqual(Logic.mealStartStep(calibrated)?.actionId, .device)
        let connected = Logic.applySpoonPacket(calibrated, .head(.spoon), now: 10)
        XCTAssertEqual(connected.device.head, .spoon)
        XCTAssertTrue(connected.device.spoonLinked)
        XCTAssertEqual(Logic.mealKcal(lunch(in: connected, iso: iso)), 428)
        XCTAssertNil(Logic.mealStartStep(connected))

        let lunchId = lunch(in: seed, iso: iso).id
        let foodId = chicken(in: seed, iso: iso).id
        let corrected = Logic.applyCorrection(seed, mealId: lunchId, foodId: foodId, optionId: "pan", now: 20)
        XCTAssertEqual(Logic.mealKcal(lunch(in: corrected, iso: iso)), 453)
        XCTAssertEqual(Logic.rollupDay(corrected.meals, date: iso).kcal, 1185)
        XCTAssertEqual(Logic.openChecks(lunch(in: corrected, iso: iso)).count, 0)
        XCTAssertEqual(Present.home(corrected, now: today).heroText, "1,185")
        XCTAssertEqual(Present.home(corrected, now: today).meals[0].status, "已确认")
        XCTAssertEqual(Present.detail(corrected, mealId: lunchId).heroText, "453")
        XCTAssertEqual(Present.records(corrected, selected: iso, today: iso).heroText, "1,185")

        let steamed = Logic.applyCorrection(corrected, mealId: lunchId, foodId: foodId, optionId: "steam", now: 30)
        XCTAssertEqual(Logic.mealKcal(lunch(in: steamed, iso: iso)), 428)
        XCTAssertEqual(Logic.rollupDay(steamed.meals, date: iso).kcal, 1160)

        let kept = Logic.applyCorrection(seed, mealId: lunchId, foodId: foodId, optionId: "keep", now: 40)
        XCTAssertEqual(Logic.mealKcal(lunch(in: kept, iso: iso)), 428)
        XCTAssertEqual(Logic.openChecks(lunch(in: kept, iso: iso)).count, 0)

        var hiddenState = corrected
        hiddenState.hideCalories = true
        let hidden = Present.home(hiddenState, now: today)
        XCTAssertEqual(hidden.heroMode, .hidden)
        XCTAssertTrue(hidden.meals.allSatisfy { $0.kcalMode == .hidden })
        XCTAssertEqual(Logic.mealKcal(lunch(in: corrected, iso: iso)), 453)
        let hiddenRecords = Present.records(hiddenState, selected: iso, today: iso)
        XCTAssertEqual(hiddenRecords.heroMode, .hidden)
        XCTAssertTrue(hiddenRecords.meals.allSatisfy { $0.kcalMode == .hidden })
        let hiddenDetail = Present.detail(hiddenState, mealId: lunchId)
        XCTAssertEqual(hiddenDetail.heroMode, .hidden)
        XCTAssertEqual(hiddenDetail.rangeText, "")
        XCTAssertTrue(hiddenDetail.foods.allSatisfy { $0.kcalText == "已隐藏" })

        let before = seed.meals.count
        var synced = Logic.applySync(corrected, incoming: Logic.deviceSnapshots(seedDate: iso), syncedAt: 50)
        XCTAssertEqual(synced.added, 0)
        XCTAssertEqual(synced.state.meals.count, before)
        XCTAssertEqual(Logic.mealKcal(lunch(in: synced.state, iso: iso)), 453)
        synced = Logic.applySync(synced.state, incoming: Logic.deviceSnapshots(seedDate: iso), syncedAt: 60)
        XCTAssertEqual(synced.added, 0)
        XCTAssertEqual(synced.state.meals.count, before)
        XCTAssertEqual(Logic.mealKcal(lunch(in: synced.state, iso: iso)), 453)

        let cleared = Logic.clearMeals(seed)
        let revived = Logic.applySync(cleared, incoming: Logic.deviceSnapshots(seedDate: iso), syncedAt: 70)
        XCTAssertEqual(revived.added, 0)
        XCTAssertEqual(revived.state.meals.count, 0)
        XCTAssertTrue(Logic.rollupDay(revived.state.meals, date: iso).empty)
        XCTAssertNil(Logic.rollupDay(revived.state.meals, date: iso).kcal)

        let added = Logic.applyAddEntry(seed, input: AddFoodInput(mealId: "", date: iso, mealName: "加餐", time: "16:00", name: "坚果", portion: ""), now: 80)
        XCTAssertTrue(added.pending)
        XCTAssertNil(Logic.rollupDay(added.state.meals, date: iso).kcal)
        XCTAssertEqual(Logic.rollupDay(added.state.meals, date: iso).placeholder, "待估算")

        let apple = Logic.applyAddEntry(seed, input: AddFoodInput(mealId: "", date: "2026-10-09", mealName: "加餐", time: "16:10", name: "苹果", portion: "1 个"), now: 90)
        XCTAssertFalse(apple.pending)
        XCTAssertEqual(Logic.rollupDay(apple.state.meals, date: "2026-10-09").kcal, 80)

        let disconnected = Logic.applyDisconnect(connected)
        XCTAssertEqual(disconnected.device.phase, .disconnected)
        XCTAssertTrue(Present.device(disconnected, today: iso).nextStep.contains("重新连接"))
        let failed = Logic.applySyncFailure(connected)
        XCTAssertEqual(failed.device.phase, .syncFailed)
        XCTAssertTrue(Present.device(failed, today: iso).nextStep.contains("再次同步"))
    }

    func testMonthSavingsStayHiddenWithoutMeals() {
        let today = fixedDate()
        let iso = ZWFormat.formatISODate(today)
        let seed = Logic.createInitial(today)
        let saved = Logic.monthSavings(meals: seed.meals, today: iso)
        XCTAssertNotNil(saved)
        XCTAssertNotEqual(saved, 0)
        XCTAssertEqual(TypicalMeal.name, "typical-meal")
        XCTAssertEqual(TypicalMeal.baselineKcal, 650)
        XCTAssertNil(Logic.monthSavings(meals: [], today: iso))

        var empty = seed
        empty.meals = []
        XCTAssertFalse(Present.home(empty, now: today, language: .en).savings.visible)
        XCTAssertFalse(Present.home(empty, now: today).savings.visible)

        let zh = Present.home(seed, now: today)
        XCTAssertEqual(zh.actionTitle, "准备好，开始下一餐")
        XCTAssertEqual(zh.actionCopy, "餐后查看记录，按需核对。")
        XCTAssertEqual(zh.primaryLabel, "开始")
        XCTAssertTrue(zh.savings.visible)
        XCTAssertEqual(zh.savings.caption, "本月少下来的")
        XCTAssertNotEqual(zh.savings.figure, "0")

        let en = Present.home(seed, now: today, language: .en)
        XCTAssertEqual(en.actionTitle, "Ready for the next meal")
        XCTAssertEqual(en.actionCopy, "Check the record after.")
        XCTAssertEqual(en.primaryLabel, "Start")
        XCTAssertTrue(en.savings.visible)
        XCTAssertEqual(en.savings.caption, "saved this month")
        XCTAssertTrue(en.savings.detail.contains("650"))
        XCTAssertNotEqual(en.savings.figure, "0")

        var hidden = seed
        hidden.hideCalories = true
        XCTAssertFalse(Present.home(hidden, now: today, language: .en).savings.visible)
    }

    func testSpoonLinkIgnoresForeignDevicesAndRepeats() {
        let battery = Data([0x01, 0x04, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x52, 0x56])
        XCTAssertEqual(SpoonLink.parse(battery), .battery(percent: 82))
        XCTAssertNil(SpoonLink.parse(Data([0x01, 0x04, 0x00])))

        var unknown = SpoonLink.frame(type: 0x7F, time: 0, payload: Data([0x01]))
        XCTAssertEqual(SpoonLink.parse(unknown), .ignored(type: 0x7F))
        unknown[unknown.count - 1] ^= 0xFF
        XCTAssertNil(SpoonLink.parse(unknown))

        let today = fixedDate()
        let seed = Logic.createInitial(today)
        let before = seed.meals.count
        let foreign = Logic.applyForeignLink(seed, name: "Headphones")
        XCTAssertEqual(foreign.meals.count, before)
        XCTAssertNil(foreign.device.battery)
        XCTAssertEqual(foreign.device.head, .none)
        XCTAssertFalse(foreign.device.spoonLinked)
        XCTAssertFalse(foreign.device.speaksSpoon)
        XCTAssertEqual(foreign.device.peripheralName, "Headphones")

        let start = SpoonLink.frame(type: SpoonLink.typeMealStart, time: 1_700_000_000, payload: {
            var payload = Data()
            SpoonLink.appendU32(7, to: &payload)
            return payload
        }())
        guard case .mealStart(let id, _) = SpoonLink.parse(start) else {
            return XCTFail("meal start did not parse")
        }
        let once = Logic.applySpoonPacket(seed, .mealStart(id: id, time: Date(timeIntervalSince1970: 1_700_000_000)), now: 20)
        let twice = Logic.applySpoonPacket(once, .mealStart(id: id, time: Date(timeIntervalSince1970: 1_700_000_000)), now: 30)
        XCTAssertEqual(twice.meals.count, before + 1)
        let meal = twice.meals.first { $0.id == "spoon-7" }
        XCTAssertEqual(meal?.foods.count, 0)
        XCTAssertNil(meal.flatMap(Logic.mealKcal))

        let sampled = Logic.applySpoonPacket(twice, .sample(id: id, time: Date(timeIntervalSince1970: 1_700_000_010), grams: 12, bite: true), now: 40)
        let repeated = Logic.applySpoonPacket(sampled, .sample(id: id, time: Date(timeIntervalSince1970: 1_700_000_010), grams: 12, bite: true), now: 50)
        XCTAssertEqual(repeated.meals.first { $0.id == "spoon-7" }?.events.count, sampled.meals.first { $0.id == "spoon-7" }?.events.count)
        XCTAssertNil(repeated.meals.first { $0.id == "spoon-7" }.flatMap(Logic.mealKcal))
    }
}
