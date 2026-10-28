import Foundation

enum HeroMode: Equatable {
    case value
    case hidden
    case placeholder
}

enum RowTone: Equatable {
    case pending
    case ok
    case wait
}

struct MealRowVM: Equatable, Identifiable {
    var id: String
    var name: String
    var meta: String
    var status: String
    var tone: RowTone
    var kcalMode: HeroMode
    var kcalText: String
}

struct SavingsVM: Equatable {
    var visible: Bool
    var figure: String
    var caption: String
    var detail: String

    static let hidden = SavingsVM(visible: false, figure: "", caption: "", detail: "")
}

struct HomeVM: Equatable {
    var dateLine: String
    var deviceLabel: String
    var deviceOn: Bool
    var devicePhase: DevicePhase
    var heroMode: HeroMode
    var heroText: String
    var helper: String
    var note: String
    var meals: [MealRowVM]
    var primaryLabel: String
    var actionTitle: String
    var actionCopy: String
    var savings: SavingsVM
}

struct DayChip: Equatable, Identifiable {
    var iso: String
    var weekday: String
    var dayNum: String
    var selected: Bool
    var isToday: Bool
    var id: String { iso }
}

struct RecordsVM: Equatable {
    var selected: String
    var title: String
    var weekLabel: String
    var days: [DayChip]
    var empty: Bool
    var mealCount: Int
    var heroMode: HeroMode
    var heroText: String
    var helper: String
    var note: String
    var meals: [MealRowVM]
}

struct FoodRowVM: Equatable, Identifiable {
    var id: String
    var name: String
    var portion: String
    var kcalText: String
    var muted: Bool
}

struct CheckRowVM: Equatable, Identifiable {
    var id: String
    var question: String
    var resolved: Bool
    var choice: String
}

struct DetailVM: Equatable {
    var id: String
    var missing: Bool
    var dateLine: String
    var name: String
    var heroMode: HeroMode
    var heroText: String
    var rangeText: String
    var checkNote: String
    var estimateNote: String
    var bites: String
    var duration: String
    var foods: [FoodRowVM]
    var checks: [CheckRowVM]
    var events: [BiteEvent]
}

struct CorrectionVM: Equatable {
    var missing: Bool
    var mealId: String
    var foodId: String
    var mealName: String
    var foodName: String
    var prompt: String
    var choiceId: String
    var options: [CheckOption]
}

enum DevicePrimary: Equatable {
    case sync
    case reconnect
    case bind
    case permission
    case scan
    case settings
    case wait
}

struct DeviceVM: Equatable {
    var phase: DevicePhase
    var title: String
    var body: String
    var nextStep: String
    var showBattery: Bool
    var batteryText: String
    var headLabel: String
    var head: UtensilHead
    var syncText: String
    var pendingText: String
    var primary: String
    var primaryId: DevicePrimary
    var primaryDisabled: Bool
    var showDisconnect: Bool
    var calibrated: Bool
    var canCalibrate: Bool
    var progress: Int
    var showProgress: Bool
    var maintenance: String
    var note: String
}

enum Present {
    static func mealRow(_ meal: Meal, hide: Bool, language: AppLanguage = .zh) -> MealRowVM {
        let kcal = rowKcal(meal, hide: hide)
        let row = MealRowVM(
            id: meal.id,
            name: meal.name,
            meta: "\(meal.time) · \(Logic.mealBrief(meal))",
            status: Logic.mealStatusText(meal),
            tone: tone(meal),
            kcalMode: kcal.mode,
            kcalText: kcal.text
        )
        guard language == .en else { return row }
        return MealRowVM(
            id: row.id,
            name: L10n.text(row.name, .en),
            meta: L10n.meta(row.meta, .en),
            status: L10n.text(row.status, .en),
            tone: row.tone,
            kcalMode: row.kcalMode,
            kcalText: L10n.text(row.kcalText, .en)
        )
    }

