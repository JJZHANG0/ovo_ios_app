import Foundation

enum DevicePhase: String, Codable, Equatable {
    case unbound
    case permissionOff = "permission_off"
    case bluetoothOff = "bluetooth_off"
    case unavailable
    case scanning
    case connecting
    case connected
    case disconnected
    case connectFailed = "connect_failed"
    case syncing
    case syncFailed = "sync_failed"
}

enum UtensilHead: String, Codable, Equatable {
    case spoon
    case fork
    case none
}

enum MealStatus: String, Codable, Equatable {
    case recording
    case settling
    case ready
}

enum FoodSource: String, Codable, Equatable {
    case utensil
    case manual
}

struct CheckOption: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    /// nil keeps the current estimate.
    var kcal: Int?
}

struct FoodCheck: Codable, Equatable {
    var question: String
    var prompt: String
    var options: [CheckOption]
    var resolved: Bool
    var choiceId: String
}

struct FoodItem: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var portion: String
    var kcal: Int?
    var source: FoodSource
    var check: FoodCheck?
}

struct BiteEvent: Codable, Equatable, Identifiable {
    var time: String
    var note: String
    var id: String { "\(time)-\(note)" }
}

struct Meal: Codable, Equatable, Identifiable {
    var id: String
    var date: String
    var name: String
    var time: String
    var startedAt: Double
    var endedAt: Double?
    var durationSec: Int
    var biteCount: Int?
    var status: MealStatus
    var foods: [FoodItem]
    var brief: String
    var briefCount: Int
    var events: [BiteEvent]
    var updatedAt: Double
    var source: FoodSource
    var estimateNote: String
}

struct DeviceState: Codable, Equatable {
    var phase: DevicePhase
    var battery: Int?
    var head: UtensilHead
    var calibrated: Bool
    var lastSyncAt: Double?
    var pendingCount: Int
    var progress: Int
    var failNextSync: Bool
    var note: String
    var bluetoothOpened: Bool
    /// Advertised or GAP name of the peripheral the user chose.
    var peripheralName: String = ""
    /// True only after a valid Spoon Link packet. A foreign device stays false.
    var spoonLinked: Bool = false
    /// True when the Spoon Link GATT service is present. False for any other device.
    var speaksSpoon: Bool = false

    enum CodingKeys: String, CodingKey {
        case phase, battery, head, calibrated, lastSyncAt, pendingCount, progress, failNextSync, note, bluetoothOpened
        case peripheralName, spoonLinked, speaksSpoon
    }

    init(phase: DevicePhase, battery: Int?, head: UtensilHead, calibrated: Bool, lastSyncAt: Double?, pendingCount: Int, progress: Int, failNextSync: Bool, note: String, bluetoothOpened: Bool, peripheralName: String = "", spoonLinked: Bool = false, speaksSpoon: Bool = false) {
        self.phase = phase
        self.battery = battery
        self.head = head
        self.calibrated = calibrated
        self.lastSyncAt = lastSyncAt
        self.pendingCount = pendingCount
        self.progress = progress
        self.failNextSync = failNextSync
        self.note = note
        self.bluetoothOpened = bluetoothOpened
        self.peripheralName = peripheralName
        self.spoonLinked = spoonLinked
        self.speaksSpoon = speaksSpoon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decode(DevicePhase.self, forKey: .phase)
        battery = try c.decodeIfPresent(Int.self, forKey: .battery) ?? nil
        head = try c.decode(UtensilHead.self, forKey: .head)
        calibrated = try c.decode(Bool.self, forKey: .calibrated)
        lastSyncAt = try c.decodeIfPresent(Double.self, forKey: .lastSyncAt) ?? nil
        pendingCount = try c.decode(Int.self, forKey: .pendingCount)
        progress = try c.decode(Int.self, forKey: .progress)
        failNextSync = try c.decode(Bool.self, forKey: .failNextSync)
        note = try c.decode(String.self, forKey: .note)
        bluetoothOpened = try c.decode(Bool.self, forKey: .bluetoothOpened)
        peripheralName = try c.decodeIfPresent(String.self, forKey: .peripheralName) ?? ""
        spoonLinked = try c.decodeIfPresent(Bool.self, forKey: .spoonLinked) ?? false
        speaksSpoon = try c.decodeIfPresent(Bool.self, forKey: .speaksSpoon) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(phase, forKey: .phase)
        try c.encodeIfPresent(battery, forKey: .battery)
        try c.encode(head, forKey: .head)
        try c.encode(calibrated, forKey: .calibrated)
        try c.encodeIfPresent(lastSyncAt, forKey: .lastSyncAt)
        try c.encode(pendingCount, forKey: .pendingCount)
        try c.encode(progress, forKey: .progress)
        try c.encode(failNextSync, forKey: .failNextSync)
        try c.encode(note, forKey: .note)
        try c.encode(bluetoothOpened, forKey: .bluetoothOpened)
        try c.encode(peripheralName, forKey: .peripheralName)
        try c.encode(spoonLinked, forKey: .spoonLinked)
        try c.encode(speaksSpoon, forKey: .speaksSpoon)
    }
}

struct Profile: Codable, Equatable {
    var heightCm: String
    var weightKg: String
    var goal: String
}

struct AppState: Codable, Equatable {
    var version: Int
    var seedDate: String
    var meals: [Meal]
    var deletedIds: [String]
    var recordingMealId: String
    var device: DeviceState
    var hideCalories: Bool
    var trainingConsent: Bool
    var profile: Profile
}

enum StepAction: String, Codable, Equatable {
    case bind
    case permission
    case reconnect
    case calibrate
    case device
    case resume
}

enum MealStart: Equatable {
    case started(String)
    case blocked(NextStep)
}

struct NextStep: Equatable {
    var title: String
    var body: String
    var action: String
    var actionId: StepAction
}

struct AddFoodInput: Equatable {
    var mealId: String
    var date: String
    var mealName: String
    var time: String
    var name: String
    var portion: String
}

struct BagLine: Codable, Equatable, Identifiable {
    var productId: String
    var quantity: Int
    var id: String { productId }
}
