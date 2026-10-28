import SwiftUI

struct BindView: View {
    @Environment(AppStore.self) private var store

    private var device: DeviceState { store.state.device }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("扫描"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                Text(store.t("附近的设备"))
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
                Text(store.t("点一个才会连接。不会自动连上。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(statusLine)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 28)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ble-status")

                if !device.note.isEmpty {
                    QuietNote(text: store.t(device.note))
                        .padding(.top, 8)
                        .accessibilityIdentifier("ble-next")
                }

                if store.nearby.isEmpty {
                    Text(store.t("还没有发现设备"))
                        .font(.system(size: 22, weight: .regular))
                        .padding(.top, 28)
                        .accessibilityIdentifier("ble-empty")
                    QuietNote(text: store.t("这里只列出真实的附近设备。"))
                        .padding(.top, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.nearby) { device in
                            Button {
                                store.connectNearby(device.id)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(device.name == "未命名" ? store.t("未命名") : device.name)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(Palette.ink)
                                    Spacer(minLength: 12)
                                    Text("\(device.rssi) dBm")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Palette.secondary)
                                        .monospacedDigit()
                                }
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("ble-device-\(device.id.uuidString)")
                            Hairline()
                        }
                    }
                    .padding(.top, 16)
                }

                if device.phase == .permissionOff {
                    PrimaryButton(title: store.t("打开设置"), identifier: "ble-settings") {
                        store.openSettings()
                    }
                    .padding(.top, 28)
                } else if device.phase != .connecting {
                    PrimaryButton(title: store.t("重新扫描"), identifier: "ble-rescan") {
                        store.startScan()
                    }
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .accessibilityIdentifier("ble-scan")
        .onAppear { store.startScan() }
    }

    private var statusLine: String {
        switch device.phase {
        case .permissionOff:
            return store.t("在设置里允许智慧勺使用蓝牙，然后再扫描。")
        case .bluetoothOff:
            return store.t("在控制中心打开蓝牙，然后再扫描。")
        case .unavailable:
            return store.t("模拟器扫描不到附近的设备。用一台 iPhone 再扫描。")
        case .connecting:
            return store.t("正在连接")
        case .connectFailed:
            return store.t("没有连上")
        case .scanning:
            return store.t("正在扫描")
        default:
            return store.t("正在请求蓝牙")
        }
    }
}

struct DeviceView: View {
    var focus: DeviceFocus
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var showCal = false

    var body: some View {
        let today = ZWFormat.formatISODate(Date())
        let vm = Present.device(store.state, today: today, language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Image("ProductSpoon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 96)
                        .frame(maxWidth: .infinity)
                    Text(vm.title)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Palette.ink)
                    Text(vm.body)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    if !vm.nextStep.isEmpty {
                        Text(vm.nextStep)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 2)
                            .accessibilityIdentifier("device-next")
                    }
                    if !vm.note.isEmpty, vm.note != vm.nextStep, !vm.note.hasPrefix("Next:"), !vm.note.hasPrefix("下一步") {
                        QuietNote(text: vm.note)
                    }
                    if vm.showProgress {
                        ProgressView(value: Double(vm.progress), total: 100)
                            .tint(Palette.ink)
                            .padding(.top, 6)
                    }
                    if vm.canCalibrate && !vm.calibrated {
                        PrimaryButton(title: store.t("完成校准"), identifier: "device-calibrate") {
                            store.calibrate()
                            showCal = false
                        }
                        .padding(.top, 16)
                    } else {
                        PrimaryButton(title: vm.primary, enabled: !vm.primaryDisabled, identifier: "device-primary") {
                            onPrimary(vm)
                        }
                        .padding(.top, 16)
                    }
                    if vm.showDisconnect {
                        QuietButton(title: store.t("断开连接"), identifier: "device-disconnect") {
                            store.disconnect()
                        }
                    }
                    spec(store.t("电量"), vm.showBattery ? vm.batteryText : "—")
                        .padding(.top, 8)
                    spec(store.t("当前餐头"), vm.headLabel)
                    spec(store.t("同步"), vm.syncText)
                    spec(store.t("待同步"), vm.pendingText)
                }
                .padding(20)
                .background { GlassShape(radius: 28) }
                .overlay { ConnectionAura(phase: vm.phase, radius: 28) }

