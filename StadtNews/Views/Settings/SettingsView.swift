import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var filteredCities: [City] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return City.catalog }
        return City.catalog.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.state.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                citiesSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.paper.ignoresSafeArea())
            .searchable(text: $query, prompt: "Stadt suchen")
            .navigationTitle("Einstellungen")
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

    private var citiesSection: some View {
        Section {
            ForEach(filteredCities) { city in
                cityRow(city)
            }
        } header: {
            Text("Meine Städte")
        } footer: {
            Text("Tippen Sie auf eine Stadt, um sie hinzuzufügen oder zu entfernen. Mindestens eine Stadt muss ausgewählt sein.")
        }
    }

    private func cityRow(_ city: City) -> some View {
        let isSelected = settings.isSelected(city)
        let isLast = isSelected && settings.selectedCityIDs.count == 1

        return Button {
            withAnimation(.easeOut(duration: 0.15)) { settings.toggle(city) }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(city.name)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.Color.ink)
                    Text(city.source)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Color.secondaryInk)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.Color.brand : Theme.Color.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLast)
        .listRowBackground(Theme.Color.surface)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Quelle", value: "presseportal.de")
            LabeledContent("Bereitgestellt durch", value: "news aktuell")
            LabeledContent("Version", value: Self.appVersion)
        } header: {
            Text("Über Stadt.news")
        } footer: {
            Text("Stadt.news bündelt offizielle Polizeimeldungen aus dem Presseportal (news aktuell GmbH). Alle Rechte an den Inhalten verbleiben bei den jeweiligen Herausgebern.")
        }
        .listRowBackground(Theme.Color.surface)
    }

    private static var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
