import Foundation

enum AppLanguage: String, Equatable {
    case en
    case zh
}

enum L10n {
    private static let weekZH = ["日", "一", "二", "三", "四", "五", "六"]
    private static let weekEN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let weekChip = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func text(_ source: String, _ language: AppLanguage) -> String {
        guard language == .en, !source.isEmpty else { return source }
        if let hit = english[source] { return hit }
        if let built = pattern(source) { return built }
        if source.contains("、") {
            let parts = source.split(separator: "、").map { String($0) }
            if parts.allSatisfy({ english[$0] != nil }) {
                return parts.map { english[$0] ?? $0 }.joined(separator: ", ")
            }
        }
        return source
    }

    static func dateLine(_ iso: String, week: Bool, _ language: AppLanguage) -> String {
        if language == .zh { return ZWFormat.formatChineseDate(iso, withWeek: week) }
        let date = ZWFormat.parseISODate(iso)
        let month = ZWFormat.calendar.component(.month, from: date)
        let day = ZWFormat.calendar.component(.day, from: date)
        let name = months.indices.contains(month - 1) ? months[month - 1] : ""
        let head = "\(name) \(day)"
        if !week { return head }
        return "\(head) · \(weekday(iso, chip: false))"
    }

    static func weekSpan(_ start: String, _ end: String, _ language: AppLanguage) -> String {
        "\(dateLine(start, week: false, language))–\(dateLine(end, week: false, language))"
    }

    static func weekday(_ iso: String, chip: Bool) -> String {
        let index = ZWFormat.calendar.component(.weekday, from: ZWFormat.parseISODate(iso)) - 1
        let table = chip ? weekChip : weekEN
        return table.indices.contains(index) ? table[index] : ""
    }

    static func weekdayZH(_ iso: String) -> String {
        let index = ZWFormat.calendar.component(.weekday, from: ZWFormat.parseISODate(iso)) - 1
        return weekZH.indices.contains(index) ? weekZH[index] : ""
    }

    static func meta(_ source: String, _ language: AppLanguage) -> String {
        guard language == .en else { return source }
        let parts = source.split(separator: "·", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return text(source, language) }
        return "\(parts[0]) · \(text(parts[1], language))"
    }

    static func recorded(_ source: String, _ language: AppLanguage) -> String {
        guard language == .en, source.hasPrefix("已记录") else { return text(source, language) }
        let rest = String(source.dropFirst("已记录".count))
        let halves = rest.split(separator: "与", maxSplits: 1).map { String($0) }
        var names: [String] = []
        if halves.count == 2 {
            names.append(contentsOf: halves[0].split(separator: "、").map { String($0) })
            names.append(halves[1])
        } else {
            names.append(rest)
        }
        let words = names.map { text($0, .en).lowercased() }
        switch words.count {
        case 0: return "Nothing recorded"
        case 1: return words[0].capitalized
        case 2: return "\(words[0].capitalized) and \(words[1])"
        default:
            let lead = words.dropLast().joined(separator: ", ")
            return "\(lead.prefix(1).uppercased() + lead.dropFirst()) and \(words.last ?? "")"
        }
    }

    static func savings(saved: Int?, hidden: Bool, _ language: AppLanguage) -> SavingsVM {
        guard !hidden, let saved, saved != 0 else { return .hidden }
        let figure = ZWFormat.formatInt(abs(saved))
        let baseline = ZWFormat.formatInt(TypicalMeal.baselineKcal)
        if language == .zh {
            if saved > 0 {
                return SavingsVM(visible: true, figure: figure, caption: "本月少下来的", detail: "相对一餐通常，\(baseline) kcal")
            }
            return SavingsVM(visible: true, figure: figure, caption: "本月多出来的", detail: "相对一餐通常，\(baseline) kcal")
        }
        if saved > 0 {
            return SavingsVM(visible: true, figure: figure, caption: "saved this month", detail: "versus a typical meal, \(baseline) kcal")
        }
        return SavingsVM(visible: true, figure: figure, caption: "above a typical meal", detail: "this month, \(baseline) kcal")
    }

