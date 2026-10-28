import Foundation

enum Logic {
    static func mealFoods(_ meal: Meal) -> [FoodItem] {
        var out: [FoodItem] = []
        var indexByKey: [String: Int] = [:]
        for item in meal.foods {
            guard let check = item.check else {
                out.append(item)
                continue
            }
            let key = "\(item.name)::\(check.prompt)"
            if let previous = indexByKey[key] {
                let current = out[previous]
                if check.resolved, current.check?.resolved != true {
                    out[previous] = item
                }
            } else {
                indexByKey[key] = out.count
                out.append(item)
            }
        }
        return out
    }

    static func mealKcal(_ meal: Meal) -> Int? {
        if meal.status != .ready { return nil }
        let foods = mealFoods(meal)
        if foods.isEmpty { return nil }
        if foods.contains(where: { $0.kcal == nil }) { return nil }
        return foods.reduce(0) { $0 + ($1.kcal ?? 0) }
    }

    static func mealKcalRange(_ meal: Meal) -> (low: Int, high: Int)? {
        if meal.status != .ready { return nil }
        let foods = mealFoods(meal)
        if foods.isEmpty || foods.contains(where: { $0.kcal == nil }) { return nil }
        var low = 0
        var high = 0
        var spread = false
        for item in foods {
            let base = item.kcal ?? 0
            let options: [Int]
            if let check = item.check, !check.resolved {
                options = check.options.compactMap(\.kcal)
            } else {
                options = []
            }
            if !options.isEmpty {
                let minValue = min(base, options.min() ?? base)
                let maxValue = max(base, options.max() ?? base)
                low += minValue
                high += maxValue
                if minValue != maxValue { spread = true }
            } else {
                low += base
                high += base
            }
        }
        if !spread { return nil }
        return (low, high)
    }

    static func openChecks(_ meal: Meal) -> [FoodItem] {
        mealFoods(meal).filter { $0.check != nil && $0.check?.resolved != true }
    }

    static func mealStatusText(_ meal: Meal) -> String {
        if meal.status == .recording { return "记录中" }
        if meal.status == .settling { return "正在整理记录" }
        let pending = openChecks(meal).count
        if pending > 0 { return "待核对\(pending)项" }
        let foods = mealFoods(meal)
        if foods.contains(where: { $0.kcal == nil }) || foods.isEmpty { return "待估算" }
        return "已确认"
    }

    static func mealBrief(_ meal: Meal) -> String {
        if meal.status == .recording { return "用餐中" }
        if !meal.brief.isEmpty, meal.foods.count == meal.briefCount { return meal.brief }
        let foods = mealFoods(meal)
        if foods.isEmpty { return "还没有食物" }
        return foods.map(\.name).joined(separator: "、")
    }

    struct DayRollup {
        var empty: Bool
        var incomplete: Bool
        var settling: Bool
        var recording: Bool
        var kcal: Int?
        var placeholder: String
        var recordedLabel: String
        var mealsDesc: [Meal]
    }

    private static func uniqueNames(_ meals: [Meal]) -> [String] {
        var names: [String] = []
        let sorted = meals.sorted { lhs, rhs in
            if lhs.time == rhs.time { return lhs.startedAt < rhs.startedAt }
            return lhs.time < rhs.time
        }
        for meal in sorted where !names.contains(meal.name) {
            names.append(meal.name)
        }
        return names
    }

