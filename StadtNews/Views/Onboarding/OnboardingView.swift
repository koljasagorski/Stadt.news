import SwiftUI

/// First-launch experience: choose one or more cities to follow.
struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var selection: Set<String> = [City.gelsenkirchen.id]
    @State private var query = ""

    private var filteredCities: [City] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return City.catalog }
        return City.catalog.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.state.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            cityList

            footer
        }
        .background(Theme.Color.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Masthead()
                .padding(.top, Theme.Spacing.sm)

            Text("Lokale Nachrichten,\ndie zählen.")
                .font(Theme.Font.featuredHeadline)
                .foregroundStyle(Theme.Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Wählen Sie die Städte, deren Meldungen Sie verfolgen möchten. Sie können Ihre Auswahl jederzeit in den Einstellungen ändern.")
                .font(Theme.Font.summary)
                .foregroundStyle(Theme.Color.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            searchField
                .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.pageMargin)
        .padding(.bottom, Theme.Spacing.md)
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Color.tertiaryInk)
            TextField("Stadt suchen", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .font(.system(.body, design: .default))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Color.surface)
        )
    }

    private var cityList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredCities) { city in
                    CitySelectionRow(
                        city: city,
                        isSelected: selection.contains(city.id)
                    ) {
                        toggle(city)
                    }
                    .padding(.horizontal, Theme.pageMargin)

                    if city.id != filteredCities.last?.id {
                        Hairline().padding(.leading, Theme.pageMargin)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Hairline()
            Button(action: continueTapped) {
                Text(selection.isEmpty ? "Mindestens eine Stadt wählen" : "Weiter")
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !selection.isEmpty))
            .disabled(selection.isEmpty)
            .padding(.horizontal, Theme.pageMargin)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(Theme.Color.paper)
    }

    private func toggle(_ city: City) {
        withAnimation(.easeOut(duration: 0.15)) {
            if selection.contains(city.id) {
                selection.remove(city.id)
            } else {
                selection.insert(city.id)
            }
        }
    }

    private func continueTapped() {
        // Preserve catalog order for a tidy feed.
        settings.selectedCityIDs = City.catalog.map(\.id).filter { selection.contains($0) }
        withAnimation(.easeInOut(duration: 0.3)) {
            settings.completeOnboarding()
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
