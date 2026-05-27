import Foundation

enum NewsServiceError: LocalizedError {
    case badResponse(Int)
    case emptyFeed

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "Der Server hat unerwartet geantwortet (Code \(code))."
        case .emptyFeed:
            return "Es konnten keine Meldungen geladen werden."
        }
    }
}

/// Result of loading several cities at once. Loading is resilient: a single
/// failing city does not prevent the others from being shown.
struct FeedResult: Sendable {
    var articles: [Article]
    var failedCities: [City]
}

/// Fetches and natively parses Presseportal RSS feeds.
final class NewsService: Sendable {
    static let shared = NewsService()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadRevalidatingCacheData
            config.timeoutIntervalForRequest = 20
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    /// Loads and parses a single city's feed.
    func articles(for city: City) async throws -> [Article] {
        var request = URLRequest(url: city.feedURL)
        request.setValue("Stadt.news/1.0 (iOS; native RSS reader)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml;q=0.9", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NewsServiceError.badResponse(http.statusCode)
        }

        let items = RSSParser().parse(data)
        let articles = items.compactMap { Article(item: $0, city: city) }
        return articles
    }

    private struct CityOutcome: Sendable {
        let city: City
        let articles: [Article]?
    }

    /// Loads multiple cities concurrently and merges the results, newest first.
    func feed(for cities: [City]) async -> FeedResult {
        guard !cities.isEmpty else { return FeedResult(articles: [], failedCities: []) }

        let outcomes = await withTaskGroup(of: CityOutcome.self) { group -> [CityOutcome] in
            for city in cities {
                group.addTask {
                    let articles = try? await self.articles(for: city)
                    return CityOutcome(city: city, articles: articles)
                }
            }
            var collected: [CityOutcome] = []
            for await outcome in group {
                collected.append(outcome)
            }
            return collected
        }

        var articles: [Article] = []
        var failed: [City] = []
        for outcome in outcomes {
            if let cityArticles = outcome.articles {
                articles.append(contentsOf: cityArticles)
            } else {
                failed.append(outcome.city)
            }
        }

        // De-duplicate by id, then sort newest first.
        var seen = Set<String>()
        let unique = articles.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }

        return FeedResult(articles: sorted, failedCities: failed)
    }
}
