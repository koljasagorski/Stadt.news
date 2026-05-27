import Foundation

/// On-disk cache of the last successfully loaded feed. Lets the app show
/// articles instantly on launch and refresh in the background, instead of
/// waiting for a cold network fetch every time.
struct FeedCache: Sendable {
    static let shared = FeedCache()

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("feed-cache.json")
    }()

    func load() -> [Article] {
        guard let data = try? Data(contentsOf: fileURL),
              let articles = try? JSONDecoder().decode([Article].self, from: data) else {
            return []
        }
        return articles
    }

    func save(_ articles: [Article]) {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