                if vm.canCalibrate && !vm.calibrated {
                    Text(store.t("校准"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 32)
                    Text(store.t("将餐具平放在桌面上，停稳后再完成。"))
                        .font(.system(size: 15, weight: .regular))
                        .padding(.top, 8)
                } else if showCal && vm.canCalibrate {
                    Text(store.t("校准"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 32)
                    Text(store.t("将餐具平放在桌面上，停稳后再完成。"))
                        .font(.system(size: 15, weight: .regular))
                        .padding(.top, 8)
                    QuietButton(title: store.t("完成校准"), identifier: "device-recalibrate") {
                        store.calibrate()
                        showCal = false
                    }
                    .padding(.top, 14)
                } else if vm.calibrated && vm.canCalibrate {
                    Text(store.t("校准"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 32)
                    Text(store.t("已经校准过。"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 6)
                    TextAction(title: store.t("重新校准")) { showCal = true }
                }

                Text(store.t("保养"))
                    .font(.system(size: 17, weight: .regular))
                    .padding(.top, 28)
                Text(vm.maintenance)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 6)

                Text(store.t("同步"))
                    .font(.system(size: 17, weight: .regular))
                    .padding(.top, 28)
                Text(store.t("查看同步失败时的提示。不会新增餐次。"))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 6)
                QuietButton(title: store.t("查看同步失败"), identifier: "device-fail") {
                    Task { await store.showSyncFailure() }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .onAppear {
            if focus == .calibrate || focus == .sync { showCal = focus == .calibrate }
        }
    }

    private func spec(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12)
            Hairline()
        }
    }

    private func onPrimary(_ vm: DeviceVM) {
        switch vm.primaryId {
        case .bind, .reconnect, .scan:
            store.startScan()
            path?.wrappedValue.append(AppRoute.bind)
        case .permission, .settings:
            store.openSettings()
        case .sync:
            Task { await store.sync() }
        case .wait:
            break
        }
    }
}

struct MealLiveView: View {
    var mealId: String
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var ending = false

