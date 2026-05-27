import SwiftUI

@main
struct StadtNewsApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .tint(Theme.Color.brand)
        }
    }
}
