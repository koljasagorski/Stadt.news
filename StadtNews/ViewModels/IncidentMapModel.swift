import Foundation
import CoreLocation
import MapKit

/// Builds map pins for incidents by geocoding a street name found in each
/// article. Police feeds carry no coordinates, so this is best-effort: items
/// without a recognisable street are reported as "unlocated" and skipped.
/// Results are cached in `UserDefaults` so the geocoder isn't hit repeatedly.
@MainActor
final class IncidentMapModel: ObservableObject {
    struct Incident: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let article: Article
    }

    @Published private(set) var incidents: [Incident] = []
    @Published private(set) var isLoading = false
    @Published private(set) var unlocatedCount = 0

    private let service = NewsService.shared
    private let geocoder = CLGeocoder()

    private var coords: [String: Coordinate]
    private var misses: Set<String>

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let decoded = try? JSONDecoder().decode(CacheData.self, from: data) {
            coords = decoded.coords
            misses = Set(decoded.misses)
        } else {
            coords = [:]
            misses = []
        }
    }

    func load(cities: [City]) async {
        guard incidents.isEmpty else { return }
        isLoading = true
        let result = await service.feed(for: cities)
        isLoading = false
        await build(from: result.articles)
    }

    // MARK: Geocoding

    private func build(from articles: [Article]) async {
        var built: [Incident] = []
        var pending: [Article] = []
        var missed = 0

        for article in articles {
            if let cached = coords[article.id] {
                built.append(Incident(id: article.id, coordinate: cached.clCoordinate, article: article))
            } else if misses.contains(article.id) {
                missed += 1
            } else {
                pending.append(article)
            }
        }
        incidents = built
        unlocatedCount = missed

        for article in pending {
            guard let center = Self.cityCenters[article.cityID],
                  let street = Self.street(in: article) else {
                misses.insert(article.id)
                missed += 1
                unlocatedCount = missed
                continue
            }

            let query = "\(street), \(article.cityName), Deutschland"
            if let coordinate = await geocode(query),
               Self.isPlausible(coordinate, near: center) {
                coords[article.id] = Coordinate(coordinate)
                built.append(Incident(id: article.id, coordinate: coordinate, article: article))
                incidents = built
            } else {
                misses.insert(article.id)
                missed += 1
                unlocatedCount = missed
            }

            // Be gentle with Apple's rate-limited geocoder.
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        save()
    }

    private func geocode(_ query: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func save() {
        let data = try? JSONEncoder().encode(CacheData(coords: coords, misses: Array(misses)))
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    // MARK: Helpers

    private static let cacheKey = "incidentCoordinateCache"

    private static func isPlausible(_ coordinate: CLLocationCoordinate2D,
                                    near center: CLLocationCoordinate2D) -> Bool {
        let a = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let b = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return a.distance(from: b) < 30_000 // within 30 km of the city centre
    }

    /// Finds the first street-like token in the article text.
    private static let streetRegex = try! NSRegularExpression(
        pattern: "([A-ZÄÖÜ][\\wäöüßA-Za-z-]*(?:straße|strasse|str\\.|platz|weg|allee|ring|damm|gasse|ufer|brücke))"
    )

    static func street(in article: Article) -> String? {
        let text = article.title + ". " + article.summary
        let range = NSRange(text.startIndex..., in: text)
        guard let match = streetRegex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[matchRange])
    }

    /// Approximate city centres. Keep ids in sync with `City.catalog`.
    static let cityCenters: [String: CLLocationCoordinate2D] = [
        "51056": .init(latitude: 51.5177, longitude: 7.0857), // Gelsenkirchen
    ]

    static func region(for cities: [City]) -> MKCoordinateRegion {
        let centers = cities.compactMap { cityCenters[$0.id] }
        guard let first = centers.first else {
            return MKCoordinateRegion(
                center: .init(latitude: 51.45, longitude: 7.0),
                span: .init(latitudeDelta: 1.5, longitudeDelta: 1.5)
            )
        }
        guard centers.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: .init(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        }
        let lats = centers.map(\.latitude)
        let lngs = centers.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        return MKCoordinateRegion(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2),
            span: .init(latitudeDelta: (maxLat - minLat) * 1.4 + 0.1,
                        longitudeDelta: (maxLng - minLng) * 1.4 + 0.1)
        )
    }
}

private struct Coordinate: Codable {
    let lat: Double
    let lng: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        lat = coordinate.latitude
        lng = coordinate.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        .init(latitude: lat, longitude: lng)
    }
}

private struct CacheData: Codable {
    var coords: [String: Coordinate]
    var misses: [String]
}
