import SwiftUI

/// List of bookmarked ("gemerkte") articles.
struct BookmarksView: View {
    @ObservedObject private var bookmarks = BookmarkStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.articles.isEmpty {
                    FeedMessageView(
                        systemImage: "bookmark",
                        title: "Noch nichts gemerkt",
                        message: "Tippen Sie in einer Meldung oben auf das Lesezeichen-Symbol, um sie hier zu speichern.",
                        actionTitle: nil,
                        action: nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bookmarks.articles) { article in
                            NavigationLink(value: article) {
                                ArticleRowView(article: article, showCity: false)
                            }
                            .listRowBackground(Theme.Color.surface)
                        }
                        .onDelete { bookmarks.remove(at: $0) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.Color.paper.ignoresSafeArea())
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Masthead(compact: true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.Color.brand)
                }
            }
        }
    }
}