    private static func rowKcal(_ meal: Meal, hide: Bool) -> (mode: HeroMode, text: String) {
        if hide, meal.status == .ready, Logic.mealKcal(meal) != nil { return (.hidden, "已隐藏") }
        if meal.status == .recording { return (.placeholder, "餐后整理") }
        if meal.status == .settling { return (.placeholder, "正在整理记录") }
        guard let kcal = Logic.mealKcal(meal) else { return (.placeholder, "待估算") }
        if hide { return (.hidden, "已隐藏") }
        return (.value, ZWFormat.formatInt(kcal))
    }

    private static func tone(_ meal: Meal) -> RowTone {
        if meal.status != .ready { return .wait }
        if !Logic.openChecks(meal).isEmpty || Logic.mealFoods(meal).contains(where: { $0.kcal == nil }) { return .pending }
        return .ok
    }

    private static func hero(from state: AppState, date: String) -> (mode: HeroMode, text: String, helper: String, note: String) {
        let rollup = Logic.rollupDay(state.meals, date: date)
        if rollup.empty {
            return (.placeholder, "没有记录", "没有记录", "没有记录并不代表没有进食。")
        }
        if state.hideCalories, rollup.kcal != nil {
            return (.hidden, "热量已隐藏", rollup.recordedLabel, rollup.kcal == 0 ? "这是已记下的估算，不是未记录。" : "还没记的餐不会当成 0。")
        }
        if rollup.kcal == nil {
            let note = rollup.incomplete
                ? "还有食物待估算，所以先不显示合计。"
                : rollup.settling
                    ? "还有餐次正在整理，没有算进合计。"
                    : "还没记的餐不会当成 0。"
            return (.placeholder, rollup.placeholder, rollup.recordedLabel, note)
        }
        let kcal = rollup.kcal ?? 0
        let note = kcal == 0
            ? "这是已记下的估算，不是未记录。"
            : rollup.settling
                ? "还有餐次正在整理，没有算进合计。"
                : "还没记的餐不会当成 0。"
        return (.value, ZWFormat.formatInt(kcal), rollup.recordedLabel, note)
    }

    static func deviceChip(_ device: DeviceState) -> (label: String, on: Bool) {
        switch device.phase {
        case .connected:
            if !device.speaksSpoon {
                let name = device.peripheralName.isEmpty ? "已连接" : device.peripheralName
                return ("\(name) · 还不是勺", true)
            }
            if !device.peripheralName.isEmpty, device.battery == nil {
                return (device.peripheralName, true)
            }
            return (device.battery != nil ? "已连接 · \(device.battery ?? 0)%" : "已连接", true)
        case .syncing:
            return ("同步中", true)
        case .syncFailed:
            return ("同步失败", true)
        case .scanning:
            return ("扫描中", false)
        case .connecting:
            return ("连接中", true)
        case .disconnected:
            return ("已断开", false)
        case .connectFailed:
            return ("连接失败", false)
        case .permissionOff:
            return ("未允许", false)
        case .bluetoothOff:
            return ("蓝牙未开", false)
        case .unavailable:
            return ("无蓝牙", false)
        case .unbound:
            return ("未绑定", false)
        }
    }

    static func home(_ state: AppState, now: Date, language: AppLanguage = .zh) -> HomeVM {
        let today = ZWFormat.formatISODate(now)
        let rollup = Logic.rollupDay(state.meals, date: today)
        let hero = hero(from: state, date: today)
        let chip = deviceChip(state.device)
        let recording = !state.recordingMealId.isEmpty
        let saved = Logic.monthSavings(meals: state.meals, today: today)
        return HomeVM(
            dateLine: L10n.dateLine(today, week: true, language),
            deviceLabel: L10n.text(chip.label, language),
            deviceOn: chip.on,
            devicePhase: state.device.phase,
            heroMode: hero.mode,
            heroText: L10n.text(hero.text, language),
            helper: L10n.recorded(hero.helper, language),
            note: L10n.text(hero.note, language),
            meals: rollup.mealsDesc.map { mealRow($0, hide: state.hideCalories, language: language) },
            primaryLabel: recording ? L10n.text("继续", language) : L10n.text("开始", language),
            actionTitle: recording ? L10n.text("这餐还在记录", language) : L10n.text("准备好，开始下一餐", language),
            actionCopy: recording ? L10n.text("结束后再查看食物和热量。", language) : L10n.text("餐后查看记录，按需核对。", language),
            savings: L10n.savings(saved: saved, hidden: state.hideCalories, language)
        )
    }

