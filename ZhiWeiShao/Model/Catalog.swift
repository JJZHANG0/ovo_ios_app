import Foundation

struct Product: Identifiable, Hashable {
    var id: String
    var eyebrow: String
    var name: String
    var price: Int
    var summary: String
    var story: String
    var includes: [String]
    var imageName: String

    var priceText: String {
        "¥\(ZWFormat.formatInt(price))"
    }
}

enum Catalog {
    static let products: [Product] = [
        Product(
            id: "spoon-head",
            eyebrow: "餐具配件",
            name: "替换勺头",
            price: 49,
            summary: "备用不锈钢勺头，同一卡口。",
            story: "备用不锈钢勺头，同一卡口。",
            includes: ["不锈钢勺头 · 1", "同一卡口"],
            imageName: "SpoonHead"
        ),
        Product(
            id: "fork-head",
            eyebrow: "餐具配件",
            name: "替换叉头",
            price: 49,
            summary: "备用不锈钢叉头，同一卡口。",
            story: "备用不锈钢叉头，同一卡口。",
            includes: ["不锈钢叉头 · 1", "同一卡口"],
            imageName: "ShopForkHead"
        ),
        Product(
            id: "carry-sleeve",
            eyebrow: "携带",
            name: "便携套",
            price: 29,
            summary: "软套，可以放进包里。",
            story: "软套，可以放进包里。",
            includes: ["软套 · 1"],
            imageName: "CarrySleeve"
        ),
        Product(
            id: "midday-bowl",
            eyebrow: "一餐",
            name: "午间一份",
            price: 26,
            summary: "米饭、蛋白质、蔬菜，一餐。",
            story: "米饭、蛋白质、蔬菜，一餐。",
            includes: ["米饭", "蛋白质", "蔬菜"],
            imageName: "MiddayBowl"
        ),
        Product(
            id: "morning-bowl",
            eyebrow: "一餐",
            name: "晨间一份",
            price: 16,
            summary: "燕麦、一个鸡蛋、水果。",
            story: "燕麦、一个鸡蛋、水果。",
            includes: ["燕麦", "鸡蛋 · 1", "水果"],
            imageName: "MorningBowl"
        ),
        Product(
            id: "five-middays",
            eyebrow: "一周",
            name: "五日午间",
            price: 98,
            summary: "五份午间。单份是 ¥26。",
            story: "五份午间，这一周的一套。单份是 ¥26。",
            includes: ["午间一份 · 5", "单份 ¥26"],
            imageName: "FiveMiddays"
        ),
    ]

    static func product(_ id: String) -> Product? {
        products.first { $0.id == id }
    }
}