    static func rollupDay(_ meals: [Meal], date: String) -> DayRollup {
        let dayMeals = meals.filter { $0.date == date }
        let active = dayMeals.filter { $0.status == .recording }
        let closed = dayMeals.filter { $0.status != .recording }
        let mealsDesc = dayMeals.sorted { lhs, rhs in
            if lhs.time == rhs.time { return lhs.startedAt > rhs.startedAt }
            return lhs.time > rhs.time
        }
        if closed.isEmpty, active.isEmpty {
            return DayRollup(empty: true, incomplete: false, settling: false, recording: false, kcal: nil, placeholder: "没有记录", recordedLabel: "没有记录", mealsDesc: mealsDesc)
        }
        if closed.isEmpty {
            return DayRollup(empty: false, incomplete: false, settling: false, recording: true, kcal: nil, placeholder: "餐后整理", recordedLabel: "这餐还在记录", mealsDesc: mealsDesc)
        }
        let ready = closed.filter { $0.status == .ready }
        let settling = closed.contains { $0.status == .settling }
        if ready.isEmpty {
            return DayRollup(empty: false, incomplete: false, settling: true, recording: !active.isEmpty, kcal: nil, placeholder: "正在整理记录", recordedLabel: "正在整理记录", mealsDesc: mealsDesc)
        }
        let recordedLabel = ZWFormat.joinRecorded(uniqueNames(ready))
        let incomplete = ready.contains { mealKcal($0) == nil }
        if incomplete {
            return DayRollup(empty: false, incomplete: true, settling: settling, recording: !active.isEmpty, kcal: nil, placeholder: "待估算", recordedLabel: recordedLabel, mealsDesc: mealsDesc)
        }
        let kcal = ready.reduce(0) { $0 + (mealKcal($1) ?? 0) }
        return DayRollup(empty: false, incomplete: false, settling: settling, recording: !active.isEmpty, kcal: kcal, placeholder: "", recordedLabel: recordedLabel, mealsDesc: mealsDesc)
    }

    /// Recorded meals this calendar month, compared with `TypicalMeal.baselineKcal`.
    /// Meals without a calorie total are left out. No recorded meals returns nil, not zero.
    static func monthSavings(meals: [Meal], today: String, baseline: Int = TypicalMeal.baselineKcal) -> Int? {
        let month = String(today.prefix(7))
        let recorded = meals.filter { $0.date.hasPrefix(month) && mealKcal($0) != nil }
        if recorded.isEmpty { return nil }
        let actual = recorded.reduce(0) { $0 + (mealKcal($1) ?? 0) }
        return recorded.count * baseline - actual
    }

    static func defaultDevice() -> DeviceState {
        DeviceState(
            phase: .unbound,
            battery: nil,
            head: .none,
            calibrated: false,
            lastSyncAt: nil,
            pendingCount: 1,
            progress: 0,
            failNextSync: false,
            note: "",
            bluetoothOpened: false
        )
    }

    static func createInitial(_ now: Date) -> AppState {
        let seedDate = ZWFormat.formatISODate(now)
        return AppState(
            version: 1,
            seedDate: seedDate,
            meals: MockData.buildMeals(today: seedDate),
            deletedIds: [],
            recordingMealId: "",
            device: defaultDevice(),
            hideCalories: false,
            trainingConsent: false,
            profile: Profile(heightCm: "", weightKg: "", goal: "")
        )
    }