    static func records(_ state: AppState, selected: String, today: String, language: AppLanguage = .zh) -> RecordsVM {
        let monday = ZWFormat.mondayOf(selected)
        let days: [DayChip] = (0..<7).map { index in
            let iso = ZWFormat.shiftDate(monday, days: index)
            return DayChip(
                iso: iso,
                weekday: language == .en ? L10n.weekday(iso, chip: true) : ZWFormat.weekdayChar(iso),
                dayNum: ZWFormat.dayNumber(iso),
                selected: iso == selected,
                isToday: iso == today
            )
        }
        let rollup = Logic.rollupDay(state.meals, date: selected)
        let hero = hero(from: state, date: selected)
        return RecordsVM(
            selected: selected,
            title: L10n.dateLine(selected, week: true, language),
            weekLabel: L10n.weekSpan(monday, ZWFormat.shiftDate(monday, days: 6), language),
            days: days,
            empty: rollup.empty,
            mealCount: rollup.mealsDesc.count,
            heroMode: hero.mode,
            heroText: L10n.text(hero.text, language),
            helper: L10n.recorded(hero.helper, language),
            note: L10n.text(hero.note, language),
            meals: rollup.mealsDesc.map { mealRow($0, hide: state.hideCalories, language: language) }
        )
    }

    static func detail(_ state: AppState, mealId: String, language: AppLanguage = .zh) -> DetailVM {
        guard let meal = state.meals.first(where: { $0.id == mealId }) else {
            return DetailVM(id: mealId, missing: true, dateLine: "", name: L10n.text("没有找到这餐", language), heroMode: .placeholder, heroText: L10n.text("没有记录", language), rangeText: "", checkNote: "", estimateNote: "", bites: "", duration: "", foods: [], checks: [], events: [])
        }
        let foods = Logic.mealFoods(meal)
        let kcal = Logic.mealKcal(meal)
        let range = Logic.mealKcalRange(meal)
        let hide = state.hideCalories
        var heroMode: HeroMode = .placeholder
        var heroText = L10n.text(meal.status == .settling ? "正在整理记录" : meal.status == .recording ? "餐后整理" : "待估算", language)
        if hide, kcal != nil {
            heroMode = .hidden
            heroText = L10n.text("热量已隐藏", language)
        } else if let kcal {
            heroMode = .value
            heroText = ZWFormat.formatInt(kcal)
        }
        let rangeText = (!hide && range != nil) ? L10n.text("估算区间 \(ZWFormat.formatInt(range!.low))–\(ZWFormat.formatInt(range!.high)) kcal", language) : ""
        let resolved = foods.contains { $0.check?.resolved == true }
        let pending = Logic.openChecks(meal).count
        return DetailVM(
            id: meal.id,
            missing: false,
            dateLine: "\(L10n.dateLine(meal.date, week: false, language)) · \(meal.time)",
            name: L10n.text(meal.name, language),
            heroMode: heroMode,
            heroText: heroText,
            rangeText: rangeText,
            checkNote: pending == 0 && resolved ? L10n.text("已按你的核对更新", language) : "",
            estimateNote: L10n.text(meal.estimateNote, language),
            bites: meal.biteCount != nil ? L10n.text("\(meal.biteCount ?? 0) 口", language) : "",
            duration: L10n.text(ZWFormat.formatDuration(meal.durationSec, manual: meal.source == .manual), language),
            foods: foods.map { item in
                if hide, item.kcal != nil {
                    return FoodRowVM(id: item.id, name: L10n.text(item.name, language), portion: L10n.text(item.portion, language), kcalText: L10n.text("已隐藏", language), muted: true)
                }
                if item.kcal == nil {
                    return FoodRowVM(id: item.id, name: L10n.text(item.name, language), portion: L10n.text(item.portion, language), kcalText: L10n.text("待估算", language), muted: true)
                }
                return FoodRowVM(id: item.id, name: L10n.text(item.name, language), portion: L10n.text(item.portion, language), kcalText: "\(ZWFormat.formatInt(item.kcal ?? 0)) kcal", muted: false)
            },
            checks: foods.compactMap { item in
                guard let check = item.check else { return nil }
                let choice = check.options.first { $0.id == check.choiceId }
                return CheckRowVM(
                    id: item.id,
                    question: L10n.text(check.resolved ? "\(item.name)已核对" : check.question, language),
                    resolved: check.resolved,
                    choice: L10n.text(check.resolved ? (choice?.label ?? "已核对") : "去核对", language)
                )
            },
            events: meal.events.map { BiteEvent(time: $0.time, note: L10n.text($0.note, language)) }
        )
    }

