import Foundation

/// Raw fields of a single `<item>` in a Presseportal RSS feed.
struct RSSItem: Sendable {
    var title = ""
    var link = ""
    var guid = ""
    var description = ""
    var contentEncoded = ""
    var pubDate = ""
}

/// Streaming RSS parser built on Foundation's `XMLParser`.
///
/// A parser instance is single-use and not thread-safe; create a fresh one
/// per feed (see `RSSService`).
final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []
    private var current: RSSItem?
    private var buffer = ""
    private var insideItem = false

    func parse(_ data: Data) -> [RSSItem] {
        items = []
        current = nil
        buffer = ""
        insideItem = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" {
            insideItem = true
            current = RSSItem()
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            buffer += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        defer { buffer = "" }

        guard insideItem else { return }

        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title":             current?.title = text
        case "link":              current?.link = text
        case "guid":              current?.guid = text
        case "description":       current?.description = text
        case "content:encoded", "encoded": current?.contentEncoded = text
        case "pubDate":           current?.pubDate = text
        case "item":
            if let current { items.append(current) }
            current = nil
            insideItem = false
        default:
            break
        }
    }
}
