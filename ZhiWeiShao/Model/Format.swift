import Foundation

enum ZWFormat {
    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }()

    static func nowMS(_ date: Date = Date()) -> Double {
        date.timeIntervalSince1970 * 1000
    }

    static func formatISODate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func parseISODate(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        let year = parts.count > 0 ? parts[0] : 1970
        let month = parts.count > 1 ? parts[1] : 1
        let day = parts.count > 2 ? parts[2] : 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static func shiftDate(_ iso: String, days: Int) -> String {
        let date = parseISODate(iso)
        let shifted = calendar.date(byAdding: .day, value: days, to: date) ?? date
        return formatISODate(shifted)
    }

    static func mondayOf(_ iso: String) -> String {
        let date = parseISODate(iso)
        let weekday = calendar.component(.weekday, from: date)
        let day = weekday - 1
        let delta = day == 0 ? -6 : 1 - day
        return shiftDate(iso, days: delta)
    }

    static func formatChineseDate(_ iso: String, withWeek: Bool) -> String {
        let date = parseISODate(iso)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let text = "\(month)月\(day)日"
        if !withWeek { return text }
        let weekday = calendar.component(.weekday, from: date) - 1
        let name = weekdays.indices.contains(weekday) ? weekdays[weekday] : ""
        return "\(text) · 周\(name)"
    }

    static func weekdayChar(_ iso: String) -> String {
        let weekday = calendar.component(.weekday, from: parseISODate(iso)) - 1
        return weekdays.indices.contains(weekday) ? weekdays[weekday] : ""
    }

    static func dayNumber(_ iso: String) -> String {
        "\(calendar.component(.day, from: parseISODate(iso)))"
    }

    static func formatClock(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    static func formatStamp(_ timestamp: Double, todayIso: String) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let iso = formatISODate(date)
        let clock = formatClock(date)
        if iso == todayIso { return "今天 \(clock)" }
        return "\(formatChineseDate(iso, withWeek: false)) \(clock)"
    }

    static func formatInt(_ value: Int) -> String {
        let negative = value < 0
        let digits = String(abs(value))
        var reversed = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { reversed.append(",") }
            reversed.append(character)
        }
        let text = String(reversed.reversed())
        return negative ? "-\(text)" : text
    }

    static func formatDuration(_ seconds: Int, manual: Bool) -> String {
        if manual, seconds <= 0 { return "手动补录" }
        if seconds < 60 { return "不到 1 分钟" }
        return "\(Int((Double(seconds) / 60).rounded())) 分钟"
    }

    static func formatTimer(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%02d:%02d", safe / 60, safe % 60)
    }

    static func atTime(_ iso: String, _ hm: String) -> Double {
        let dateParts = iso.split(separator: "-").compactMap { Int($0) }
        let timeParts = hm.split(separator: ":").compactMap { Int($0) }
        let year = dateParts.count > 0 ? dateParts[0] : 1970
        let month = dateParts.count > 1 ? dateParts[1] : 1
        let day = dateParts.count > 2 ? dateParts[2] : 1
        let hour = timeParts.count > 0 ? timeParts[0] : 0
        let minute = timeParts.count > 1 ? timeParts[1] : 0
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
        return nowMS(date)
    }

    static func joinRecorded(_ names: [String]) -> String {
        if names.isEmpty { return "没有记录" }
        if names.count == 1 { return "已记录\(names[0])" }
        if names.count == 2 { return "已记录\(names[0])与\(names[1])" }
        return "已记录\(names.dropLast().joined(separator: "、"))与\(names[names.count - 1])"
    }
}
