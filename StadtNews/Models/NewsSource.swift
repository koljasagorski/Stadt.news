import Foundation

/// A category of publisher within a city: police, fire brigade, or city hall.
///
/// Derived from an article's `source` string so the feed can be filtered by
/// source and push notifications can be toggled per source. The raw value
/// matches the worker's `sourceID` and the OneSignal `src_<id>` tag.
enum NewsSource: String, CaseIterable, Identifiable, Sendable {
    case polizei
    case feuerwehr
    case stadt

    var id: String { rawValue }

    /// Short label for filter chips and settings rows.
    var label: String {
        switch self {
        case .polizei: return "Polizei"
        case .feuerwehr: return "Feuerwehr"
        case .stadt: return "Stadt"
        }
    }

    /// Maps an article's full source string, e.g. "Feuerwehr Gelsenkirchen".
    init(sourceName: String) {
        if sourceName.localizedCaseInsensitiveContains("Polizei") {
            self = .polizei
        } else if sourceName.localizedCaseInsensitiveContains("Feuerwehr") {
            self = .feuerwehr
        } else {
            self = .stadt
        }
    }
}

extension Article {
    /// The publisher category this article belongs to.
    var newsSource: NewsSource { NewsSource(sourceName: source) }
}
