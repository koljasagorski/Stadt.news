import SwiftUI
import SafariServices

/// In-app browser used to show the original press release.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(Theme.Color.brand)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
