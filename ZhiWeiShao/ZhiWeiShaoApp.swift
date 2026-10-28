import SwiftUI

@main
struct ZhiWeiShaoApp: App {
    @State private var store: AppStore

    init() {
        TabChrome.apply()
        _store = State(initialValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Palette.ink)
                .preferredColorScheme(.light)
        }
    }
}
