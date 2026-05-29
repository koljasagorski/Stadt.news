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
        } header: {
            Text("Mitteilungen")
        } footer: {
            Text("Erhalten Sie eine Mitteilung, sobald in Gelsenkirchen eine neue Meldung erscheint. Sie können dies jederzeit ändern.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Quellen", value: "Polizei · Feuerwehr · Stadt")
            LabeledContent("Version", value: Self.appVersion)
        } header: {
            Text("Über Gelsenkirchen.news")
        } footer: {
            Text("Gelsenkirchen.news bündelt offizielle Meldungen der Polizei und Feuerwehr Gelsenkirchen (über das Presseportal der news aktuell GmbH) sowie Pressemeldungen der Stadt Gelsenkirchen (gelsenkirchen.de). Alle Rechte an den Inhalten verbleiben bei den jeweiligen Herausgebern.")
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
