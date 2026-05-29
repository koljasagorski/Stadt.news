import Foundation
import Combine

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    /// Paragraphs to display – the teaser first, replaced by the full text
    /// once it has loaded.
    @Published private(set) var paragraphs: [String]
    @Published private(set) var contact: String?
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    @Published private(set) var loadedFull = false

    let article: Article
    private let service: ArticleContentService

    init(article: Article, service: ArticleContentService = .shared) {
        self.article = article
        self.service = service
        if let body = article.body, !body.isEmpty {
            // Full text already delivered by the backend – show it instantly
            // (works offline too) and skip the on-device page fetch.
            self.paragraphs = body
            self.contact = article.contact
            self.loadedFull = true
        } else {
            let teaser = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            self.paragraphs = teaser.isEmpty ? [] : [teaser]
        }
    }

    func loadFullContent() async {
        guard !loadedFull, !isLoading else { return }
        isLoading = true
        loadFailed = false

        do {
            let content = try await service.fullContent(for: article.url)
            if let contact = content.contact, !contact.isEmpty {
                self.contact = contact
            }
            if content.bodyParagraphs.isEmpty {
                // Couldn't parse the full text – keep the teaser and nudge the
                // reader to the original.
                loadFailed = true
            } else {
                paragraphs = content.bodyParagraphs
                loadedFull = true
            }
        } catch {
            loadFailed = true
        }

        isLoading = false
    }
}
