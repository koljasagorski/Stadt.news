import Foundation
import SwiftUI

/// Routes external navigation requests (currently: push notification taps) into
/// the app. `PushService` writes the tapped article's URL here; `NewsFeedView`
/// resolves it against the loaded feed and appends the matching article to
/// `path`. If no match is found once the feed is loaded, callers fall back to
/// opening the URL in the in-app Safari sheet.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    /// Backs the main `NavigationStack` so external callers can push views.
    @Published var path = NavigationPath()

    /// URL of an article the user opened from a push but that hasn't been
    /// resolved into a navigation yet. `nil` once consumed.
    @Published var pendingArticleURL: URL?

    private init() {}

    func openArticle(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        pendingArticleURL = url
    }
}