    private static func pattern(_ source: String) -> String? {
        if let n = capture(source, prefix: "待核对", suffix: "项") {
            return n == "1" ? "1 to check" : "\(n) to check"
        }
        if let n = capture(source, prefix: "已同步 ", suffix: " 条记录") {
            return "Synced \(n)"
        }
        if let n = capture(source, prefix: "已同步 ", suffix: " 条记录。") {
            return "Synced \(n)."
        }
        if let n = capture(source, prefix: "还有 ", suffix: " 条记录待同步") {
            return "\(n) still to sync"
        }
        if source.hasPrefix("上次同步 ") {
            return "Last sync \(source.dropFirst("上次同步 ".count))"
        }
        if source.hasPrefix("估算区间 "), source.hasSuffix(" kcal") {
            let mid = source.dropFirst("估算区间 ".count).dropLast(" kcal".count)
            return "Range \(mid) kcal"
        }
        if let n = capture(source, prefix: "", suffix: " 口"), !n.isEmpty, Int(n) != nil {
            return "\(n) bites"
        }
        if let n = capture(source, prefix: "", suffix: " 分钟"), Int(n) != nil {
            return "\(n) min"
        }
        if source.hasPrefix("已连接 · "), source.hasSuffix("%") {
            return "Connected · \(source.dropFirst("已连接 · ".count))"
        }
        if source.hasPrefix("电量 "), source.hasSuffix("%") {
            return "Battery \(source.dropFirst("电量 ".count))"
        }
        if source.hasPrefix("电量 "), source.contains("已校准") {
            return source.replacingOccurrences(of: "电量 ", with: "Battery ").replacingOccurrences(of: "已校准", with: "calibrated")
        }
        if source.hasSuffix("已核对") {
            let name = String(source.dropLast("已核对".count))
            return "\(text(name, .en)) checked"
        }
        if source.hasPrefix("加入") {
            return "Into \(text(String(source.dropFirst(2)), .en))"
        }
        if source.hasPrefix("数量 ") {
            return "Qty \(source.dropFirst("数量 ".count))"
        }
        if source.hasPrefix("当前是"), source.contains("记录可以同步") {
            return "This head is on. Records can sync."
        }
        if source.hasPrefix("当前是"), source.contains("还需要完成一次校准") {
            return "This head is on. Calibrate once."
        }
        if source.hasSuffix(" · 还不是勺") {
            let name = String(source.dropLast(" · 还不是勺".count))
            return "\(name) · Not a spoon"
        }
        if source.hasSuffix("没有连上。靠近后再选一次。") {
            let name = String(source.dropLast("没有连上。靠近后再选一次。".count))
            if name.isEmpty { return "It did not connect. Move closer and choose it again." }
            return "\(name) did not connect. Move closer and choose it again."
        }
        if source.hasPrefix("一口 · "), source.hasSuffix(" g") {
            let grams = String(source.dropFirst("一口 · ".count).dropLast(" g".count))
            return "Bite · \(grams) g"
        }
        return nil
    }

    private static func capture(_ source: String, prefix: String, suffix: String) -> String? {
        guard source.hasPrefix(prefix), source.hasSuffix(suffix), source.count >= prefix.count + suffix.count else { return nil }
        let start = source.index(source.startIndex, offsetBy: prefix.count)
        let end = source.index(source.endIndex, offsetBy: -suffix.count)
        guard start <= end else { return nil }
        return String(source[start..<end])
    }

