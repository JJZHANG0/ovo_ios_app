import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    PreviewHost()
}

private struct PreviewHost: View {
    init() { TabChrome.apply() }

    var body: some View {
        ContentView()
            .environment(AppStore())
            .tint(Palette.ink)
            .preferredColorScheme(.light)
    }
}
