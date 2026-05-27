import SwiftUI

struct MainView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showingSettings = false
    @State private var showingMap = false
    @State private var showingBookmarks = false

    var body: some View {
        NavigationStack {
            NewsFeedView(cities: settings.selectedCities)
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingMap = true
                        } label: {
                            Image(systemName: "map")
                                .foregroundStyle(Theme.Color.ink)
                        }
                        .accessibilityLabel("Karte")
                    }
                    ToolbarItem(placement: .principal) {
                        Masthead(compact: true)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingBookmarks = true
                        } label: {
                            Image(systemName: "bookmark")
                                .foregroundStyle(Theme.Color.ink)
                        }
                        .accessibilityLabel("Gemerkte Meldungen")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Theme.Color.ink)
                        }
                        .accessibilityLabel("Einstellungen")
                    }
                }
                .toolbarBackground(Theme.Color.paper, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.Color.brand)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingMap) {
            IncidentMapView(cities: settings.selectedCities)
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksView()
        }
    }
}
