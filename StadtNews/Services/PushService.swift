import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

/// Thin wrapper around OneSignal for push notifications.
///
/// All OneSignal calls are guarded by `#if canImport(OneSignalFramework)`, so
/// the app keeps building and running normally *before* the OneSignal Swift
/// package is added in Xcode. Once the package is present and `appID` is set,
/// the methods light up automatically.
///
/// Setup checklist (see the pull request description for full steps):
///  1. Xcode → File → Add Package Dependencies → `https://github.com/OneSignal/OneSignal-iOS-SDK`
///  2. Paste the OneSignal App ID into `PushService.appID` below.
///  3. Target → Signing & Capabilities → add "Push Notifications" and
///     "Background Modes → Remote notifications" (needs an Apple Developer team).
final class PushService {
    static let shared = PushService()
    private init() {}

    /// OneSignal App ID. Find it in the OneSignal dashboard under
    /// Settings → Keys & IDs. Until this is set, push stays inactive.
    static let appID = "YOUR_ONESIGNAL_APP_ID"

    private var didStart = false

    /// `true` once a real App ID has been pasted in (i.e. push is configured).
    private static var isConfigured: Bool { appID != "YOUR_ONESIGNAL_APP_ID" }

    /// Called once at launch from the app delegate.
    func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(OneSignalFramework)
        guard !didStart, Self.isConfigured else { return }
        didStart = true
        OneSignal.initialize(Self.appID, withLaunchOptions: launchOptions)
        #endif
    }

    /// Turns push on/off. Turning on triggers the iOS permission prompt.
    func setEnabled(_ enabled: Bool) {
        #if canImport(OneSignalFramework)
        guard Self.isConfigured else { return }
        if enabled {
            OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
            OneSignal.User.pushSubscription.optIn()
        } else {
            OneSignal.User.pushSubscription.optOut()
        }
        #endif
    }

    /// Mirrors the user's selected cities into OneSignal tags (`city_<id> = 1`),
    /// so the GitHub poller can target only the cities a user follows.
    func syncCityTags(_ selectedCityIDs: [String]) {
        #if canImport(OneSignalFramework)
        guard Self.isConfigured else { return }
        let selected = Set(selectedCityIDs)
        var add: [String: String] = [:]
        var remove: [String] = []
        for city in City.catalog {
            let key = "city_\(city.id)"
            if selected.contains(city.id) {
                add[key] = "1"
            } else {
                remove.append(key)
            }
        }
        if !add.isEmpty { OneSignal.User.addTags(add) }
        if !remove.isEmpty { OneSignal.User.removeTags(remove) }
        #endif
    }
}
