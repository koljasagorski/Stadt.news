import Foundation

/// Full article text extracted natively from a Presseportal article page.
struct ArticleContent: Sendable {
    let bodyParagraphs: [String]
    let contact: String?

    var isEmpty: Bool { bodyParagraphs.isEmpty && (contact?.isEmpty ?? true) }
}

/// Loads and parses the full text of a press release.
///
/// The RSS feed only contains a truncated teaser ("… Lesen Sie hier weiter…"),
/// so the complete article is fetched from its web page and the body /
/// contact block are extracted natively. Results are cached per URL.
actor ArticleContentService {
    static let shared = ArticleContentService()

    private let session: URLSession
    private var cache: [URL: ArticleContent] = [:]

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    func fullContent(for url: URL) async throws -> ArticleContent {
        if let cached = cache[url] { return cached }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Stadt.news/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NewsServiceError.badResponse(http.statusCode)
        }

        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let content = ArticleHTMLExtractor.extract(from: html)
        cache[url] = content
        return content
    }
}

/// Extracts the body and contact block from a Presseportal press-release page.
///
/// Handles both page layouts: contact shown inline, and contact behind a
/// "Kontaktdaten anzeigen" toggle. Falls back to empty results (so the caller
/// keeps showing the teaser) if the expected structure is not found.
enum ArticleHTMLExtractor {
    static func extract(from html: String) -> ArticleContent {
        let ns = html as NSString
        let length = ns.length

        func indexOf(_ sub: String, from: Int) -> Int? {
            guard from >= 0, from <= length else { return nil }
            let range = ns.range(of: sub, options: [], range: NSRange(location: from, length: length - from))
            return range.location == NSNotFound ? nil : range.location
        }
        func lastIndexOf(_ sub: String, from: Int, to: Int) -> Int? {
            guard from >= 0, from < to, to <= length else { return nil }
            let range = ns.range(of: sub, options: .backwards, range: NSRange(location: from, length: to - from))
            return range.location == NSNotFound ? nil : range.location
        }

        // The contact / attribution block always begins with one of these.
        let endMarkers = ["contact-headline", "mod-toggle", "Rückfragen bitte an",
                          "Nachfragen für Journalist", "originator", "Original-Content von"]

        // MARK: Body – between the "(ots)" dateline and the contact block.
        var bodyParagraphs: [String] = []
        if let city = indexOf("story-city", from: 0),
           let datelineEnd = indexOf("</p>", from: city) {
            let bodyStart = datelineEnd + 4
            var markerPos = length
            for marker in endMarkers {
                if let pos = indexOf(marker, from: bodyStart) { markerPos = min(markerPos, pos) }
            }
            let bodyEnd = lastIndexOf("<", from: bodyStart, to: markerPos) ?? markerPos
            if bodyStart < bodyEnd {
                let bodyHTML = ns.substring(with: NSRange(location: bodyStart, length: bodyEnd - bodyStart))
                bodyParagraphs = paragraphs(from: bodyHTML)
            }
        }

        // MARK: Contact – from the contact headline to the end of the attribution line.
        var contact: String?
        if let headline = indexOf("contact-headline", from: 0) {
            let contactStart = lastIndexOf("<", from: 0, to: headline) ?? headline
            var contactEnd = length
            if let originator = indexOf("originator", from: contactStart),
               let paragraphEnd = indexOf("</p>", from: originator) {
                contactEnd = paragraphEnd + 4
            } else if let contactText = indexOf("contact-text", from: contactStart),
                      let paragraphEnd = indexOf("</p>", from: contactText) {
                contactEnd = paragraphEnd + 4
            } else {
                contactEnd = min(length, contactStart + 1200)
            }
            if contactStart < contactEnd {
                let chunk = ns.substring(with: NSRange(location: contactStart, length: contactEnd - contactStart))
                let text = chunk.htmlToPlainText()
                contact = text.isEmpty ? nil : text
            }
        }

        return ArticleContent(bodyParagraphs: bodyParagraphs, contact: contact)
    }

    private static func paragraphs(from html: String) -> [String] {
        html.htmlToPlainText()
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