    private static let english: [String: String] = [
        "今天": "Today",
        "记录": "Record",
        "商城": "Shop",
        "我的": "Me",
        "开始": "Start",
        "继续": "Resume",
        "未绑定": "Not linked",
        "已连接": "Connected",
        "同步中": "Syncing",
        "同步失败": "Sync failed",
        "连接中": "Connecting",
        "已断开": "Disconnected",
        "蓝牙未开": "Bluetooth off",
        "今日已记录热量 · 估算": "Recorded today · estimate",
        "准备好，开始下一餐": "Ready for the next meal",
        "餐后查看记录，按需核对。": "Check the record after.",
        "这餐还在记录": "This meal is still open",
        "结束后再查看食物和热量。": "Review it when you finish.",
        "最近记录": "Recent",
        "全部记录": "All",
        "今天还没有记录": "Nothing today",
        "没有记录并不代表没有进食。": "An empty day is not zero.",
        "还没记的餐不会当成 0。": "Missing meals are not zero.",
        "这是已记下的估算，不是未记录。": "This is what was written down.",
        "还有食物待估算，所以先不显示合计。": "Some foods are still uncounted.",
        "还有餐次正在整理，没有算进合计。": "A meal is still settling.",
        "没有记录": "No record",
        "热量已隐藏": "Calories hidden",
        "已隐藏": "Hidden",
        "待估算": "To estimate",
        "餐后整理": "After the meal",
        "正在整理记录": "Settling",
        "已确认": "Confirmed",
        "记录中": "Recording",
        "用餐中": "In progress",
        "还没有食物": "No foods yet",
        "早餐": "Breakfast",
        "午餐": "Lunch",
        "晚餐": "Dinner",
        "加餐": "Extra",
        "燕麦酸奶": "Oat yogurt",
        "燕麦酸奶、鸡蛋、水果": "Oat yogurt, eggs, fruit",
        "鸡蛋": "Eggs",
        "水果": "Fruit",
        "拿铁": "Latte",
        "熟米饭": "Rice",
        "鸡胸肉": "Chicken",
        "蔬菜与配料": "Vegetables",
        "鸡肉蔬菜饭": "Chicken rice",
        "燕麦": "Oats",
        "牛奶": "Milk",
        "蔬菜": "Vegetables",
        "豆腐": "Tofu",
        "鸡腿": "Chicken leg",
        "米饭": "Rice",
        "鱼": "Fish",
        "约 1 碗": "About a bowl",
        "约 1 份": "One portion",
        "约 180 克": "About 180 g",
        "约 120 克": "About 120 g",
        "约 300 毫升": "About 300 ml",
        "约 250 毫升": "About 250 ml",
        "2 个": "2",
        "1 个": "1",
        "饮食日记": "Diary",
        "上一周": "Earlier",
        "下一周": "Later",
        "没有记录并不代表没有进食，也不会被算成 0。": "An empty day is not counted as zero.",
        "补记一餐": "Add a meal",
        "餐": "meals",
        "已留下的记录": "What was recorded",
        "餐次": "Meals",
        "补记": "Add",
        "选购": "Browse",
        "轻食，以及可以换上的餐具。": "Light meals, and utensils you can change.",
        "购物袋": "Bag",
        "包含": "Includes",
        "加入购物袋": "Add to bag",
        "没有找到这件商品": "This item is gone",
        "购物袋是空的": "Your bag is empty",
        "选好之后可以放进来。购买还没有开放。": "Add something when you are ready. Buying is not open.",
        "购买还没有开放。这里只是暂时放着，不会自动结算。": "Buying is not open. Nothing here checks out.",
        "继续浏览": "Keep browsing",
        "价格已包含在标价里。没有倒计时，也没有预先勾选的项目。": "The price is the price. No countdown, nothing pre-checked.",
        "替换勺头": "Spoon head",
        "备用不锈钢勺头，同一卡口。": "Spare steel spoon head, same mount.",
        "不锈钢勺头 · 1": "Steel spoon head · 1",
        "同一卡口": "Same mount",
        "备用不锈钢叉头，同一卡口。": "Spare steel fork head, same mount.",
        "携带": "Carry",
        "便携套": "Carry sleeve",
        "软套，可以放进包里。": "A soft sleeve for a bag.",
        "软套 · 1": "Soft sleeve · 1",
        "一餐": "One meal",
        "午间一份": "Midday bowl",
        "米饭、蛋白质、蔬菜，一餐。": "Rice, protein, vegetables, one meal.",
        "蛋白质": "Protein",
        "晨间一份": "Morning bowl",
        "燕麦、一个鸡蛋、水果。": "Oats, one egg, fruit.",
        "鸡蛋 · 1": "Egg · 1",
        "一周": "A week",
        "五日午间": "Five middays",
        "五份午间。单份是 ¥26。": "Five midday bowls. The single bowl is ¥26.",
        "五份午间，这一周的一套。单份是 ¥26。": "Five midday bowls for the week. The single bowl is ¥26.",
        "午间一份 · 5": "Midday bowl · 5",
        "单份 ¥26": "One bowl ¥26",
        "轻食套餐": "Light meal",
        "午间轻食": "Midday set",
        "米饭、蛋白质与时蔬，按一餐配好。": "Rice, protein, vegetables.",
        "为一餐准备。米饭、蛋白质和蔬菜分开放好，加热后食用。不附带折扣，也不捆绑餐具。": "For one meal. Rice, protein, and vegetables stay separate. Heat, then eat.",
        "熟米饭 · 约 180 克": "Rice · about 180 g",
        "蛋白质 · 一份": "Protein · one portion",
        "时蔬 · 一份": "Vegetables · one portion",
        "晨间轻食": "Morning set",
        "燕麦、鸡蛋和水果，从容的一餐。": "Oats, egg, and fruit.",
        "适合早上吃完就出门。燕麦、鸡蛋和水果已经分好，不需要再搭配。": "Leave after breakfast. Oats, egg, and fruit are already set.",
        "燕麦 · 约 1 碗": "Oats · about a bowl",
        "鸡蛋 · 1 个": "Egg · 1",
        "水果 · 约 1 份": "Fruit · one portion",
        "餐具配件": "Tableware",
        "替换叉头": "Fork head",
        "与智慧勺同一卡口，吃饭前换上。": "Same mount as the spoon.",
        "不锈钢叉头。机身不用换，记录方式也不变。装上之后，在设备里把餐头改成叉头。": "A steel fork head. Keep the handle and the record. Then set the head to fork.",
        "不锈钢叉头 · 1": "Steel fork head · 1",
        "与勺头同一卡口": "Same mount as the spoon",
        "智能餐具": "Utensil",
        "智慧叉": "Smart fork",
        "另一款智能餐具。叉头一体，记录方式相同。": "One-piece fork. Same record.",
        "适合更习惯用叉的人。电量、校准和同步都在同一套设备里完成，和智慧勺共用这份记录。": "For eating with a fork. Battery, calibration, and sync stay with the spoon's record.",
        "一体叉头": "One-piece fork",
        "电量与校准": "Battery and calibration",
        "和智慧勺同一份记录": "The same record as the spoon",
        "个人设置": "Settings",
        "按你的方式记录": "Record your way",
        "我的智慧勺": "My spoon",
        "设备与同步": "Device and sync",
        "同步记录": "Sync",
        "个人偏好": "Preferences",
        "隐藏热量数字": "Hide calories",
        "隐私与数据": "Privacy",
        "会员与权益": "Membership",
        "记录只为你自己回顾。": "The record is only for you.",
        "恢复初始记录": "Restore today's meals",
        "恢复后，今天的午餐会回到初始估算。": "Lunch today returns to the first estimate.",
        "恢复": "Restore",
        "取消": "Cancel",
        "今天的午餐会回到初始估算。你做过的核对会被清掉。": "Lunch today returns to the first estimate. Checks you made are cleared.",
        "还未填写，不影响记录": "Not set yet",
        "暂不设定": "Not now",
        "吃得更规律": "Steadier meals",
        "把每餐记完整": "Finish each meal",
        "清淡一些": "Lighter food",
        "智慧勺": "Spoon",
        "设备": "Device",
        "返回": "Back",
        "连接你的智慧勺": "Connect your spoon",
        "勺头和叉头可以更换。先连接，再校准，然后开始用餐。": "The spoon and fork heads swap. Connect, calibrate, then eat.",
        "连接智慧勺": "Connect",
        "使用本机连接": "Use this iPhone",
        "正在连接": "Connecting",
        "请让餐具靠近手机。": "Keep the utensil near the phone.",
        "将餐具平放在桌面上，停稳后再完成校准。": "Lay it flat on the table, then calibrate.",
        "完成校准": "Calibrate",
        "可以开始用餐": "Ready to eat",
        "已校准": "Calibrated",
        "未校准": "Not calibrated",
        "允许": "Allow",
        "暂不": "Not now",
        "使用蓝牙连接餐具": "Connect with Bluetooth",
        "只会在你同意后请求蓝牙，用来连接餐具。": "Bluetooth is asked only after you allow it, and only to connect the utensil.",
        "还没有绑定智慧勺": "No spoon yet",
        "绑定后可以查看连接、电量和餐头。": "After linking, you can see connection, battery, and the head.",
        "下一步：去绑定": "Next: link it",
        "去绑定": "Link",
        "蓝牙还没有打开": "Bluetooth is off",
        "在下一步允许蓝牙后，再连接餐具。": "Allow Bluetooth, then connect.",
        "下一步：开启蓝牙": "Next: turn Bluetooth on",
        "开启蓝牙": "Turn on",
        "请稍等": "One moment",
        "正在同步": "Syncing",
        "请稍等片刻，不要关闭页面。": "Stay on this page for a moment.",
        "连接已断开": "Disconnected",
        "靠近餐具后重新连接。": "Bring the utensil close, then connect again.",
        "下一步：重新连接": "Next: connect again",
        "重新连接": "Connect again",
        "同步没有完成": "Sync did not finish",
        "记录还在，可以再试一次。": "The record is still here. Try again.",
        "下一步：再次同步": "Next: sync again",
        "再次同步": "Sync again",
        "同步设备记录": "Sync records",
        "下一步：完成校准": "Next: calibrate",
        "电量": "Battery",
        "当前餐头": "Head",
        "同步": "Sync",
        "待同步": "Waiting",
        "—": "—",
        "还没有同步": "Not synced yet",
        "没有待同步的记录": "Nothing waiting",
        "断开连接": "Disconnect",
        "餐头": "Head",
        "吃饭前确认现在装的是勺头还是叉头。": "Before you eat, confirm the spoon or the fork.",
        "勺头": "Spoon",
        "叉头": "Fork",
        "未选择餐头": "No head",
        "校准": "Calibrate",
        "将餐具平放在桌面上，停稳后再完成。": "Lay it flat, let it settle, then finish.",
        "已经校准过。": "Already calibrated.",
        "重新校准": "Calibrate again",
        "保养": "Care",
        "餐后冲洗餐头，避免浸泡机身。": "Rinse the head after a meal. Do not soak the body.",
        "查看同步失败时的提示。不会新增餐次。": "See the note for a failed sync. No meal is added.",
        "查看同步失败": "See a failed sync",
        "已连接。": "Connected.",
        "还没有允许使用蓝牙。": "Bluetooth was not allowed.",
        "蓝牙已打开。": "Bluetooth is on.",
        "蓝牙暂时不可用，已使用本机连接。": "Bluetooth is unavailable. This iPhone is connected.",
        "校准已完成。": "Calibration is done.",
        "下一步：靠近餐具，重新连接。": "Next: bring it close and connect again.",
        "下一步：再次同步。记录还在。": "Next: sync again. The record is still here.",
        "记录已是最新": "Already up to date",
        "记录已是最新。": "Already up to date.",
        "安心吃饭，餐后再看": "Eat now. Look later.",
        "热量在餐后整理，吃饭时不会逐口提醒。": "Calories wait until the meal is over.",
        "结束并查看本餐": "End and review",
        "没有找到这餐": "This meal is gone",
        "食物组成": "Foods",
        "需要核对": "To check",
        "去核对": "Check",
        "已核对": "Checked",
        "已按你的核对更新": "Updated from your check",
        "可以再次修改": "You can change it",
        "补录食物": "Add a food",
        "收起进食过程": "Hide the meal",
        "查看进食过程": "Show the meal",
        "开始用餐": "Started",
        "这餐结束": "Finished",
        "中间吃得比较集中": "A fuller stretch",
        "鸡肉的烹饪方式需要核对": "How the chicken was cooked",
        "这份鸡肉是怎么做的？": "How was this chicken cooked?",
        "水煮或清蒸": "Steamed",
        "少量油煎制": "Pan-fried",
        "不确定，保留原估计": "Keep this estimate",
        "没有找到需要核对的食物": "Nothing here to check",
        "保存并更新本餐": "Save this meal",
        "补录": "Add",
        "饮品、零食，或餐具没有记下的食物，都可以补在这里。": "A drink, a snack, or anything the utensil missed.",
        "食物名称": "Food",
        "例如 苹果、黑咖啡": "Apple, or black coffee",
        "分量": "Portion",
        "例如 1 个，可不填": "Optional, such as 1",
        "不填分量，或还不能估算的食物，会保持待估算。": "Leave the portion blank and it stays uncounted.",
        "日期": "Date",
        "时间": "Time",
        "加入这条记录": "Add to the record",
        "请先写食物名称": "Name the food first",
        "都可以留空，不会拦住记录。": "Leave them blank. The record still works.",
        "身高": "Height",
        "厘米，可不填": "Centimeters, optional",
        "体重": "Weight",
        "公斤，可不填": "Kilograms, optional",
        "想先关注什么": "What to notice",
        "保存": "Save",
        "用餐记录": "Meal record",
        "用来在这台手机上展示餐次、食物和习惯变化。": "Meals, foods, and how they change, on this iPhone.",
        "连接信息": "Connection",
        "用来显示餐具是否连上、电量和餐头。不会在后台拍照，也不会持续上传画面。": "Whether the utensil is connected, its battery, and the head. No camera, and no live upload.",
        "模型训练": "Model training",
        "这是单独的选择，默认关闭。关闭时，记录只留在这台手机上。": "A separate choice, off unless you turn it on. Off, the record stays on this iPhone.",
        "允许用于模型训练": "Allow model training",
        "导出记录": "Export",
        "导出还没有开放。": "Export is not open.",
        "导出": "Export",
        "删除记录": "Delete",
        "删除这台手机上的用餐记录。设备绑定可以保留。": "Deletes meals on this iPhone. The device link can stay.",
        "删除本机记录": "Delete meals",
        "知道了": "OK",
        "删除": "Delete",
        "这台手机上的用餐记录会被清掉。没有记录不会被显示成 0。": "Meals on this iPhone are cleared. An empty day is not shown as zero.",
        "基础能力现在就可以用。付费方案还没有开放购买或续费。": "The basics work now. Paid plans are not open.",
        "基础": "Basic",
        "正在使用": "In use",
        "连接餐具": "Connect a utensil",
        "记录用餐": "Record a meal",
        "查看历史": "See history",
        "核对与补录": "Check and add",
        "Plus": "Plus",
        "未开通": "Not open",
        "完整趋势": "Full trends",
        "食谱工具": "Recipe tools",
        "更细的用餐回顾": "A closer look at meals",
        "Pro": "Pro",
        "在 Plus 之上，支持更长时间的回顾": "What Plus has, kept for longer",
        "先连接智慧勺": "Connect the spoon first",
        "绑定餐具后就可以开始这餐。身高和目标都可以稍后再填。": "Link the utensil, then start. Height and goals can wait.",
        "允许蓝牙后，再连接餐具。": "Allow Bluetooth, then connect.",
        "餐具没有连上": "The utensil is not connected",
        "靠近餐具并重新连接后，再开始用餐。": "Bring it close, connect, then start.",
        "餐具正在处理上一步，完成后再开始用餐。": "It is still finishing the last step.",
        "查看设备": "See device",
        "可以先重新同步，再开始用餐。": "Sync again, then start the meal.",
        "先完成校准": "Calibrate first",
        "把餐具平放在桌面，完成校准后再开始。": "Lay it flat, calibrate, then start.",
        "去校准": "Calibrate",
        "先确认餐头": "Choose the head",
        "装上勺头或叉头后，再开始用餐。": "Fit the spoon or the fork, then start.",
        "有一餐还在记录": "A meal is still open",
        "先结束这一餐，再开始下一餐。": "End this one before the next.",
        "继续用餐": "Resume",
        "已更新本餐": "Meal updated",
        "已记下，待估算": "Saved, still to estimate",
        "已加入记录": "Added",
        "记录已删除": "Meals deleted",
        "已放入购物袋": "Added to bag",
        "请稍等，正在处理。": "One moment.",
        "连接已断开，请先重新连接。": "Disconnected. Connect again.",
        "请先连接餐具。": "Connect the utensil first.",
        "手动补录": "Added by hand",
        "不到 1 分钟": "Under a minute",
        "语言": "Language",
        "打开餐具电源，手机放在旁边。": "Turn it on. Keep the phone close.",
        "点击下面的按钮后，才会请求蓝牙。": "Bluetooth is asked only after the tap.",
        "连接后把餐具平放，完成一次校准。": "Lay it flat, then calibrate once.",
        "身高、体重和目标都可以稍后填写，不影响记录。": "Height, weight, and a goal can wait.",
        "选择一项后，本餐合计会跟着更新。可以稍后再次修改。": "The total follows what you choose.",
        "用餐时间较短，请核对下面的结果。": "A short meal. Check the result below.",
        "可以按需要核对食物。": "Check a food if you want.",
        "分量待补充": "Portion later",
        "信息还不够，这一项保持待估算。": "Not enough here. This stays uncounted.",
        "时蔬": "Vegetables",
        "清汤": "Broth",
        "约 1 碟": "About a plate",
        "扫描": "Scan",
        "附近的设备": "Nearby",
        "点一个才会连接。不会自动连上。": "Choose one to connect.",
        "还没有发现设备": "No devices yet",
        "这里只列出真实的附近设备。": "Only a real device is listed.",
        "正在请求蓝牙": "Asking for Bluetooth",
        "正在扫描": "Scanning",
        "扫描中": "Scanning",
        "重新扫描": "Scan again",
        "打开设置": "Open Settings",
        "未允许": "Not allowed",
        "无蓝牙": "No radio",
        "连接失败": "Failed",
        "还没有允许蓝牙": "Bluetooth not allowed",
        "在设置里允许智慧勺使用蓝牙，然后再扫描。": "Allow Bluetooth in Settings, then scan.",
        "下一步：前往设置允许蓝牙": "Next: allow Bluetooth",
        "下一步：前往设置允许蓝牙。": "Next: allow Bluetooth.",
        "在控制中心打开蓝牙，然后再扫描。": "Turn on Bluetooth in Control Center, then scan.",
        "下一步：打开蓝牙": "Next: turn Bluetooth on",
        "下一步：打开蓝牙。": "Next: turn Bluetooth on.",
        "这里没有蓝牙": "No Bluetooth here",
        "模拟器扫描不到附近的设备。用一台 iPhone 再扫描。": "The simulator cannot see devices. Scan from an iPhone.",
        "下一步：换到 iPhone": "Next: use an iPhone",
        "下一步：换到 iPhone。": "Next: use an iPhone.",
        "没有连上": "Could not connect",
        "靠近后再选一次。": "Move closer and choose it again.",
        "下一步：重新扫描并选择设备": "Next: scan and choose a device",
        "下一步：重新扫描并选择设备。": "Next: scan and choose a device.",
        "选择一个设备后才会连接。": "Choose a device to connect.",
        "下一步：选择一个设备": "Next: choose a device",
        "未命名": "Unnamed",
        "还不是智慧勺": "Not a spoon yet",
        "还不是智慧勺。这份连接不会记餐，也不会写入热量。": "Not a spoon yet. This link does not record a meal.",
        "下一步：靠近智慧勺，重新扫描并选中它。": "Next: scan again and choose the spoon.",
        "已找到智慧勺，还没有收到电量或餐头。": "Spoon found. No battery or head yet.",
        "已找到智慧勺，还没有收到数据。": "Spoon found. No data yet.",
        "下一步：等它发来一包数据。没有数据就不会记餐。": "Next: wait for a packet. No packet, no meal.",
        "这还不是智慧勺，不会新增餐次。": "Not a spoon yet. No meal is added.",
        "已请求同步": "Sync requested",
        "已请求同步。餐次只在收到数据包时更新。": "Sync requested. Meals change only when a packet arrives.",
        "用餐": "Meal",
        "还不是勺": "Not a spoon",
    ]
}
