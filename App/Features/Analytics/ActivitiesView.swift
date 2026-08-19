import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Dernières séances réalisées, chacune avec son analyse en langage naturel.
struct ActivitiesView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]
    @State private var items: [(activity: CompletedActivity, analysis: SessionAnalysis)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if items.isEmpty {
                    ContentUnavailableView("Aucune séance réalisée", systemImage: "figure.run.circle",
                                           description: Text("Tes activités importées (Santé ou démo) apparaîtront ici avec leur analyse."))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(items, id: \.activity.id) { item in
                        DSCard {
                            VStack(alignment: .leading, spacing: DS.Space.xs) {
                                HStack(spacing: DS.Space.sm) {
                                    SportBadge(sportKey: item.activity.sport.rawValue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.analysis.headline)
                                            .font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                                        Text(item.activity.start.formatted(.dateTime.weekday().day().month().locale(Format.fr)).capitalized)
                                            .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                                    }
                                }
                                ForEach(Array(item.analysis.insights.enumerated()), id: \.offset) { _, insight in
                                    Label(insight, systemImage: "sparkle")
                                        .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("Dernières séances")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: services.sourceMode) { await load() }
    }

    private func load() async {
        guard let profile = profiles.first?.domain else { return }
        items = await services.recentAnalyses(profile: profile)
    }
}