    static func mealStartStep(_ state: AppState) -> NextStep? {
        switch state.device.phase {
        case .unbound:
            return NextStep(title: "先连接智慧勺", body: "绑定餐具后就可以开始这餐。身高和目标都可以稍后再填。", action: "去绑定", actionId: .bind)
        case .permissionOff:
            return NextStep(title: "还没有允许蓝牙", body: "在设置里允许智慧勺使用蓝牙，然后再扫描。", action: "打开设置", actionId: .permission)
        case .bluetoothOff:
            return NextStep(title: "蓝牙还没有打开", body: "在控制中心打开蓝牙，然后再扫描。", action: "重新扫描", actionId: .reconnect)
        case .unavailable:
            return NextStep(title: "这里没有蓝牙", body: "模拟器扫描不到附近的设备。用一台 iPhone 再扫描。", action: "重新扫描", actionId: .device)
        case .scanning, .connecting, .syncing:
            return NextStep(title: "请稍等", body: "餐具正在处理上一步，完成后再开始用餐。", action: "查看设备", actionId: .device)
        case .connectFailed:
            return NextStep(title: "没有连上", body: "靠近后再选一次。不会自动连上别的设备。", action: "重新扫描", actionId: .reconnect)
        case .disconnected:
            return NextStep(title: "餐具没有连上", body: "靠近餐具后重新连接。", action: "重新连接", actionId: .reconnect)
        case .syncFailed:
            return NextStep(title: "同步没有完成", body: "可以先重新同步，再开始用餐。", action: "查看设备", actionId: .device)
        case .connected:
            break
        }
        if !state.device.speaksSpoon {
            return NextStep(title: "还不是智慧勺", body: "这份连接不会记餐，也不会写入热量。", action: "重新扫描", actionId: .reconnect)
        }
        if !state.device.calibrated {
            return NextStep(title: "先完成校准", body: "把餐具平放在桌面，完成校准后再开始。", action: "去校准", actionId: .calibrate)
        }
        if state.device.head == .none {
            return NextStep(title: "先确认餐头", body: "装上勺头或叉头后，再开始用餐。", action: "查看设备", actionId: .device)
        }
        if !state.recordingMealId.isEmpty {
            return NextStep(title: "有一餐还在记录", body: "先结束这一餐，再开始下一餐。", action: "继续用餐", actionId: .resume)
        }
        return nil
    }

    static func dropLiveLink(_ state: AppState) -> AppState {
        switch state.device.phase {
        case .connected, .connecting, .scanning, .syncing, .syncFailed:
            var next = state
            next.device.phase = .disconnected
            next.device.battery = nil
            next.device.head = .none
            next.device.spoonLinked = false
            next.device.speaksSpoon = false
            next.device.peripheralName = ""
            next.device.calibrated = false
            next.device.progress = 0
            next.device.note = "下一步：重新扫描并选择设备。"
            return next
        default:
            return state
        }
    }

    static func applyDenyBluetooth(_ state: AppState) -> AppState {
        var next = state
        next.device.phase = .permissionOff
        next.device.progress = 0
        next.device.bluetoothOpened = false
        next.device.note = "下一步：前往设置允许蓝牙。"
        return next
    }

    static func applyBluetoothOff(_ state: AppState) -> AppState {
        var next = state
        next.device.phase = .bluetoothOff
        next.device.progress = 0
        next.device.bluetoothOpened = false
        next.device.note = "下一步：打开蓝牙。"
        return next
    }

    static func applyRadioUnavailable(_ state: AppState) -> AppState {
        var next = state
        next.device.phase = .unavailable
        next.device.progress = 0
        next.device.bluetoothOpened = false
        next.device.note = "下一步：换到 iPhone。"
        return next
    }

    static func applyScanning(_ state: AppState) -> AppState {
        var next = state
        next.device.phase = .scanning
        next.device.progress = 0
        next.device.bluetoothOpened = true
        next.device.note = "选择一个设备后才会连接。"
        return next
    }

    static func applyConnecting(_ state: AppState, name: String) -> AppState {
        var next = state
        next.device.phase = .connecting
        next.device.peripheralName = name
        next.device.progress = 40
        next.device.note = "请让餐具靠近手机。"
        return next
    }

    static func applyConnectFailed(_ state: AppState, name: String) -> AppState {
        var next = state
        next.device.phase = .connectFailed
        if !name.isEmpty { next.device.peripheralName = name }
        next.device.progress = 0
        next.device.spoonLinked = false
        next.device.speaksSpoon = false
        next.device.note = "下一步：重新扫描并选择设备。"
        return next
    }

    /// A live link that does not speak Spoon Link. Meals, calories, battery, and head stay as they were, except battery and head are cleared so a previous spoon cannot leak onto this device.
    static func applyForeignLink(_ state: AppState, name: String) -> AppState {
        var next = state
        next.device.phase = .connected
        next.device.peripheralName = name.isEmpty ? "未命名" : name
        next.device.speaksSpoon = false
        next.device.spoonLinked = false
        next.device.battery = nil
        next.device.head = .none
        next.device.calibrated = false
        next.device.progress = 100
        next.device.bluetoothOpened = true
        next.device.note = "还不是智慧勺。这份连接不会记餐，也不会写入热量。"
        return next
    }

