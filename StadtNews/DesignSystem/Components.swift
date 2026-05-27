import SwiftUI

/// Uppercase, letter-spaced category label – the "kicker" above a headline.
struct KickerLabel: View {
    let text: String
    var color: Color = Theme.Color.brand

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Font.kicker)
            .tracking(1.3)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// A thin editorial rule.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Color.hairline)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// Small dot used to separate metadata items.
struct MetaDot: View {
    var body: some View {
        Circle()
            .fill(Theme.Color.tertiaryInk)
            .frame(width: 3, height: 3)
    }
}

/// The "Stadt.news" nameplate.
struct Masthead: View {
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            Text("Stadt")
                .foregroundStyle(Theme.Color.ink)
            Text(".news")
                .foregroundStyle(Theme.Color.brand)
        }
        .font(compact ? Theme.Font.mastheadCompact : Theme.Font.masthead)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Stadt.news")
    }
}

/// A selectable city pill used in the feed's city filter bar.
struct CityChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(isSelected ? Theme.Color.paper : Theme.Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? Theme.Color.ink : Theme.Color.surface)
                )
                .overlay(
                    Capsule().stroke(Theme.Color.hairline, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Standard primary action button (filled, editorial red).
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .default).weight(.semibold))
            .foregroundStyle(Theme.Color.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(enabled ? Theme.Color.brand : Theme.Color.tertiaryInk)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
