import Foundation
import Observation
import UIKit

struct SyncOutcome: Equatable {
    var ok: Bool
    var message: String
    var added: Int
}

@MainActor
@Observable
final class AppStore {
    private(set) var state: AppState
    var bag: [BagLine]
    var toast: String?
    var nearby: [NearbyDevice] = []
    let radio = SpoonRadio()

    private var syncLock = false
    private var finishTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    private static let storageKey = "zhiweishao.store.v1"
    private static let bagKey = "zhiweishao.bag.v1"
    private static let languageKey = "zhiweishao.language.v1"
    var language: AppLanguage

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-reset-store") {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            UserDefaults.standard.removeObject(forKey: Self.bagKey)
            UserDefaults.standard.removeObject(forKey: Self.languageKey)
        }
        if let saved = Self.load(), saved.version == 1 {
            var next = saved
            let now = ZWFormat.nowMS()
            for meal in next.meals where meal.status == .settling {
                next = Logic.applyFinishMeal(next, mealId: meal.id, now: now)
            }
            state = Logic.dropLiveLink(next)
        } else {
            state = Logic.createInitial(Date())
        }
        bag = Self.loadBag()
        if let index = arguments.firstIndex(of: "-language"), arguments.indices.contains(index + 1),
           let forced = AppLanguage(rawValue: arguments[index + 1]) {
            language = forced
        } else {
            language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.languageKey) ?? "") ?? .en
        }
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        radio.attach(self)
        persist()
    }

    func t(_ source: String) -> String {
        L10n.text(source, language)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    func setHideCalories(_ on: Bool) {
        state.hideCalories = on
        persist()
    }

    func setTrainingConsent(_ on: Bool) {
        state.trainingConsent = on
        persist()
    }

    func saveProfile(heightCm: String, weightKg: String, goal: String) {
        state.profile.heightCm = heightCm.trimmingCharacters(in: .whitespacesAndNewlines)
        state.profile.weightKg = weightKg.trimmingCharacters(in: .whitespacesAndNewlines)
        state.profile.goal = goal
        persist()
    }

    func startScan() {
        radio.start()
    }

    func connectNearby(_ id: UUID) {
        radio.connect(id: id)
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func radioScanStarted() {
        nearby = []
        state = Logic.applyScanning(state)
        persist()
    }

    func radioDiscovered(id: UUID, name: String, rssi: Int) {
        let shown = name.isEmpty ? "未命名" : name
        if let index = nearby.firstIndex(where: { $0.id == id }) {
            nearby[index].name = shown
            nearby[index].rssi = rssi
        } else {
            nearby.append(NearbyDevice(id: id, name: shown, rssi: rssi))
        }
        nearby.sort { $0.rssi > $1.rssi }
    }

    func radioConnecting(name: String) {
        state = Logic.applyConnecting(state, name: name)
        persist()
    }

    func radioConnectFailed(name: String) {
        state = Logic.applyConnectFailed(state, name: name)
        persist()
    }

    func radioDisconnected() {
        state = Logic.applyDisconnect(state)
        persist()
    }

    func radioPermissionDenied() {
        nearby = []
        state = Logic.applyDenyBluetooth(state)
        persist()
    }

    func radioPoweredOff() {
        nearby = []
        state = Logic.applyBluetoothOff(state)
        persist()
    }

    func radioUnavailable() {
        nearby = []
        state = Logic.applyRadioUnavailable(state)
        persist()
    }

    func radioForeignDevice(name: String) {
        let before = state.meals
        state = Logic.applyForeignLink(state, name: name)
        state.meals = before
        persist()
    }

    func radioFoundSpoonService(name: String) {
        state = Logic.applySpoonService(state, name: name)
        persist()
    }

    func radioPacket(_ packet: SpoonPacket) {
        state = Logic.applySpoonPacket(state, packet, now: ZWFormat.nowMS())
        persist()
    }

    func calibrate() {
        state = Logic.applyCalibrated(state)
        persist()
    }

    func disconnect() {
        radio.disconnect()
        state = Logic.applyDisconnect(state)
        persist()
    }

    func setHead(_ head: UtensilHead) {
        guard state.device.spoonLinked else { return }
        state = Logic.applyHead(state, head: head)
        persist()
    }

    func sync() async -> SyncOutcome {
        if syncLock { return SyncOutcome(ok: false, message: "请稍等，正在处理。", added: 0) }
        syncLock = true
        defer { syncLock = false }
        return await runSync()
    }

    private func runSync() async -> SyncOutcome {
        let phase = state.device.phase
        if phase == .disconnected {
            return SyncOutcome(ok: false, message: "连接已断开，请先重新连接。", added: 0)
        }
        if phase == .unbound || phase == .permissionOff || phase == .bluetoothOff || phase == .unavailable || phase == .connectFailed || phase == .scanning {
            return SyncOutcome(ok: false, message: "请先连接餐具。", added: 0)
        }
        if !state.device.speaksSpoon {
            return SyncOutcome(ok: false, message: "这还不是智慧勺，不会新增餐次。", added: 0)
        }
        if phase == .connecting || phase == .syncing {
            return SyncOutcome(ok: false, message: "请稍等，正在处理。", added: 0)
        }
        if state.device.failNextSync {
            state = Logic.applySyncFailure(state)
            persist()
            return SyncOutcome(ok: false, message: "同步没有完成", added: 0)
        }
        patchDevice { device in
            device.phase = .syncing
            device.progress = 50
        }
        radio.writeSync()
        patchDevice { device in
            device.phase = .connected
            device.progress = 100
            device.note = "已请求同步。餐次只在收到数据包时更新。"
        }
        flash("已请求同步")
        return SyncOutcome(ok: true, message: "已请求同步", added: 0)
    }

    func showSyncFailure() async {
        let phase = state.device.phase
        if phase != .connected && phase != .syncFailed {
            state = Logic.applySyncFailure(state)
            persist()
            return
        }
        state.device.failNextSync = true
        if phase == .syncFailed { state.device.phase = .connected }
        persist()
        _ = await sync()
    }

    func startMeal() -> MealStart {
        if let step = Logic.mealStartStep(state) {
            return .blocked(step)
        }
        let started = Logic.applyStartMeal(state, now: ZWFormat.nowMS())
        state = started.state
        persist()
        return .started(started.meal.id)
    }

    func endMeal(mealId: String) {
        let now = ZWFormat.nowMS()
        state = Logic.applyEndMeal(state, mealId: mealId, now: now)
        persist()
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !Task.isCancelled else { return }
            guard Logic.findMeal(self.state, mealId: mealId)?.status == .settling else { return }
            self.state = Logic.applyFinishMeal(self.state, mealId: mealId, now: ZWFormat.nowMS())
            self.persist()
        }
    }

    func saveCorrection(mealId: String, foodId: String, optionId: String) {
        state = Logic.applyCorrection(state, mealId: mealId, foodId: foodId, optionId: optionId, now: ZWFormat.nowMS())
        persist()
        flash("已更新本餐")
    }

    func addFood(_ input: AddFoodInput) -> (mealId: String, pending: Bool) {
        let result = Logic.applyAddEntry(state, input: input, now: ZWFormat.nowMS())
        state = result.state
        persist()
        flash(result.pending ? "已记下，待估算" : "已加入记录")
        return (result.mealId, result.pending)
    }

    func deleteLocalMeals() {
        state = Logic.clearMeals(state)
        persist()
        flash("记录已删除")
    }

    func resetRecords() {
        finishTask?.cancel()
        state = Logic.createInitial(Date())
        persist()
    }

    func addToBag(productId: String) {
        if let index = bag.firstIndex(where: { $0.productId == productId }) {
            bag[index].quantity += 1
        } else {
            bag.append(BagLine(productId: productId, quantity: 1))
        }
        persistBag()
        flash("已放入购物袋")
    }

    func bagCount() -> Int {
        bag.reduce(0) { $0 + $1.quantity }
    }

    func flash(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard let self, !Task.isCancelled, self.toast == text else { return }
            self.toast = nil
        }
    }

    private func patchDevice(_ body: (inout DeviceState) -> Void) {
        body(&state.device)
        persist()
    }

    private func persist() {
        guard !ProcessInfo.processInfo.arguments.contains("-reset-store") else { return }
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func persistBag() {
        guard !ProcessInfo.processInfo.arguments.contains("-reset-store") else { return }
        if let data = try? JSONEncoder().encode(bag) {
            UserDefaults.standard.set(data, forKey: Self.bagKey)
        }
    }

    private static func load() -> AppState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: data)
    }

    private static func loadBag() -> [BagLine] {
        guard let data = UserDefaults.standard.data(forKey: bagKey),
              let lines = try? JSONDecoder().decode([BagLine].self, from: data) else { return [] }
        return lines
    }
}
