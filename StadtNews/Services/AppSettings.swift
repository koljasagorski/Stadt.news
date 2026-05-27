import Foundation
import Combine

/// App-wide user preferences, persisted in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {
    /// Ordered list of selected city ids. Order is the display order.
    @Published var selectedCityIDs: [String] {
        didSet { defaults.set(selectedCityIDs, forKey: Keys.cities) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// Whether the user wants push notifications for new articles.
    @Published var pushEnabled: Bool {
        didSet { defaults.set(pushEnabled, forKey: Keys.push) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let cities = "selectedCityIDs"
        static let onboarding = "hasCompletedOnboarding"
        static let push = "pushEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCityIDs = defaults.stringArray(forKey: Keys.cities) ?? []
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        self.pushEnabled = defaults.bool(forKey: Keys.push)
    }

    /// Selected cities resolved against the catalog, preserving order.
    var selectedCities: [City] {
        selectedCityIDs.compactMap { City.city(for: $0) }
    }

    func isSelected(_ city: City) -> Bool {
        selectedCityIDs.contains(city.id)
    }

    func toggle(_ city: City) {
        if let index = selectedCityIDs.firstIndex(of: city.id) {
            // Keep at least one city selected.
            guard selectedCityIDs.count > 1 else { return }
            selectedCityIDs.remove(at: index)
        } else {
            selectedCityIDs.append(city.id)
        }
    }

    func select(_ city: City) {
        guard !selectedCityIDs.contains(city.id) else { return }
        selectedCityIDs.append(city.id)
    }

    /// Finalises onboarding, defaulting to Gelsenkirchen if nothing was picked.
    func completeOnboarding() {
        if selectedCityIDs.isEmpty {
            selectedCityIDs = [City.gelsenkirchen.id]
        }
        hasCompletedOnboarding = true
    }
}
