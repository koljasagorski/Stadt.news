import Foundation
import Combine

/// App-wide user preferences, persisted in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    /// Whether the user wants push notifications for new articles.
    @Published var pushEnabled: Bool {
        didSet { defaults.set(pushEnabled, forKey: Keys.push) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let push = "pushEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pushEnabled = defaults.bool(forKey: Keys.push)
    }

    /// The app covers a single city, so the selection is the whole catalog.
    var selectedCities: [City] { City.catalog }

    var selectedCityIDs: [String] { City.catalog.map(\.id) }
}
