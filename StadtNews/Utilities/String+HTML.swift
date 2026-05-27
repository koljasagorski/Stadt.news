import Foundation

extension String {
    /// Converts a fragment of HTML (as found in Presseportal `content:encoded`
    /// or `description`) into clean, readable plain text with paragraph breaks.
    ///
    /// This is intentionally lightweight (no `NSAttributedString` HTML import,
    /// which is slow and main-thread only) so it is safe to run off the main
    /// actor while parsing the feed.
    func htmlToPlainText() -> String {
        var text = self

        // Line breaks.
        for tag in ["<br>", "<br/>", "<br />"] {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // Block-level closings become paragraph breaks.
        let blockClosings = ["</p>", "</div>", "</li>", "</ul>", "</ol>",
                             "</h1>", "</h2>", "</h3>", "</h4>", "</h5>",
                             "</tr>", "</table>", "</blockquote>"]
        for tag in blockClosings {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        // List items get a bullet.
        text = text.replacingOccurrences(of: "<li>", with: "•\u{00A0}", options: .caseInsensitive)

        // Strip every remaining tag.
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode entities, then normalise whitespace.
        text = text.decodingHTMLEntities()
        text = text.replacingOccurrences(of: "\r", with: "")
        text = text.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes a leading Presseportal press code such as "POL-GE: " or
    /// "BPOL NRW: " so headlines read cleanly.
    func removingPressCodePrefix() -> String {
        let pattern = "^[A-ZÄÖÜ0-9]{2,}(?:[ -][A-ZÄÖÜ0-9]+)*:\\s*"
        guard let range = self.range(of: pattern, options: [.regularExpression]) else {
            return self
        }
        return String(self[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    /// Removes a leading press dateline such as "Gelsenkirchen (ots) - " so the
    /// teaser starts with the actual content.
    func removingDatelinePrefix() -> String {
        guard let range = self.range(of: "(ots)"),
              distance(from: startIndex, to: range.lowerBound) <= 40 else {
            return self
        }
        var rest = self[range.upperBound...]
        while let first = rest.first,
              first == " " || first == "-" || first == "–" || first == ":" || first == "\u{00A0}" {
            rest = rest.dropFirst()
        }
        let result = String(rest).trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? self : result
    }

    /// Decodes the HTML entities commonly seen in German press feeds,
    /// including numeric (decimal and hex) references.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": "\u{00A0}",
            "&hellip;": "…", "&ndash;": "–", "&mdash;": "—",
            "&euro;": "€", "&laquo;": "«", "&raquo;": "»",
            "&bdquo;": "„", "&ldquo;": "“", "&rdquo;": "”",
            "&sbquo;": "‚", "&lsquo;": "‘", "&rsquo;": "’",
            "&auml;": "ä", "&ouml;": "ö", "&uuml;": "ü",
            "&Auml;": "Ä", "&Ouml;": "Ö", "&Uuml;": "Ü",
            "&szlig;": "ß", "&deg;": "°", "&copy;": "©",
            "&middot;": "·", "&bull;": "•", "&times;": "×",
        ]

        var result = self
        for (entity, value) in named {
            result = result.replacingOccurrences(of: entity, with: value)
        }

        // Numeric references: &#123; and &#x1F;
        result = result.replacingOccurrences(
            of: "&#[xX]?[0-9A-Fa-f]+;",
            with: "",
            options: .regularExpression
        ) { match in
            let inner = match.dropFirst(2).dropLast()
            if let first = inner.first, first == "x" || first == "X" {
                guard let code = UInt32(inner.dropFirst(), radix: 16),
                      let scalar = Unicode.Scalar(code) else { return match }
                return String(Character(scalar))
            } else {
                guard let code = UInt32(inner), let scalar = Unicode.Scalar(code) else { return match }
                return String(Character(scalar))
            }
        }

        // Resolve "&amp;" produced literally last to avoid double-decoding.
        return result
    }
}

private extension String {
    /// `replacingOccurrences(of:with:options:)` variant that maps each regex
    /// match through a transform closure.
    func replacingOccurrences(
        of pattern: String,
        with template: String,
        options: String.CompareOptions,
        _ transform: (String) -> String
    ) -> String {
        guard options.contains(.regularExpression),
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        let nsString = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else { return self }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let range = match.range
            result += nsString.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
            let matched = nsString.substring(with: range)
            result += transform(matched)
            lastEnd = range.location + range.length
        }
        result += nsString.substring(from: lastEnd)
        return result
    }
}