    static func applySpoonService(_ state: AppState, name: String) -> AppState {
        var next = state
        next.device.phase = .connected
        next.device.peripheralName = name.isEmpty ? "未命名" : name
        next.device.speaksSpoon = true
        next.device.spoonLinked = false
        next.device.battery = nil
        next.device.head = .none
        next.device.progress = 100
        next.device.bluetoothOpened = true
        next.device.note = "已找到智慧勺，还没有收到数据。"
        return next
    }

    static func applyConnected(_ state: AppState, bluetoothOpened: Bool) -> AppState {
        var next = state
        next.device.phase = .connected
        next.device.progress = 100
        next.device.bluetoothOpened = bluetoothOpened
        next.device.speaksSpoon = true
        next.device.note = ""
        return next
    }

    static func applySpoonPacket(_ state: AppState, _ packet: SpoonPacket, now: Double) -> AppState {
        var next = state
        switch packet {
        case .ignored:
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            return next
        case .battery(let percent):
            guard (0...100).contains(percent) else { return state }
            next.device.battery = percent
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            return next
        case .head(let head):
            next.device.head = head
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            return next
        case .mealStart(let id, let time):
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            let mealId = spoonMealId(id)
            if next.meals.contains(where: { $0.id == mealId }) { return next }
            let meal = spoonMeal(id: mealId, time: time, now: now)
            next.meals.append(meal)
            next.recordingMealId = mealId
            return next
        case .sample(let id, let time, let grams, let bite):
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            let mealId = spoonMealId(id)
            guard let index = next.meals.firstIndex(where: { $0.id == mealId }) else { return next }
            let clock = ZWFormat.formatClock(time)
            let note = bite ? "一口 · \(grams) g" : "\(grams) g"
            if next.meals[index].events.contains(where: { $0.time == clock && $0.note == note }) { return next }
            next.meals[index].events.append(BiteEvent(time: clock, note: note))
            if bite {
                next.meals[index].biteCount = (next.meals[index].biteCount ?? 0) + 1
            }
            next.meals[index].updatedAt = now
            return next
        case .mealEnd(let id, let time, let duration):
            next.device.spoonLinked = true
            next.device.speaksSpoon = true
            let mealId = spoonMealId(id)
            guard let index = next.meals.firstIndex(where: { $0.id == mealId }) else { return next }
            if next.meals[index].status != .recording { return next }
            next.meals[index].status = .ready
            next.meals[index].endedAt = time.timeIntervalSince1970 * 1000
            next.meals[index].durationSec = max(1, duration)
            next.meals[index].updatedAt = now
            if next.recordingMealId == mealId { next.recordingMealId = "" }
            return next
        }
    }

    private static func spoonMealId(_ id: UInt32) -> String {
        "spoon-\(id)"
    }

    private static func spoonMeal(id: String, time: Date, now: Double) -> Meal {
        Meal(
            id: id,
            date: ZWFormat.formatISODate(time),
            name: "用餐",
            time: ZWFormat.formatClock(time),
            startedAt: time.timeIntervalSince1970 * 1000,
            endedAt: nil,
            durationSec: 0,
            biteCount: nil,
            status: .recording,
            foods: [],
            brief: "用餐中",
            briefCount: 0,
            events: [BiteEvent(time: ZWFormat.formatClock(time), note: "开始用餐")],
            updatedAt: now,
            source: .utensil,
            estimateNote: ""
        )
    }

    static func applyCalibrated(_ state: AppState) -> AppState {
        guard state.device.phase == .connected || state.device.phase == .syncFailed else { return state }
        var next = state
        next.device.calibrated = true
        next.device.phase = .connected
        next.device.note = "校准已完成。"
        return next
    }

