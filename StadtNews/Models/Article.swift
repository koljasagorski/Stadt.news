import Foundation

/// A single news item, parsed natively from a Presseportal RSS feed.
struct Article: Identifiable, Hashable, Sendable {
    let id: String
    /// Display headline with the "POL-XX:" press code removed.
    let title: String
    /// Short plain-text teaser.
    let summary: String
    /// Full plain-text body (press-code and HTML removed).
    let body: String
    /// Trailing contact / attribution block, shown as a styled footer.
    let contact: String?
    /// Link to the original press release.
    let url: URL
    let publishedAt: Date?
    let cityID: String
    let cityName: String
    /// Publishing authority, e.g. "Polizei Gelsenkirchen".
    let source: String

    var hasBody: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Body split into display paragraphs.
    var paragraphs: [String] {
        body
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension Article {
    init?(item: RSSItem, city: City) {
        let link = item.link.isEmpty ? item.guid : item.link
        guard let url = URL(string: link) else { return nil }

        let cleanTitle = item.title.htmlToPlainText()
        guard !cleanTitle.isEmpty else { return nil }

        let displayTitle = cleanTitle.removingPressCodePrefix()
        let fullHTML = item.contentEncoded.isEmpty ? item.description : item.contentEncoded
        let (body, footer) = fullHTML.htmlToPlainText().splittingBodyAndFooter()

        self.init(
            id: item.guid.isEmpty ? link : item.guid,
            title: displayTitle.isEmpty ? cleanTitle : displayTitle,
            summary: item.description.htmlToPlainText(),
            body: body,
            contact: footer,
            url: url,
            publishedAt: DateParsing.rfc2822.date(from: item.pubDate),
            cityID: city.id,
            cityName: city.name,
            source: city.source
        )
    }
}
