import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                notificationsSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.paper.ignoresSafeArea())
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

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $settings.pushEnabled) {
                Text("Push bei neuen Meldungen")
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Color.ink)
            }
            .tint(Theme.Color.brand)
            .listRowBackground(Theme.Color.surface)

            ForEach(NewsSource.allCases) { source in
                Toggle(isOn: Binding(
                    get: { settings.isPushEnabled(for: source) },
                    set: { settings.setPushEnabled($0, for: source) }
                )) {
                    Text(source.label)
                        .foregroundStyle(settings.pushEnabled ? Theme.Color.ink : Theme.Color.tertiaryInk)
                }
                .tint(Theme.Color.brand)
                .disabled(!settings.pushEnabled)
                .listRowBackground(Theme.Color.surface)
            }
        } header: {
            Text("Mitteilungen")
        } footer: {
            Text("Erhalten Sie eine Mitteilung, sobald eine neue Meldung erscheint – und wählen Sie, von welchen Quellen. Sie können dies jederzeit ändern.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Quellen", value: "Polizei · Feuerwehr · Stadt · Warnungen")
            LabeledContent("Version", value: Self.appVersion)
        } header: {
            Text("Über Gelsenkirchen.news")
        } footer: {
            Text("Gelsenkirchen.news bündelt offizielle Meldungen der Polizei und Feuerwehr Gelsenkirchen (über das Presseportal der news aktuell GmbH), Pressemeldungen der Stadt Gelsenkirchen (gelsenkirchen.de) sowie amtliche Warnungen des Bundesamts für Bevölkerungsschutz (BBK/NINA). Alle Rechte an den Inhalten verbleiben bei den jeweiligen Herausgebern.")
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
