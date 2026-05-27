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
    /// Cities available at launch.
    ///
    /// Gelsenkirchen is the first, default city. Every id below is a
    /// verified Presseportal police newsroom. Add more entries here to
    /// expand coverage – no other code needs to change.
    static let catalog: [City] = [
        City(id: "51056", name: "Gelsenkirchen", state: "Nordrhein-Westfalen", source: "Polizei Gelsenkirchen"),
        City(id: "4971",  name: "Dortmund",      state: "Nordrhein-Westfalen", source: "Polizei Dortmund"),
        City(id: "11562", name: "Essen",         state: "Nordrhein-Westfalen", source: "Polizei Essen"),
        City(id: "11530", name: "Bochum",        state: "Nordrhein-Westfalen", source: "Polizei Bochum"),
        City(id: "50510", name: "Duisburg",      state: "Nordrhein-Westfalen", source: "Polizei Duisburg"),
        City(id: "13248", name: "Düsseldorf",    state: "Nordrhein-Westfalen", source: "Polizei Düsseldorf"),
        City(id: "12415", name: "Köln",          state: "Nordrhein-Westfalen", source: "Polizei Köln"),
        City(id: "11187", name: "Münster",       state: "Nordrhein-Westfalen", source: "Polizei Münster"),
        City(id: "12522", name: "Bielefeld",     state: "Nordrhein-Westfalen", source: "Polizei Bielefeld"),
        City(id: "11811", name: "Wuppertal",     state: "Nordrhein-Westfalen", source: "Polizei Wuppertal"),
    ]

    /// The default city the app launches with.
    static let gelsenkirchen = catalog[0]

    static func city(for id: String) -> City? {
        catalog.first { $0.id == id }
    }
}