    static func applyDisconnect(_ state: AppState) -> AppState {
        if state.device.phase == .unbound || state.device.phase == .permissionOff { return state }
        var next = state
        next.device.phase = .disconnected
        next.device.progress = 0
        next.device.note = "下一步：靠近餐具，重新连接。"
        return next
    }

    static func applyHead(_ state: AppState, head: UtensilHead) -> AppState {
        if state.device.phase == .unbound { return state }
        var next = state
        next.device.head = head
        return next
    }

    static func applySyncFailure(_ state: AppState) -> AppState {
        var next = state
        next.device.phase = .syncFailed
        next.device.failNextSync = false
        next.device.progress = 0
        next.device.note = "下一步：再次同步。记录还在。"
        return next
    }

    static func applySync(_ state: AppState, incoming: [Meal], syncedAt: Double) -> (state: AppState, added: Int) {
        let deleted = Set(state.deletedIds)
        var map = Dictionary(uniqueKeysWithValues: state.meals.map { ($0.id, $0) })
        var order = state.meals.map(\.id)
        var added = 0
        for meal in incoming {
            if deleted.contains(meal.id) { continue }
            if let local = map[meal.id] {
                if local.updatedAt >= meal.updatedAt {
                    map[meal.id] = local
                } else {
                    map[meal.id] = meal
                }
            } else {
                map[meal.id] = meal
                order.append(meal.id)
                added += 1
            }
        }
        var next = state
        next.meals = order.compactMap { map[$0] }
        next.device.phase = .connected
        next.device.progress = 100
        next.device.pendingCount = 0
        next.device.lastSyncAt = syncedAt
        next.device.failNextSync = false
        next.device.note = added > 0 ? "已同步 \(added) 条记录。" : "记录已是最新。"
        return (next, added)
    }

    private static func nextMealName(_ state: AppState, date: String, now: Date) -> String {
        let hour = ZWFormat.calendar.component(.hour, from: now)
        let preferred = hour < 10 ? "早餐" : hour < 15 ? "午餐" : hour < 21 ? "晚餐" : "加餐"
        let exists = state.meals.contains { $0.date == date && $0.name == preferred && $0.status != .recording }
        return exists ? "加餐" : preferred
    }

    static func applyStartMeal(_ state: AppState, now: Double) -> (state: AppState, meal: Meal) {
        let dateValue = Date(timeIntervalSince1970: now / 1000)
        let date = ZWFormat.formatISODate(dateValue)
        let time = ZWFormat.formatClock(dateValue)
        let name = nextMealName(state, date: date, now: dateValue)
        let meal = Meal(
            id: "meal-live-\(Int(now))",
            date: date,
            name: name,
            time: time,
            startedAt: now,
            endedAt: nil,
            durationSec: 0,
            biteCount: nil,
            status: .recording,
            foods: [],
            brief: "用餐中",
            briefCount: 0,
            events: [],
            updatedAt: now,
            source: .utensil,
            estimateNote: ""
        )
        var next = state
        next.meals.append(meal)
        next.recordingMealId = meal.id
        return (next, meal)
    }

    static func applyEndMeal(_ state: AppState, mealId: String, now: Double) -> AppState {
        var next = state
        if next.recordingMealId == mealId { next.recordingMealId = "" }
        next.meals = next.meals.map { meal in
            guard meal.id == mealId, meal.status == .recording else { return meal }
            var updated = meal
            updated.durationSec = max(1, Int(((now - meal.startedAt) / 1000).rounded()))
            updated.status = .settling
            updated.endedAt = now
            updated.updatedAt = now
            return updated
        }
        return next
    }

