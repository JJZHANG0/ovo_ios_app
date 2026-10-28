# Spoon Link

This is the contract the spoon firmware implements. The iOS app parses only this framing. UUIDs are an app-side definition until the hardware confirms them. Change them in this file and in `ZhiWeiShao/Model/SpoonLink.swift` together. The Swift file is what the app uses.

The phone does not connect by itself. It scans, lists name and signal, and connects only after a person picks a row. Battery, the current head, and meals change only when a packet below checks out. Any other device can stay connected and is shown as not a spoon yet. That link does not create a meal or a calorie.

No Bluetooth background mode. The session is foreground only. The app does not capture the lock screen.

## GATT

| Role | UUID |
|---|---|
| Service | `6C2E0001-5B4A-4E3F-8D2C-1A0B9E8D7C6B` |
| Device status, notify | `6C2E0002-5B4A-4E3F-8D2C-1A0B9E8D7C6B` |
| Meal event, notify | `6C2E0003-5B4A-4E3F-8D2C-1A0B9E8D7C6B` |
| Sync, write | `6C2E0004-5B4A-4E3F-8D2C-1A0B9E8D7C6B` |

Status notifications carry battery and head. Meal notifications carry meal start, a sample, and meal end. The phone writes a sync request to the sync characteristic. The spoon answers by notifying the same meal packets again. A repeated meal id does not create a second meal.

Packets may be longer than the default 20-byte ATT payload. The spoon should request a larger MTU. A truncated notify fails the length check and is ignored.

## Frame

Little-endian. Every packet is:

| Offset | Size | Field |
|---|---|---|
| 0 | 1 | Version. This document is version `1`. Any other version is rejected. |
| 1 | 1 | Type |
| 2 | 4 | Time, Unix seconds, UTC |
| 6 | 2 | Payload length, in bytes |
| 8 | length | Payload |
| 8 + length | 1 | Checksum, XOR of every preceding byte |

The byte count must be `9 + length`. A bad checksum, a bad length, or a bad payload for a known type is not applied.

## Types

| Type | Name | Where | Payload |
|---|---|---|---|
| `0x01` | Meal start | Meal notify | `u32` meal id |
| `0x02` | Sample | Meal notify | `u32` meal id, `i16` grams, `u8` flags |
| `0x03` | Meal end | Meal notify | `u32` meal id, `u16` duration in seconds |
| `0x04` | Battery | Status notify | `u8` percent, 0 through 100 |
| `0x05` | Head | Status notify | `u8` head |
| `0x10` | Sync request | Phone writes this | empty |

Sample flags: bit 0 set means this sample is a bite. Other bits are reserved and ignored. Grams are whole grams, and may be negative. There is no kilocalorie field. The app does not invent calories from weight.

Head values: `0` none, `1` spoon, `2` fork. Any other value is rejected.

Unknown types with a valid frame are ignored. They do not change battery, head, meals, or calories.

A sample or a meal end for an unknown meal id does not create a meal. A meal start for an id that already exists does not create another meal.

## Example

Battery 82% at Unix time 0:

```
01 04 00 00 00 00 01 00 52 56
```

`0x52` is 82. `0x56` is the checksum. The phone will not treat a nearby device as a spoon until it notifies on the service above with a frame like this.
