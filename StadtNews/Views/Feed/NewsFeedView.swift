import SwiftUI

struct NewsFeedView: View {
    let cities: [City]

    @StateObject private var viewModel = NewsFeedViewModel()
    @State private var cityFilter: String?

    /// Filter restricted to currently selected cities (guards against a stale
    /// filter after the user changes their selection in settings).
    private var effectiveFilter: String? {
        guard let cityFilter, cities.contains(where: { $0.id == cityFilter }) else { return nil }
        return cityFilter
    }

    private var visibleArticles: [Article] {
        viewModel.articles(forCityID: effectiveFilter)
    }

    private var showsCityKicker: Bool {
        effectiveFilter == nil && cities.count > 1
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                dateline

                if cities.count > 1 {
                    cityFilterBar
                }

                content
            }
        }
        .background(Theme.Color.paper.ignoresSafeArea())
        .refreshable {
            await viewModel.refresh(cities: cities)
        }
        .task(id: cities.map(\.id)) {
            await viewModel.load(cities: cities)
        }
    }

    // MARK: Sections

    private var dateline: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(Self.datelineText)
                .font(.system(.caption, design: .default).weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.Color.secondaryInk)
            Hairline()
        }
        .padding(.horizontal, Theme.pageMargin)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.md)
    }

    private var cityFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                CityChip(title: "Alle", isSelected: effectiveFilter == nil) {
                    withAnimation(.easeOut(duration: 0.15)) { cityFilter = nil }
                }
                ForEach(cities) { city in
                    CityChip(title: city.name, isSelected: effectiveFilter == city.id) {
                        withAnimation(.easeOut(duration: 0.15)) { cityFilter = city.id }
                    }
                }
            }
            .padding(.horizontal, Theme.pageMargin)
        }
        .padding(.bottom, Theme.Spacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .failed(let message):
            FeedMessageView(
                systemImage: "wifi.exclamationmark",
                title: "Keine Verbindung",
                message: message,
                actionTitle: "Erneut versuchen"
            ) {
                Task { await viewModel.refresh(cities: cities) }
            }
            .padding(.top, Theme.Spacing.section)
        case .idle:
            FeedSkeletonView().padding(.horizontal, Theme.pageMargin)
        case .loading:
            if viewModel.articles.isEmpty {
                FeedSkeletonView().padding(.horizontal, Theme.pageMargin)
            } else {
                articleList
            }
        case .loaded:
            articleList
        }
    }

    @ViewBuilder
    private var articleList: some View {
        if visibleArticles.isEmpty {
            FeedMessageView(
                systemImage: "newspaper",
                title: "Noch keine Meldungen",
                message: "Für diese Auswahl liegen derzeit keine Meldungen vor.",
                actionTitle: nil,
                action: nil
            )
            .padding(.top, Theme.Spacing.section)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink(value: visibleArticles[0]) {
                    FeaturedArticleView(article: visibleArticles[0])
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.pageMargin)

                ForEach(visibleArticles.dropFirst()) { article in
                    VStack(spacing: 0) {
                        Hairline()
                            .padding(.vertical, Theme.Spacing.xl)
                        NavigationLink(value: article) {
                            ArticleRowView(article: article, showCity: showsCityKicker)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.pageMargin)
                }
            }
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.section)
        }
    }

    private static let datelineText: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "EEEE, d. MMMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }()
}