    static func applyFinishMeal(_ state: AppState, mealId: String, now: Double) -> AppState {
        var next = state
        next.meals = next.meals.map { meal in
            guard meal.id == mealId, meal.status == .settling else { return meal }
            var updated = meal
            let foods = meal.foods.isEmpty ? MockData.liveFoods(mealId: meal.id) : meal.foods
            let short = meal.durationSec < 20
            updated.status = .ready
            updated.foods = foods
            updated.brief = foods.map(\.name).joined(separator: "、")
            updated.briefCount = foods.count
            updated.biteCount = short ? nil : max(6, Int((Double(meal.durationSec) / 40).rounded()))
            updated.estimateNote = short ? "用餐时间较短，请核对下面的结果。" : "可以按需要核对食物。"
            if meal.events.isEmpty {
                updated.events = [
                    BiteEvent(time: meal.time, note: "开始用餐"),
                    BiteEvent(time: ZWFormat.formatClock(Date(timeIntervalSince1970: now / 1000)), note: "这餐结束"),
                ]
            }
            updated.updatedAt = now
            return updated
        }
        return next
    }

    static func applyCorrection(_ state: AppState, mealId: String, foodId: String, optionId: String, now: Double) -> AppState {
        var next = state
        next.meals = next.meals.map { meal in
            guard meal.id == mealId else { return meal }
            var updated = meal
            updated.foods = mealFoods(meal).map { item in
                guard item.id == foodId, var check = item.check else { return item }
                guard let option = check.options.first(where: { $0.id == optionId }) else { return item }
                var edited = item
                edited.kcal = option.kcal ?? item.kcal
                check.resolved = true
                check.choiceId = optionId
                edited.check = check
                return edited
            }
            updated.updatedAt = now
            updated.status = .ready
            return updated
        }
        return next
    }

    static func applyAddEntry(_ state: AppState, input: AddFoodInput, now: Double) -> (state: AppState, mealId: String, pending: Bool) {
        let name = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let portion = input.portion.trimmingCharacters(in: .whitespacesAndNewlines)
        let kcal = MockData.estimateManualFood(name: name, portion: portion)
        let item = FoodItem(
            id: "manual-\(Int(now))",
            name: name,
            portion: portion.isEmpty ? "分量待补充" : portion,
            kcal: kcal,
            source: .manual,
            check: nil
        )
        if !input.mealId.isEmpty {
            var next = state
            next.meals = next.meals.map { meal in
                guard meal.id == input.mealId else { return meal }
                var updated = meal
                updated.foods.append(item)
                updated.updatedAt = now
                updated.briefCount = -1
                return updated
            }
            return (next, input.mealId, kcal == nil)
        }
        if let existing = state.meals.reversed().first(where: { $0.date == input.date && $0.name == input.mealName && $0.status == .ready }) {
            var next = state
            next.meals = next.meals.map { meal in
                guard meal.id == existing.id else { return meal }
                var updated = meal
                updated.foods.append(item)
                if !input.time.isEmpty { updated.time = input.time }
                updated.updatedAt = now
                updated.briefCount = -1
                return updated
            }
            return (next, existing.id, kcal == nil)
        }
        let mealId = "meal-manual-\(Int(now))"
        let meal = Meal(
            id: mealId,
            date: input.date,
            name: input.mealName,
            time: input.time,
            startedAt: now,
            endedAt: now,
            durationSec: 0,
            biteCount: nil,
            status: .ready,
            foods: [item],
            brief: name,
            briefCount: 1,
            events: [],
            updatedAt: now,
            source: .manual,
            estimateNote: kcal == nil ? "信息还不够，这一项保持待估算。" : ""
        )
        var next = state
        next.meals.append(meal)
        return (next, mealId, kcal == nil)
    }

    static func clearMeals(_ state: AppState) -> AppState {
        var next = state
        var deleted = Set(state.deletedIds)
        state.meals.forEach { deleted.insert($0.id) }
        next.deletedIds = Array(deleted)
        next.meals = []
        next.recordingMealId = ""
        return next
    }

    static func deviceSnapshots(seedDate: String) -> [Meal] {
        MockData.buildMeals(today: seedDate)
    }

    static func findMeal(_ state: AppState, mealId: String) -> Meal? {
        state.meals.first { $0.id == mealId }
    }
}