    static func correction(_ state: AppState, mealId: String, foodId: String, language: AppLanguage = .zh) -> CorrectionVM {
        let meal = state.meals.first { $0.id == mealId }
        let food = meal.flatMap { Logic.mealFoods($0).first { $0.id == foodId } }
        guard let meal, let food, let check = food.check else {
            return CorrectionVM(missing: true, mealId: mealId, foodId: foodId, mealName: "", foodName: "", prompt: L10n.text("没有找到需要核对的食物", language), choiceId: "", options: [])
        }
        return CorrectionVM(
            missing: false,
            mealId: mealId,
            foodId: foodId,
            mealName: L10n.text(meal.name, language),
            foodName: L10n.text(food.name, language),
            prompt: L10n.text(check.prompt, language),
            choiceId: check.choiceId,
            options: check.options.map { CheckOption(id: $0.id, label: L10n.text($0.label, language), kcal: $0.kcal) }
        )
    }

    static func headName(_ head: UtensilHead, language: AppLanguage = .zh) -> String {
        switch head {
        case .spoon: return L10n.text("勺头", language)
        case .fork: return L10n.text("叉头", language)
        case .none: return L10n.text("未选择餐头", language)
        }
    }

    static func device(_ state: AppState, today: String, language: AppLanguage = .zh) -> DeviceVM {
        let device = state.device
        let headLabel = headName(device.head, language: language)
        let syncText = device.lastSyncAt != nil ? L10n.text("上次同步 \(ZWFormat.formatStamp(device.lastSyncAt ?? 0, todayIso: today))", language) : L10n.text("还没有同步", language)
        let pendingText = device.pendingCount > 0 ? L10n.text("还有 \(device.pendingCount) 条记录待同步", language) : L10n.text("没有待同步的记录", language)
        var view = DeviceVM(
            phase: device.phase,
            title: "",
            body: "",
            nextStep: "",
            showBattery: device.battery != nil && device.phase != .unbound,
            batteryText: device.battery != nil ? "\(device.battery ?? 0)%" : "",
            headLabel: headLabel,
            head: device.head,
            syncText: syncText,
            pendingText: pendingText,
            primary: "",
            primaryId: .wait,
            primaryDisabled: false,
            showDisconnect: device.phase == .connected || device.phase == .syncFailed,
            calibrated: device.calibrated,
            canCalibrate: device.spoonLinked && (device.phase == .connected || device.phase == .syncFailed),
            progress: device.progress,
            showProgress: device.phase == .connecting || device.phase == .syncing,
            maintenance: L10n.text("餐后冲洗餐头，避免浸泡机身。", language),
            note: L10n.text(device.note, language)
        )
        switch device.phase {
        case .unbound:
            view.title = "还没有绑定智慧勺"
            view.body = "绑定后可以查看连接、电量和餐头。"
            view.nextStep = "下一步：去绑定"
            view.primary = "去绑定"
            view.primaryId = .bind
            view.showDisconnect = false
        case .permissionOff:
            view.title = "还没有允许蓝牙"
            view.body = "在设置里允许智慧勺使用蓝牙，然后再扫描。"
            view.nextStep = "下一步：前往设置允许蓝牙"
            view.primary = "打开设置"
            view.primaryId = .settings
            view.showDisconnect = false
        case .bluetoothOff:
            view.title = "蓝牙还没有打开"
            view.body = "在控制中心打开蓝牙，然后再扫描。"
            view.nextStep = "下一步：打开蓝牙"
            view.primary = "重新扫描"
            view.primaryId = .scan
            view.showDisconnect = false
        case .unavailable:
            view.title = "这里没有蓝牙"
            view.body = "模拟器扫描不到附近的设备。用一台 iPhone 再扫描。"
            view.nextStep = "下一步：换到 iPhone"
            view.primary = "重新扫描"
            view.primaryId = .scan
            view.showDisconnect = false
        case .scanning:
            view.title = "正在扫描"
            view.body = "点一个才会连接。不会自动连上。"
            view.nextStep = "下一步：选择一个设备"
            view.primary = "正在扫描"
            view.primaryId = .wait
            view.primaryDisabled = true
            view.showDisconnect = false
            view.showProgress = true
        case .connectFailed:
            view.title = "没有连上"
            view.body = device.peripheralName.isEmpty ? "靠近后再选一次。" : "\(device.peripheralName)没有连上。靠近后再选一次。"
            view.nextStep = "下一步：重新扫描并选择设备"
            view.primary = "重新扫描"
            view.primaryId = .scan
            view.showDisconnect = false
        case .connecting:
            view.title = "正在连接"
            view.body = "请让餐具靠近手机。"
            view.nextStep = "请稍等"
            view.primary = "请稍等"
            view.primaryId = .wait
            view.primaryDisabled = true
            view.showDisconnect = false
        case .syncing:
            view.title = "正在同步"
            view.body = "请稍等片刻，不要关闭页面。"
            view.nextStep = "请稍等"
            view.primary = "正在同步"
            view.primaryId = .wait
            view.primaryDisabled = true
        case .disconnected:
            view.title = "连接已断开"
            view.body = "靠近餐具后重新连接。"
            view.nextStep = "下一步：重新连接"
            view.primary = "重新扫描"
            view.primaryId = .scan
            view.showDisconnect = false
        case .syncFailed:
            view.title = "同步没有完成"
            view.body = "记录还在，可以再试一次。"
            view.nextStep = "下一步：再次同步"
            view.primary = "再次同步"
            view.primaryId = .sync
        case .connected:
            let title = device.peripheralName.isEmpty ? "已连接" : device.peripheralName
            view.title = title
            if !device.speaksSpoon {
                view.body = "还不是智慧勺。这份连接不会记餐，也不会写入热量。"
                view.nextStep = "下一步：靠近智慧勺，重新扫描并选中它。"
                view.primary = "重新扫描"
                view.primaryId = .scan
                view.canCalibrate = false
            } else if !device.spoonLinked {
                view.body = "已找到智慧勺，还没有收到电量或餐头。"
                view.nextStep = "下一步：等它发来一包数据。没有数据就不会记餐。"
                view.primary = "同步设备记录"
                view.primaryId = .sync
            } else {
                view.body = device.calibrated ? "当前是\(headLabel)。记录可以同步。" : "当前是\(headLabel)。还需要完成一次校准。"
                view.nextStep = device.calibrated ? "" : "下一步：完成校准"
                view.primary = "同步设备记录"
                view.primaryId = .sync
            }
        }
        if language == .en {
            view.title = L10n.text(view.title, .en)
            view.body = L10n.text(view.body, .en)
            view.nextStep = L10n.text(view.nextStep, .en)
            view.primary = L10n.text(view.primary, .en)
        }
        return view
    }

    static func profileSummary(_ state: AppState, language: AppLanguage = .zh) -> String {
        var bits: [String] = []
        if !state.profile.heightCm.isEmpty { bits.append("\(state.profile.heightCm) cm") }
        if !state.profile.weightKg.isEmpty { bits.append("\(state.profile.weightKg) kg") }
        if !state.profile.goal.isEmpty, state.profile.goal != "暂不设定" { bits.append(L10n.text(state.profile.goal, language)) }
        if bits.isEmpty { return L10n.text("还未填写，不影响记录", language) }
        return bits.joined(separator: " · ")
    }
}
