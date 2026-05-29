import SwiftUI

@main
struct StadtNewsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .tint(Theme.Color.brand)
                .onAppear {
                    PushService.shared.setEnabled(settings.pushEnabled)
                    PushService.shared.syncCityTags(settings.selectedCityIDs)
                    PushService.shared.syncSourceTags(settings.enabledPushSources)
                }
                .onChange(of: settings.pushEnabled) { _, enabled in
                    PushService.shared.setEnabled(enabled)
                }
                .onChange(of: settings.enabledPushSources) { _, sources in
                    PushService.shared.syncSourceTags(sources)
                }
        }
    }
}
