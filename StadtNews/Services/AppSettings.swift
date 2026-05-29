import Foundation
import Combine

/// App-wide user preferences, persisted in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    /// Whether the user wants push notifications for new articles.
    @Published var pushEnabled: Bool {
        didSet { defaults.set(pushEnabled, forKey: Keys.push) }
    }

    /// Which sources the user wants push notifications for (defaults to all).
    @Published var enabledPushSources: Set<String> {
        didSet { defaults.set(Array(enabledPushSources), forKey: Keys.pushSources) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let push = "pushEnabled"
        static let pushSources = "enabledPushSources"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pushEnabled = defaults.bool(forKey: Keys.push)
        if let stored = defaults.array(forKey: Keys.pushSources) as? [String] {
            self.enabledPushSources = Set(stored)
        } else {
            self.enabledPushSources = Set(NewsSource.allCases.map(\.id))
        }
    }

    func isPushEnabled(for source: NewsSource) -> Bool {
        enabledPushSources.contains(source.id)
    }

    func setPushEnabled(_ enabled: Bool, for source: NewsSource) {
        if enabled {
            enabledPushSources.insert(source.id)
        } else {
            enabledPushSources.remove(source.id)
        }
    }

    /// The app covers a single city, so the selection is the whole catalog.
    var selectedCities: [City] { City.catalog }

    var selectedCityIDs: [String] { City.catalog.map(\.id) }
}
