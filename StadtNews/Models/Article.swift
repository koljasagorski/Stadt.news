import Foundation

/// A single news item, parsed natively from a Presseportal RSS feed.
///
/// The feed only carries a short teaser; the full text is loaded on demand
/// from the article page (see `ArticleContentService`).
struct Article: Identifiable, Hashable, Sendable {
    let id: String
    /// Display headline with the "POL-XX:" press code removed.
    let title: String
    /// Short plain-text teaser from the feed.
    let summary: String
    /// Link to the original press release.
    let url: URL
    let publishedAt: Date?
    let cityID: String
    let cityName: String
    /// Publishing authority, e.g. "Polizei Gelsenkirchen".
    let source: String
}

extension Article {
    init?(item: RSSItem, city: City) {
        let link = item.link.isEmpty ? item.guid : item.link
        guard let url = URL(string: link) else { return nil }

        let cleanTitle = item.title.htmlToPlainText()
        guard !cleanTitle.isEmpty else { return nil }
        let displayTitle = cleanTitle.removingPressCodePrefix()

        self.init(
            id: item.guid.isEmpty ? link : item.guid,
            title: displayTitle.isEmpty ? cleanTitle : displayTitle,
            summary: item.description.htmlToPlainText().removingDatelinePrefix(),
            url: url,
            publishedAt: DateParsing.rfc2822.date(from: item.pubDate),
            cityID: city.id,
            cityName: city.name,
            source: city.source
        )
    }
}
