# 智慧勺

A spoon, and a fork head on the same mount. It records a meal while you eat. This iPhone app is where you link the utensil, review the meal, correct the record, and open the shop.

## On an iPhone

Open `ZhiWeiShao.xcodeproj` in Xcode. Choose the ZhiWeiShao scheme and your iPhone, then run. The phone needs iOS 18. Signing is off in the project, so select your development team before it installs.

A nearby spoon is found from the phone. The simulator has no radio for that.

## Spoon Link

The firmware has to match `SpoonLink.md`. The app parses only that contract: a versioned packet with time, length, payload, and a checksum, on the service and characteristics named there. Battery, the current head, and meals update only from a packet that matches. Any other Bluetooth device can stay connected and is shown as not a spoon yet. It does not become a meal.

## Shop

The shop is a catalog stored in the app. Prices and photos are local demo data. Buying is not open.

## 中文

智慧勺是一只勺，叉头用同一卡口换上。它在用餐时留下记录。这支 iPhone 应用用来连接餐具、回看并核对记录，以及打开商城。

用 Xcode 打开 `ZhiWeiShao.xcodeproj`，选择智慧勺方案和你的 iPhone，然后运行。手机需要 iOS 18。工程里签名是关着的，安装前选上你的开发团队。

固件必须符合 `SpoonLink.md`。应用只解析这份格式。其他蓝牙设备可以保持连接，但不会变成一餐。

商城是应用里的本地目录。价格和图片是演示数据，购买还没有开放。
