import CoreBluetooth
import Foundation

/// Spoon Link UUIDs and packet framing.
/// Change these constants here and in `SpoonLink.md` together. Hardware has not confirmed them yet.
enum SpoonLink {
    static let serviceUUID = "6C2E0001-5B4A-4E3F-8D2C-1A0B9E8D7C6B"
    static let statusUUID = "6C2E0002-5B4A-4E3F-8D2C-1A0B9E8D7C6B"
    static let mealUUID = "6C2E0003-5B4A-4E3F-8D2C-1A0B9E8D7C6B"
    static let syncUUID = "6C2E0004-5B4A-4E3F-8D2C-1A0B9E8D7C6B"

    static var service: CBUUID { CBUUID(string: serviceUUID) }
    static var status: CBUUID { CBUUID(string: statusUUID) }
    static var meal: CBUUID { CBUUID(string: mealUUID) }
    static var sync: CBUUID { CBUUID(string: syncUUID) }

    static let version: UInt8 = 1
    static let typeMealStart: UInt8 = 0x01
    static let typeSample: UInt8 = 0x02
    static let typeMealEnd: UInt8 = 0x03
    static let typeBattery: UInt8 = 0x04
    static let typeHead: UInt8 = 0x05
    /// Host writes this type to the sync characteristic. The spoon answers on the meal characteristic.
    static let typeSync: UInt8 = 0x10

    static let headNone: UInt8 = 0
    static let headSpoon: UInt8 = 1
    static let headFork: UInt8 = 2

    /// A frame the checksum accepts. `nil` means the bytes are not a Spoon Link packet.
    /// `.ignored` is a valid frame whose type this app does not act on.
    static func parse(_ data: Data) -> SpoonPacket? {
        guard data.count >= 9 else { return nil }
        guard data[0] == version else { return nil }
        let type = data[1]
        let time = readU32(data, 2)
        let length = Int(readU16(data, 6))
        guard data.count == 8 + length + 1 else { return nil }
        let payload = data.subdata(in: 8..<(8 + length))
        var xor: UInt8 = 0
        for byte in data.dropLast() { xor ^= byte }
        guard xor == data[data.count - 1] else { return nil }
        let when = Date(timeIntervalSince1970: TimeInterval(time))
        switch type {
        case typeMealStart:
            guard payload.count == 4 else { return nil }
            return .mealStart(id: readU32(payload, 0), time: when)
        case typeSample:
            guard payload.count == 7 else { return nil }
            let grams = Int(Int16(bitPattern: readU16(payload, 4)))
            let bite = payload[6] & 0x01 == 0x01
            return .sample(id: readU32(payload, 0), time: when, grams: grams, bite: bite)
        case typeMealEnd:
            guard payload.count == 6 else { return nil }
            return .mealEnd(id: readU32(payload, 0), time: when, duration: Int(readU16(payload, 4)))
        case typeBattery:
            guard payload.count == 1, payload[0] <= 100 else { return nil }
            return .battery(percent: Int(payload[0]))
        case typeHead:
            guard payload.count == 1 else { return nil }
            switch payload[0] {
            case headNone: return .head(.none)
            case headSpoon: return .head(.spoon)
            case headFork: return .head(.fork)
            default: return nil
            }
        case typeSync:
            return .ignored(type: type)
        default:
            return .ignored(type: type)
        }
    }

    static func frame(type: UInt8, time: UInt32, payload: Data) -> Data {
        var data = Data()
        data.append(version)
        data.append(type)
        appendU32(time, to: &data)
        appendU16(UInt16(payload.count), to: &data)
        data.append(payload)
        var xor: UInt8 = 0
        for byte in data { xor ^= byte }
        data.append(xor)
        return data
    }

    static func syncRequest(time: UInt32 = UInt32(Date().timeIntervalSince1970)) -> Data {
        frame(type: typeSync, time: time, payload: Data())
    }

    static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    static func appendU16(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    static func appendU32(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }
}

enum SpoonPacket: Equatable {
    case mealStart(id: UInt32, time: Date)
    case sample(id: UInt32, time: Date, grams: Int, bite: Bool)
    case mealEnd(id: UInt32, time: Date, duration: Int)
    case battery(percent: Int)
    case head(UtensilHead)
    case ignored(type: UInt8)
}

struct NearbyDevice: Identifiable, Equatable {
    var id: UUID
    var name: String
    var rssi: Int
}
