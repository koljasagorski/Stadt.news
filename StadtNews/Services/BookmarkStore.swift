import Foundation
import Combine

/// Stores bookmarked ("gemerkte") articles, persisted in `UserDefaults`.
///
/// A shared singleton (rather than an `@EnvironmentObject`) so it can be used
/// from anywhere – including article views presented from nested sheets like
/// the map – without risking a missing-environment crash.
@MainActor
final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var articles: [Article]

    private let defaults: UserDefaults
    private let key = "bookmarkedArticles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Article].self, from: data) {
            articles = decoded
        } else {
            articles = []
        }
    }

    func isBookmarked(_ article: Article) -> Bool {
        articles.contains { $0.id == article.id }
    }

    func toggle(_ article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles.remove(at: index)
        } else {
            articles.insert(article, at: 0)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        articles.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(articles), forKey: key)
    }
}
