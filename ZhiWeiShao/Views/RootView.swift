import SwiftUI

private struct NavPathKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath>? = nil
}

extension EnvironmentValues {
    var navPath: Binding<NavigationPath>? {
        get { self[NavPathKey.self] }
        set { self[NavPathKey.self] = newValue }
    }
}

enum DeviceFocus: Hashable {
    case none
    case calibrate
    case sync
}

enum AppRoute: Hashable {
    case device(DeviceFocus)
    case bind
    case mealLive(String)
    case mealDetail(String)
    case correction(mealId: String, foodId: String)
    case addEntry(mealId: String, date: String)
    case preferences
    case privacy
    case membership
    case product(String)
    case bag
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var tab = 0
    @State private var todayPath = NavigationPath()
    @State private var recordsPath = NavigationPath()
    @State private var shopPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $todayPath) {
                TodayView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteScreen(route: route)
                    }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.navPath, $todayPath)
            .tabItem { Label(store.t("今天"), systemImage: "sun.max") }
            .tag(0)

            NavigationStack(path: $recordsPath) {
                RecordsView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteScreen(route: route)
                    }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.navPath, $recordsPath)
            .tabItem { Label(store.t("记录"), systemImage: "list.bullet") }
            .tag(1)

            NavigationStack(path: $shopPath) {
                ShopView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteScreen(route: route)
                    }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.navPath, $shopPath)
            .tabItem { Label(store.t("商城"), systemImage: "bag") }
            .tag(2)

            NavigationStack(path: $profilePath) {
                ProfileView()
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteScreen(route: route)
                    }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.navPath, $profilePath)
            .tabItem { Label(store.t("我的"), systemImage: "person") }
            .tag(3)
        }
        .id(store.language)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Text(store.t(toast))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        Capsule().fill(Color.black.opacity(0.84))
                        Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                    }
                    .padding(.top, 8)
                    .accessibilityIdentifier("toast")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecords)) { _ in
            tab = 1
        }
    }
}

struct RouteScreen: View {
    var route: AppRoute
    @Environment(AppStore.self) private var store

    var body: some View {
        PushScaffold(title: title) {
            screen
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .device(let focus):
            DeviceView(focus: focus)
        case .bind:
            BindView()
        case .mealLive(let id):
            MealLiveView(mealId: id)
        case .mealDetail(let id):
            MealDetailView(mealId: id)
        case .correction(let mealId, let foodId):
            CorrectionView(mealId: mealId, foodId: foodId)
        case .addEntry(let mealId, let date):
            AddEntryView(mealId: mealId, date: date)
        case .preferences:
            PreferencesView()
        case .privacy:
            PrivacyView()
        case .membership:
            MembershipView()
        case .product(let id):
            ProductDetailView(productId: id)
        case .bag:
            BagView()
        }
    }

    private var title: String {
        switch route {
        case .device: return store.t("设备")
        case .bind: return ""
        case .mealLive: return ""
        case .mealDetail: return ""
        case .correction: return ""
        case .addEntry: return ""
        case .preferences: return ""
        case .privacy: return store.t("隐私与数据")
        case .membership: return store.t("会员与权益")
        case .product: return ""
        case .bag: return store.t("购物袋")
        }
    }
}
