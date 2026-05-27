import SwiftUI

/// Standard story in the feed list.
struct ArticleRowView: View {
    let article: Article
    var showCity: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if showCity {
                KickerLabel(text: article.cityName)
            }

            Text(article.title)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(Theme.Font.summary)
                    .foregroundStyle(Theme.Color.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ArticleMetaLine(article: article)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// "Polizei Gelsenkirchen · vor 3 Std." metadata row.
struct ArticleMetaLine: View {
    let article: Article

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(article.source)
                .lineLimit(1)
            if let date = article.publishedAt {
                MetaDot()
                Text(date.newsRelativeDescription())
            }
        }
        .font(Theme.Font.meta)
        .foregroundStyle(Theme.Color.tertiaryInk)
    }
}

/// Large lead story shown at the top of the feed.
struct FeaturedArticleView: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            KickerLabel(text: article.cityName)

            Text(article.title)
                .font(Theme.Font.featuredHeadline)
                .foregroundStyle(Theme.Color.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.Color.secondaryInk)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ArticleMetaLine(article: article)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
