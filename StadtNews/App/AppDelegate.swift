import UIKit

/// Minimal app delegate so OneSignal can initialise with the launch options.
/// Wired into SwiftUI via `@UIApplicationDelegateAdaptor` in `StadtNewsApp`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushService.shared.start(launchOptions: launchOptions)
        return true
    }
}
