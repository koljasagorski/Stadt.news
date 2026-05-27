import SwiftUI

/// A single selectable city row, shared by onboarding and settings.
struct CitySelectionRow: View {
    let city: City
    let isSelected: Bool
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.Color.ink)
                    Text(city.state)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Color.secondaryInk)
                }

                Spacer(minLength: Theme.Spacing.md)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Theme.Color.brand : Theme.Color.hairline,
                            lineWidth: isSelected ? 0 : 1.5
                        )
                        .background(
                            Circle().fill(isSelected ? Theme.Color.brand : .clear)
                        )
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.Color.paper)
                    }
                }
                .opacity(isLocked ? 0.5 : 1)
            }
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}
