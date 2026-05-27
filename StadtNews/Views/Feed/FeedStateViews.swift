import SwiftUI

/// Redacted placeholder shown during the initial load.
struct FeedSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            placeholder(lines: 3, headline: Theme.Font.featuredHeadline, summary: true)
            Hairline()
            ForEach(0..<4, id: \.self) { _ in
                placeholder(lines: 2, headline: Theme.Font.headline, summary: false)
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private func placeholder(lines: Int, headline: Font, summary: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("GELSENKIRCHEN")
                .font(Theme.Font.kicker)
            Text(String(repeating: "Schlagzeile Text ", count: lines))
                .font(headline)
                .lineLimit(lines)
            if summary {
                Text("Eine kurze Zusammenfassung der Meldung, die hier als Platzhalter dient.")
                    .font(Theme.Font.summary)
            }
            Text("Polizei Gelsenkirchen · vor 2 Std.")
                .font(Theme.Font.meta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Centered empty / error state with an optional action.
struct FeedMessageView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Theme.Color.tertiaryInk)

            Text(title)
                .font(Theme.Font.secondaryHeadline)
                .foregroundStyle(Theme.Color.ink)

            Text(message)
                .font(Theme.Font.summary)
                .foregroundStyle(Theme.Color.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(Theme.Color.brand)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.md)
                        .overlay(
                            Capsule().stroke(Theme.Color.brand, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.section)
    }
}
