import Foundation
import Combine

@MainActor
final class NewsFeedViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var articles: [Article] = []
    @Published private(set) var failedCities: [City] = []
    @Published private(set) var lastUpdated: Date?

    private let service: NewsService
    private let cache: FeedCache

    init(service: NewsService = .shared, cache: FeedCache = .shared) {
        self.service = service
        self.cache = cache
    }

    /// Loads the feed. On the first load the cached feed is shown instantly
    /// (if present) and refreshed in the background; otherwise a loading state
    /// is shown. Pull-to-refresh keeps the existing articles visible.
    func load(cities: [City]) async {
        guard !cities.isEmpty else {
            articles = []
            failedCities = []
            phase = .loaded
            return
        }

        if articles.isEmpty {
            let cityIDs = Set(cities.map(\.id))
            let cached = cache.load().filter { cityIDs.contains($0.cityID) }
            if cached.isEmpty {
                phase = .loading
            } else {
                articles = cached
                phase = .loaded
            }
        }

        let result = await service.feed(for: cities)

        if result.articles.isEmpty {
            if result.failedCities.isEmpty {
                // Reached the source(s) but there is genuinely nothing to show.
                articles = []
                failedCities = []
                phase = .loaded
            } else if articles.isEmpty {
                // Could not load anything and have no cached content.
                phase = .failed(NewsServiceError.emptyFeed.localizedDescription)
            } else {
                // A refresh failed – keep the articles already on screen.
                phase = .loaded
            }
            return
        }

        articles = result.articles
        failedCities = result.failedCities
        lastUpdated = Date()
        phase = .loaded

        let toCache = result.articles
        Task.detached { [cache] in cache.save(toCache) }
    }

    func refresh(cities: [City]) async {
        await load(cities: cities)
    }

    func articles(forCityID cityID: String?) -> [Article] {
        guard let cityID else { return articles }
        return articles.filter { $0.cityID == cityID }
    }
}
