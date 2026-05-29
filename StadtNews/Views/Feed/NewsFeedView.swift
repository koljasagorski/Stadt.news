import SwiftUI

struct NewsFeedView: View {
    let cities: [City]

    @StateObject private var viewModel = NewsFeedViewModel()
    @ObservedObject private var router = DeepLinkRouter.shared
    @State private var cityFilter: String?
    @State private var sourceFilter: NewsSource?
    @State private var searchText = ""
    @State private var safariFallback: IdentifiableURL?

    /// Filter restricted to currently selected cities (guards against a stale
    /// filter after the user changes their selection in settings).
    private var effectiveFilter: String? {
        guard let cityFilter, cities.contains(where: { $0.id == cityFilter }) else { return nil }
        return cityFilter
    }

    /// Sources actually present in the loaded feed, in catalog order.
    private var availableSources: [NewsSource] {
        let present = Set(viewModel.articles.map(\.newsSource))
        return NewsSource.allCases.filter { present.contains($0) }
    }

    private var visibleArticles: [Article] {
        var result = viewModel.articles(forCityID: effectiveFilter)
        if let sourceFilter {
            result = result.filter { $0.newsSource == sourceFilter }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedStandardContains(query)
                    || $0.summary.localizedStandardContains(query)
            }
        }
        return result
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

                if availableSources.count > 1 {
                    sourceFilterBar
                }

                content
            }
        }
        .background(Theme.Color.paper.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Meldungen durchsuchen")
        .refreshable {
            await viewModel.refresh(cities: cities)
        }
        .task(id: cities.map(\.id)) {
            await viewModel.load(cities: cities)
        }
        .onChange(of: router.pendingArticleURL, initial: true) { _, _ in resolvePendingDeepLink() }
        .onChange(of: viewModel.articles, initial: true) { _, _ in resolvePendingDeepLink() }
        .sheet(item: $safariFallback) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
    }

    /// Resolves a pending push-tap URL against the loaded feed. If a matching
    /// article exists, it is pushed onto the navigation stack; otherwise – once
    /// the feed is non-empty – the URL is opened in the in-app Safari sheet so
    /// the tap is never lost.
    private func resolvePendingDeepLink() {
        guard let url = router.pendingArticleURL else { return }
        if let match = viewModel.articles.first(where: { $0.url == url }) {
            router.path.append(match)
            router.pendingArticleURL = nil
        } else if !viewModel.articles.isEmpty {
            safariFallback = IdentifiableURL(url: url)
            router.pendingArticleURL = nil
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

    private var sourceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                CityChip(title: "Alle", isSelected: sourceFilter == nil) {
                    withAnimation(.easeOut(duration: 0.15)) { sourceFilter = nil }
                }
                ForEach(availableSources) { source in
                    CityChip(title: source.label, isSelected: sourceFilter == source) {
                        withAnimation(.easeOut(duration: 0.15)) { sourceFilter = source }
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

/// Local wrapper to give `URL` an `Identifiable` conformance for `.sheet(item:)`
/// without exporting a module-wide extension that could collide with libraries.
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
}
