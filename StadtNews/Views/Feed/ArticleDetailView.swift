import SwiftUI

struct ArticleDetailView: View {
    @StateObject private var viewModel: ArticleDetailViewModel
    @State private var showingSafari = false

    init(article: Article) {
        _viewModel = StateObject(wrappedValue: ArticleDetailViewModel(article: article))
    }

    private var article: Article { viewModel.article }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header

                Hairline()

                bodyView

                if viewModel.isLoading {
                    loadingRow
                } else if viewModel.loadFailed && !viewModel.loadedFull {
                    failureNote
                }

                if let contact = viewModel.contact {
                    contactBlock(contact)
                }

                originalLink

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.top, Theme.Spacing.md)
        }
        .background(Theme.Color.paper.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Masthead(compact: true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: article.url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.Color.ink)
                }
            }
        }
        .task {
            await viewModel.loadFullContent()
        }
        .sheet(isPresented: $showingSafari) {
            SafariView(url: article.url)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            KickerLabel(text: article.cityName)

            Text(article.title)
                .font(Theme.Font.articleTitle)
                .foregroundStyle(Theme.Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Text(article.source)
                    .foregroundStyle(Theme.Color.ink)
                    .fontWeight(.semibold)
                if let date = article.publishedAt {
                    MetaDot()
                    Text(date.newsAbsoluteDescription())
                        .foregroundStyle(Theme.Color.secondaryInk)
                }
            }
            .font(Theme.Font.meta)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if viewModel.paragraphs.isEmpty && viewModel.isLoading {
            // No teaser available – show placeholder lines while loading.
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    Text("Platzhalter Textzeile für die Meldung")
                        .font(Theme.Font.articleBody)
                        .redacted(reason: .placeholder)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ForEach(Array(viewModel.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(Theme.Font.articleBody)
                        .foregroundStyle(Theme.Color.ink)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView()
            Text("Vollständige Meldung wird geladen …")
                .font(Theme.Font.meta)
                .foregroundStyle(Theme.Color.tertiaryInk)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var failureNote: some View {
        Text("Die vollständige Meldung konnte nicht geladen werden. Sie können sie im Original lesen.")
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.Color.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func contactBlock(_ contact: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            KickerLabel(text: "Kontakt & Quelle", color: Theme.Color.tertiaryInk)
            Text(contact)
                .font(.system(.footnote, design: .default))
                .foregroundStyle(Theme.Color.secondaryInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Color.surface)
        )
    }

    private var originalLink: some View {
        Button {
            showingSafari = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "safari")
                Text("Im Original lesen")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .font(.system(.subheadline, design: .default).weight(.semibold))
            .foregroundStyle(Theme.Color.brand)
            .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
