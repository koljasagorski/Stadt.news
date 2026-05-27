import Foundation

/// A city whose local news can be displayed in the app.
///
/// `id` is the numeric Presseportal "Blaulicht" newsroom identifier
/// (e.g. Gelsenkirchen = `51056`). The app is designed so that the
/// catalog can grow to cover every city in Germany over time.
struct City: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    /// German federal state ("Bundesland").
    let state: String
    /// The publishing authority, e.g. "Polizei Gelsenkirchen".
    let source: String

    /// Native RSS feed for this city's newsroom.
    var feedURL: URL {
        URL(string: "https://www.presseportal.de/rss/dienststelle_\(id).rss2")!
    }

    /// Public web page for this newsroom (used for "read original" links).
    var webURL: URL {
        URL(string: "https://www.presseportal.de/blaulicht/nr/\(id)")!
    }
}

extension City {
    /// The single city this app covers. The catalog is intentionally limited to
    /// Gelsenkirchen; the multi-city plumbing is kept so it can grow again later.
    static let catalog: [City] = [
        City(id: "51056", name: "Gelsenkirchen", state: "Nordrhein-Westfalen", source: "Polizei Gelsenkirchen"),
    ]

    /// The city the app launches with.
    static let gelsenkirchen = catalog[0]

    static func city(for id: String) -> City? {
        catalog.first { $0.id == id }
    }
}