    var body: some View {
        let head = Present.headName(store.state.device.head, language: store.language)
        let calibrated = store.t(store.state.device.calibrated ? "已校准" : "未校准")
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("安心吃饭，餐后再看"))
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Palette.ink)
                            .frame(width: 7, height: 7)
                        Text(store.t("记录中"))
                            .font(.system(size: 16, weight: .regular))
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(ZWFormat.formatTimer(elapsed(at: context.date)))
                            .font(.system(size: 56, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                    Text("\(head) · \(calibrated)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    QuietNote(text: store.t("热量在餐后整理，吃饭时不会逐口提醒。"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background { GlassShape(radius: 28) }
                .overlay { ConnectionAura(phase: .connected, radius: 28) }
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: store.t(ending ? "正在整理记录" : "结束并查看本餐"), enabled: !ending, identifier: "end-meal") {
                guard !ending else { return }
                ending = true
                store.endMeal(mealId: mealId)
                if let path {
                    var value = path.wrappedValue
                    if !value.isEmpty { value.removeLast() }
                    value.append(AppRoute.mealDetail(mealId))
                    path.wrappedValue = value
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .accessibilityIdentifier("meal-live")
    }

    private func elapsed(at date: Date) -> Int {
        guard let meal = store.state.meals.first(where: { $0.id == mealId }) else { return 0 }
        if meal.status == .recording {
            return max(0, Int((date.timeIntervalSince1970 - meal.startedAt / 1000).rounded()))
        }
        return meal.durationSec
    }
}

struct MealDetailView: View {
    var mealId: String
    @Environment(AppStore.self) private var store
    @Environment(\.navPath) private var path
    @State private var eventsOpen = false

    var body: some View {
        let vm = Present.detail(store.state, mealId: mealId, language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !vm.dateLine.isEmpty {
                    Text(vm.dateLine)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                }
                Text(vm.name)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 4)
                KcalFigure(mode: vm.heroMode, text: vm.heroText, size: 44, unitSize: 13)
                    .padding(.top, 12)
                    .accessibilityIdentifier("detail-hero")
                if !vm.rangeText.isEmpty {
                    Text(vm.rangeText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 8)
                }
                if !vm.checkNote.isEmpty {
                    QuietNote(text: vm.checkNote).padding(.top, 6)
                }
                if !vm.estimateNote.isEmpty {
                    QuietNote(text: vm.estimateNote).padding(.top, 6)
                }
                if !vm.bites.isEmpty || !vm.duration.isEmpty {
                    Text([vm.bites, vm.duration].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 10)
                }

                if !vm.foods.isEmpty {
                    Text(store.t("食物组成"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 32)
                    VStack(spacing: 0) {
                        ForEach(Array(vm.foods.enumerated()), id: \.element.id) { index, food in
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name)
                                        .font(.system(size: 16, weight: .regular))
                                    Text(food.portion)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Palette.secondary)
                                }
                                Spacer()
                                Text(food.kcalText)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(food.muted ? Palette.secondary : Palette.ink)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 14)
                            if index < vm.foods.count - 1 { Hairline() }
                        }
                    }
                }

                if !vm.checks.isEmpty {
                    Text(store.t("需要核对"))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.top, 28)
                    VStack(spacing: 0) {
                        ForEach(Array(vm.checks.enumerated()), id: \.element.id) { index, check in
                            Button {
                                path?.wrappedValue.append(AppRoute.correction(mealId: mealId, foodId: check.id))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(check.question)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundStyle(Palette.ink)
                                            .multilineTextAlignment(.leading)
                                        Text(check.resolved ? "\(check.choice) · \(store.t("可以再次修改"))" : check.choice)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundStyle(Palette.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Palette.tertiary)
                                }
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("check-\(check.id)")
                            if index < vm.checks.count - 1 { Hairline() }
                        }
                    }
                }

                TextAction(title: store.t("补录食物")) {
                    path?.wrappedValue.append(AppRoute.addEntry(mealId: mealId, date: ""))
                }
                .padding(.top, 12)
                .accessibilityIdentifier("add-food")

                if !vm.events.isEmpty {
                    Button {
                        eventsOpen.toggle()
                    } label: {
                        HStack {
                            Text(store.t(eventsOpen ? "收起进食过程" : "查看进食过程"))
                                .font(.system(size: 16, weight: .regular))
                            Spacer()
                            Image(systemName: eventsOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.tertiary)
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    if eventsOpen {
                        ForEach(vm.events) { event in
                            HStack(alignment: .firstTextBaseline) {
                                Text(event.time)
                                    .font(.system(size: 14, weight: .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Text(event.note)
                                    .font(.system(size: 15, weight: .regular))
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
}

struct CorrectionView: View {
    var mealId: String
    var foodId: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedId = ""

    var body: some View {
        let vm = Present.correction(store.state, mealId: mealId, foodId: foodId, language: store.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !vm.mealName.isEmpty {
                    Text("\(vm.mealName) · \(vm.foodName)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                }
                Text(vm.prompt)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 6)
                QuietNote(text: store.t("选择一项后，本餐合计会跟着更新。可以稍后再次修改。"))
                    .padding(.top, 10)
                VStack(spacing: 0) {
                    ForEach(vm.options) { option in
                        Button {
                            selectedId = option.id
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                if selectedId == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("option-\(option.id)")
                        Hairline()
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: store.t("保存并更新本餐"), enabled: !selectedId.isEmpty && !vm.missing, identifier: "save-correction") {
                guard !selectedId.isEmpty, !vm.missing else { return }
                store.saveCorrection(mealId: mealId, foodId: foodId, optionId: selectedId)
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .onAppear {
            if selectedId.isEmpty { selectedId = vm.choiceId }
        }
    }
}

struct AddEntryView: View {
    var mealId: String
    var date: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var portion = ""
    @State private var chosenDate = ""
    @State private var time = ""
    @State private var mealName = "加餐"
    @State private var error = ""

    private let mealNames = ["早餐", "午餐", "晚餐", "加餐"]
    private var lockedMeal: Meal? {
        guard !mealId.isEmpty else { return nil }
        return store.state.meals.first { $0.id == mealId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("补录"))
                    .font(.system(size: 34, weight: .regular))
                Text(store.t("饮品、零食，或餐具没有记下的食物，都可以补在这里。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 8)
                if let meal = lockedMeal {
                    QuietNote(text: store.t("加入\(meal.name)"))
                        .padding(.top, 8)
                }
                FieldLabel(text: store.t("食物名称")).padding(.top, 28)
                LineField(placeholder: store.t("例如 苹果、黑咖啡"), text: $name)
                FieldLabel(text: store.t("分量")).padding(.top, 20)
                LineField(placeholder: store.t("例如 1 个，可不填"), text: $portion)
                QuietNote(text: store.t("不填分量，或还不能估算的食物，会保持待估算。"))
                    .padding(.top, 8)

                if lockedMeal == nil {
                    FieldLabel(text: store.t("日期")).padding(.top, 20)
                    Text(L10n.dateLine(chosenDate.isEmpty ? ZWFormat.formatISODate(Date()) : chosenDate, week: true, store.language))
                        .font(.system(size: 17, weight: .regular))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) { Hairline() }
                        .overlay {
                            DatePicker("", selection: dateBinding, displayedComponents: .date)
                                .labelsHidden()
                                .colorMultiply(.clear)
                        }
                    FieldLabel(text: store.t("餐次")).padding(.top, 20)
                    Picker(store.t("餐次"), selection: $mealName) {
                        ForEach(mealNames, id: \.self) { Text(store.t($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)
                }

                FieldLabel(text: store.t("时间")).padding(.top, 20)
                Text(time.isEmpty ? ZWFormat.formatClock(Date()) : time)
                    .font(.system(size: 17, weight: .regular))
                    .monospacedDigit()
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Hairline() }
                    .overlay {
                        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorMultiply(.clear)
                    }
                if !error.isEmpty {
                    Text(store.t(error))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 12)
                }
                PrimaryButton(title: store.t(lockedMeal == nil ? "加入这条记录" : "保存并更新本餐"), identifier: "save-entry") {
                    save()
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            let now = Date()
            if let meal = lockedMeal {
                chosenDate = meal.date
                time = meal.time
                mealName = meal.name
            } else {
                chosenDate = date.isEmpty ? ZWFormat.formatISODate(now) : date
                time = ZWFormat.formatClock(now)
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { ZWFormat.parseISODate(chosenDate.isEmpty ? ZWFormat.formatISODate(Date()) : chosenDate) },
            set: { chosenDate = ZWFormat.formatISODate($0) }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let iso = chosenDate.isEmpty ? ZWFormat.formatISODate(Date()) : chosenDate
                let clock = time.isEmpty ? ZWFormat.formatClock(Date()) : time
                return Date(timeIntervalSince1970: ZWFormat.atTime(iso, clock) / 1000)
            },
            set: { time = ZWFormat.formatClock($0) }
        )
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            error = "请先写食物名称"
            return
        }
        _ = store.addFood(AddFoodInput(
            mealId: mealId,
            date: chosenDate,
            mealName: mealName,
            time: time,
            name: trimmed,
            portion: portion
        ))
        dismiss()
    }
}

struct PreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var height = ""
    @State private var weight = ""
    @State private var goal = ""
    private let goals = ["吃得更规律", "把每餐记完整", "清淡一些", "暂不设定"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("个人偏好"))
                    .font(.system(size: 34, weight: .regular))
                Text(store.t("都可以留空，不会拦住记录。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 8)
                FieldLabel(text: store.t("身高")).padding(.top, 28)
                LineField(placeholder: store.t("厘米，可不填"), text: $height)
                FieldLabel(text: store.t("体重")).padding(.top, 20)
                LineField(placeholder: store.t("公斤，可不填"), text: $weight)
                FieldLabel(text: store.t("想先关注什么")).padding(.top, 24)
                VStack(spacing: 0) {
                    ForEach(goals, id: \.self) { item in
                        Button {
                            goal = item
                        } label: {
                            HStack {
                                Text(store.t(item))
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                if goal == item {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        Hairline()
                    }
                }
                .padding(.top, 8)
                PrimaryButton(title: store.t("保存"), identifier: "save-profile") {
                    store.saveProfile(heightCm: height, weightKg: weight, goal: goal)
                    dismiss()
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            height = store.state.profile.heightCm
            weight = store.state.profile.weightKg
            goal = store.state.profile.goal
        }
    }
}

struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmDelete = false
    @State private var showExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                privacyBlock(store.t("用餐记录"), store.t("用来在这台手机上展示餐次、食物和习惯变化。"))
                privacyBlock(store.t("连接信息"), store.t("用来显示餐具是否连上、电量和餐头。不会在后台拍照，也不会持续上传画面。"))
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("模型训练"))
                        .font(.system(size: 17, weight: .regular))
                    Text(store.t("这是单独的选择，默认关闭。关闭时，记录只留在这台手机上。"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    HStack {
                        Text(store.t("允许用于模型训练"))
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.state.trainingConsent },
                            set: { store.setTrainingConsent($0) }
                        ))
                        .labelsHidden()
                        .tint(Palette.ink)
                    }
                    .padding(.top, 8)
                    Hairline()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("导出记录"))
                        .font(.system(size: 17, weight: .regular))
                    Text(store.t("导出还没有开放。"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    QuietButton(title: store.t("导出")) { showExport = true }
                        .padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("删除记录"))
                        .font(.system(size: 17, weight: .regular))
                    Text(store.t("删除这台手机上的用餐记录。设备绑定可以保留。"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Palette.secondary)
                    QuietButton(title: store.t("删除本机记录"), identifier: "delete-meals") { confirmDelete = true }
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .alert(store.t("导出记录"), isPresented: $showExport) {
            Button(store.t("知道了"), role: .cancel) {}
        } message: {
            Text(store.t("导出还没有开放。"))
        }
        .alert(store.t("删除本机记录"), isPresented: $confirmDelete) {
            Button(store.t("删除")) { store.deleteLocalMeals() }
            Button(store.t("取消"), role: .cancel) {}
        } message: {
            Text(store.t("这台手机上的用餐记录会被清掉。没有记录不会被显示成 0。"))
        }
    }

    private func privacyBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .regular))
            Text(body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MembershipView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.t("基础能力现在就可以用。付费方案还没有开放购买或续费。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 8)
                plan("基础", "正在使用", ["连接餐具", "记录用餐", "查看历史", "核对与补录"])
                plan("Plus", "未开通", ["完整趋势", "食谱工具", "更细的用餐回顾"])
                plan("Pro", "未开通", ["在 Plus 之上，支持更长时间的回顾"])
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func plan(_ title: String, _ status: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.t(title))
                    .font(.system(size: 22, weight: .regular))
                Spacer()
                Text(store.t(status))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.tertiary)
            }
            ForEach(lines, id: \.self) { line in
                Text(store.t(line))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Palette.ink)
            }
            Hairline().padding(.top, 12)
        }
        .padding(.top, 28)
    }
}
