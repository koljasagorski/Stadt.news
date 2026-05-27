import Foundation

/// Reads the prebuilt feed from the Cloudflare worker (see `worker/`).
///
/// Returns `nil` when the backend isn't configured yet or the request fails,
/// so `NewsService` transparently falls back to fetching the RSS feeds
/// directly on-device. Set `baseURL` to the deployed worker URL to enable it.
final class RemoteFeedService: Sendable {
    static let shared = RemoteFeedService()

    /// Deployed worker URL, e.g. "https://gelsenkirchen-news.<subdomain>.workers.dev".
    /// Leave empty to keep using the on-device RSS path.
    static let baseURL = "https://gelsenkirchen-news.vwcampermieten.workers.dev"

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadRevalidatingCacheData
            config.timeoutIntervalForRequest = 15
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    private struct Envelope: Decodable {
        let articles: [Article]
    }

    func feed(for cities: [City]) async -> FeedResult? {
        guard !Self.baseURL.isEmpty,
              let url = URL(string: Self.baseURL + "/v1/feed") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Gelsenkirchen.news/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)

            let ids = Set(cities.map(\.id))
            let filtered = envelope.articles.filter { ids.contains($0.cityID) }
            return filtered.isEmpty ? nil : FeedResult(articles: filtered, failedCities: [])
        } catch {
            return nil
        }
    }
}
