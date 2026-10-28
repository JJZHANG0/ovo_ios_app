import Foundation

/// Named comparison baseline for one recorded meal. Not a target, and not a stand-in for a meal that was never recorded.
enum TypicalMeal {
    static let name = "typical-meal"
    static let baselineKcal = 650
}

enum MockData {
    /// Seed records stay older than any user correction.
    static let seedRevision: Double = 1

    private static let manualKcal: [String: Int] = [
        "黑咖啡": 5,
        "美式咖啡": 5,
        "无糖豆浆": 40,
        "原味酸奶": 90,
        "苹果": 80,
        "清水": 0,
    ]

    static func estimateManualFood(name: String, portion: String) -> Int? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if portion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        return manualKcal[key]
    }

    static func chickenCheck() -> FoodCheck {
        FoodCheck(
            question: "鸡肉的烹饪方式需要核对",
            prompt: "这份鸡肉是怎么做的？",
            options: [
                CheckOption(id: "steam", label: "水煮或清蒸", kcal: 165),
                CheckOption(id: "pan", label: "少量油煎制", kcal: 190),
                CheckOption(id: "keep", label: "不确定，保留原估计", kcal: nil),
            ],
            resolved: false,
            choiceId: ""
        )
    }

    private static func food(
        id: String,
        name: String,
        portion: String,
        kcal: Int?,
        check: FoodCheck? = nil
    ) -> FoodItem {
        FoodItem(id: id, name: name, portion: portion, kcal: kcal, source: .utensil, check: check)
    }

    private static func makeMeal(
        date: String,
        slot: String,
        name: String,
        time: String,
        foods: [FoodItem],
        brief: String? = nil,
        durationSec: Int = 20 * 60,
        biteCount: Int? = 16,
        events: [BiteEvent] = []
    ) -> Meal {
        let started = ZWFormat.atTime(date, time)
        return Meal(
            id: "meal-\(date)-\(slot)",
            date: date,
            name: name,
            time: time,
            startedAt: started,
            endedAt: started + Double(durationSec) * 1000,
            durationSec: durationSec,
            biteCount: biteCount,
            status: .ready,
            foods: foods,
            brief: brief ?? foods.map(\.name).joined(separator: "、"),
            briefCount: foods.count,
            events: events,
            updatedAt: seedRevision,
            source: .utensil,
            estimateNote: ""
        )
    }

    private static func todayBreakfast(_ date: String) -> Meal {
        let id = "meal-\(date)-breakfast"
        return makeMeal(
            date: date,
            slot: "breakfast",
            name: "早餐",
            time: "08:05",
            foods: [
                food(id: "\(id)-oats", name: "燕麦酸奶", portion: "约 1 碗", kcal: 280),
                food(id: "\(id)-egg", name: "鸡蛋", portion: "2 个", kcal: 150),
                food(id: "\(id)-fruit", name: "水果", portion: "约 1 份", kcal: 120),
                food(id: "\(id)-latte", name: "拿铁", portion: "约 300 毫升", kcal: 182),
            ],
            brief: "燕麦酸奶、鸡蛋、水果",
            durationSec: 15 * 60,
            biteCount: 18,
            events: [
                BiteEvent(time: "08:06", note: "开始用餐"),
                BiteEvent(time: "08:20", note: "这餐结束"),
            ]
        )
    }

    private static func todayLunch(_ date: String) -> Meal {
        let id = "meal-\(date)-lunch"
        return makeMeal(
            date: date,
            slot: "lunch",
            name: "午餐",
            time: "12:20",
            foods: [
                food(id: "\(id)-rice", name: "熟米饭", portion: "约 180 克", kcal: 156),
                food(id: "\(id)-chicken", name: "鸡胸肉", portion: "约 120 克", kcal: 165, check: chickenCheck()),
                food(id: "\(id)-veg", name: "蔬菜与配料", portion: "约 1 份", kcal: 107),
            ],
            brief: "鸡肉蔬菜饭",
            durationSec: 22 * 60,
            biteCount: 28,
            events: [
                BiteEvent(time: "12:21", note: "开始用餐"),
                BiteEvent(time: "12:32", note: "中间吃得比较集中"),
                BiteEvent(time: "12:42", note: "这餐结束"),
            ]
        )
    }

    private static func plainFoods(_ mealId: String, _ items: [(String, String, Int)]) -> [FoodItem] {
        items.enumerated().map { index, item in
            food(id: "\(mealId)-\(index)", name: item.0, portion: item.1, kcal: item.2)
        }
    }

    private static func genericBreakfast(_ date: String) -> Meal {
        let id = "meal-\(date)-breakfast"
        return makeMeal(
            date: date,
            slot: "breakfast",
            name: "早餐",
            time: "08:20",
            foods: plainFoods(id, [
                ("燕麦", "约 1 碗", 240),
                ("鸡蛋", "1 个", 78),
                ("牛奶", "约 250 毫升", 140),
            ]),
            durationSec: 14 * 60,
            biteCount: 14
        )
    }

    private static func genericLunch(_ date: String, time: String, withVeg: Bool, protein: Int) -> Meal {
        let id = "meal-\(date)-lunch"
        var items: [(String, String, Int)] = [("熟米饭", "约 1 碗", 180)]
        items.append(withVeg ? ("蔬菜", "约 1 份", 70) : ("豆腐", "约 1 份", 90))
        items.append(("鸡腿", "约 1 份", protein))
        return makeMeal(
            date: date,
            slot: "lunch",
            name: "午餐",
            time: time,
            foods: plainFoods(id, items),
            durationSec: 24 * 60,
            biteCount: 22
        )
    }

    private static func genericDinner(_ date: String) -> Meal {
        let id = "meal-\(date)-dinner"
        return makeMeal(
            date: date,
            slot: "dinner",
            name: "晚餐",
            time: "18:40",
            foods: plainFoods(id, [
                ("米饭", "约 1 碗", 200),
                ("鱼", "约 1 份", 180),
                ("蔬菜", "约 1 份", 80),
            ]),
            durationSec: 26 * 60,
            biteCount: 24
        )
    }

    /// One history relative to the first-open day. That day has breakfast 732 and lunch 428.
    static func buildMeals(today: String) -> [Meal] {
        var meals: [Meal] = []
        let monday = ZWFormat.mondayOf(today)
        let thisWeekTimes = ["12:05", "12:12", "12:20", "12:08", "12:28", "12:20", "12:30"]
        for index in 0..<7 {
            let date = ZWFormat.shiftDate(monday, days: index)
            if date > today { break }
            if date == today {
                meals.append(todayBreakfast(date))
                meals.append(todayLunch(date))
                continue
            }
            meals.append(genericBreakfast(date))
            meals.append(genericLunch(date, time: thisWeekTimes[index], withVeg: true, protein: 150 + index * 8))
            if index == 1 || index == 4 { meals.append(genericDinner(date)) }
        }

        let previousMonday = ZWFormat.shiftDate(monday, days: -7)
        let lastLunch: Set<Int> = [0, 1, 3, 5]
        let lastBreakfast: Set<Int> = [0, 1, 2, 3, 5]
        let lastVeg: Set<Int> = [0, 3]
        let lastTimes = [0: "12:42", 1: "12:55", 3: "13:05", 5: "12:36"]
        for index in 0..<7 {
            let date = ZWFormat.shiftDate(previousMonday, days: index)
            if date > today { continue }
            if lastBreakfast.contains(index) { meals.append(genericBreakfast(date)) }
            if lastLunch.contains(index) {
                meals.append(genericLunch(date, time: lastTimes[index] ?? "12:30", withVeg: lastVeg.contains(index), protein: 210))
            }
        }
        return meals
    }

    static func liveFoods(mealId: String) -> [FoodItem] {
        [
            food(id: "\(mealId)-soup", name: "清汤", portion: "约 1 碗", kcal: 60),
            FoodItem(
                id: "\(mealId)-veg",
                name: "时蔬",
                portion: "约 1 碟",
                kcal: 90,
                source: .utensil,
                check: FoodCheck(
                    question: "蔬菜是否加了酱汁需要核对",
                    prompt: "这份蔬菜加酱汁了吗？",
                    options: [
                        CheckOption(id: "plain", label: "没有酱汁", kcal: 90),
                        CheckOption(id: "sauce", label: "加了少量酱汁", kcal: 120),
                        CheckOption(id: "keep", label: "不确定，保留原估计", kcal: nil),
                    ],
                    resolved: false,
                    choiceId: ""
                )
            ),
        ]
    }
}
