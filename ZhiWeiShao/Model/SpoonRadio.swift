import CoreBluetooth
import Foundation

/// CoreBluetooth session. The manager is created on the first scan tap, not at launch.
/// Nothing here connects until `connect(id:)` — that is only called from a row the user taps.
final class SpoonRadio: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private weak var store: AppStore?
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var connected: CBPeripheral?
    private var syncCharacteristic: CBCharacteristic?

    func attach(_ store: AppStore) {
        self.store = store
    }

    func start() {
        if central == nil {
            central = CBCentralManager(
                delegate: self,
                queue: nil,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
            return
        }
        apply(central?.state ?? .unknown)
    }

    func connect(id: UUID) {
        guard let central, let peripheral = peripherals[id] else { return }
        central.stopScan()
        connected = peripheral
        syncCharacteristic = nil
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        let name = displayName(peripheral)
        Task { @MainActor in
            self.store?.radioConnecting(name: name)
        }
    }

    func disconnect() {
        guard let central, let connected else { return }
        central.cancelPeripheralConnection(connected)
    }

    func writeSync() {
        guard let connected, let syncCharacteristic else { return }
        let packet = SpoonLink.syncRequest()
        connected.writeValue(packet, for: syncCharacteristic, type: .withResponse)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        apply(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals[peripheral.identifier] = peripheral
        let name = advertisedName(peripheral, advertisementData)
        let rssi = RSSI.intValue
        let id = peripheral.identifier
        Task { @MainActor in
            self.store?.radioDiscovered(id: id, name: name, rssi: rssi)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        syncCharacteristic = nil
        peripheral.discoverServices([SpoonLink.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let name = displayName(peripheral)
        Task { @MainActor in
            self.store?.radioConnectFailed(name: name)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connected?.identifier == peripheral.identifier {
            connected = nil
            syncCharacteristic = nil
        }
        Task { @MainActor in
            self.store?.radioDisconnected()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let name = displayName(peripheral)
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == SpoonLink.service }) else {
            Task { @MainActor in
                self.store?.radioForeignDevice(name: name)
            }
            return
        }
        Task { @MainActor in
            self.store?.radioFoundSpoonService(name: name)
        }
        peripheral.discoverCharacteristics([SpoonLink.status, SpoonLink.meal, SpoonLink.sync], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, service.uuid == SpoonLink.service else { return }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == SpoonLink.sync {
                syncCharacteristic = characteristic
            }
            if characteristic.uuid == SpoonLink.status || characteristic.uuid == SpoonLink.meal {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        guard characteristic.uuid == SpoonLink.status || characteristic.uuid == SpoonLink.meal else { return }
        guard let packet = SpoonLink.parse(data) else { return }
        Task { @MainActor in
            self.store?.radioPacket(packet)
        }
    }

    private func apply(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            beginScan()
        case .unauthorized:
            Task { @MainActor in self.store?.radioPermissionDenied() }
        case .poweredOff:
            central?.stopScan()
            Task { @MainActor in self.store?.radioPoweredOff() }
        case .unsupported:
            Task { @MainActor in self.store?.radioUnavailable() }
        case .resetting, .unknown:
            break
        @unknown default:
            break
        }
    }

    private func beginScan() {
        peripherals = [:]
        Task { @MainActor in
            self.store?.radioScanStarted()
        }
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func advertisedName(_ peripheral: CBPeripheral, _ advertisement: [String: Any]) -> String {
        if let local = advertisement[CBAdvertisementDataLocalNameKey] as? String, !local.isEmpty {
            return local
        }
        return displayName(peripheral)
    }

    private func displayName(_ peripheral: CBPeripheral) -> String {
        if let name = peripheral.name, !name.isEmpty { return name }
        return ""
    }
}
