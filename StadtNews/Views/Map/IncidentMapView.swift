import SwiftUI
import MapKit

struct IncidentMapView: View {
    let cities: [City]

    @StateObject private var model = IncidentMapModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Article? = nil
    @State private var camera: MapCameraPosition

    init(cities: [City]) {
        self.cities = cities
        _camera = State(initialValue: .region(IncidentMapModel.region(for: cities)))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $camera) {
                    ForEach(model.incidents) { incident in
                        Annotation(incident.article.cityName, coordinate: incident.coordinate) {
                            Button {
                                selected = incident.article
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Theme.Color.brand)
                                    .background(Circle().fill(.white).padding(4))
                                    .shadow(radius: 2, y: 1)
                            }
                            .accessibilityLabel(incident.article.title)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                statusBanner
            }
            .background(Theme.Color.paper.ignoresSafeArea())
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
            .sheet(item: $selected) { article in
                NavigationStack {
                    ArticleDetailView(article: article)
                }
            }
            .task {
                await model.load(cities: cities)
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let text = bannerText {
            HStack(spacing: Theme.Spacing.sm) {
                if model.isLoading {
                    ProgressView()
                }
                Text(text)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Color.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Capsule().fill(Theme.Color.surface)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            )
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var bannerText: String? {
        if model.isLoading && model.incidents.isEmpty {
            return "Meldungen werden geladen …"
        }
        if model.incidents.isEmpty {
            return model.unlocatedCount > 0
                ? "Für diese Meldungen ließ sich kein genauer Ort ermitteln."
                : "Keine Meldungen mit Ortsangabe gefunden."
        }
        if model.unlocatedCount > 0 {
            return "\(model.incidents.count) auf der Karte · \(model.unlocatedCount) ohne genauen Ort"
        }
        return nil
    }
}
