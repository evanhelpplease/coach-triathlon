import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Records personnels par discipline.
struct RecordsView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]
    @State private var records: [PersonalRecord] = []

    private let sports: [(key: String, label: String)] = [
        ("swim", "Natation"), ("bike", "Vélo"), ("run", "Course")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if records.isEmpty {
                    ContentUnavailableView("Pas encore de record", systemImage: "trophy",
                                           description: Text("Réalise des séances pour établir tes records."))
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(sports, id: \.key) { sport in
                        let group = records.filter { $0.sportKey == sport.key }
                        if !group.isEmpty {
                            Text(sport.label).font(DS.Font.title).foregroundStyle(DS.Color.sport(sport.key))
                            DSCard {
                                VStack(spacing: DS.Space.xs) {
                                    ForEach(group) { rec in
                                        HStack {
                                            Image(systemName: "trophy.fill").foregroundStyle(DS.Color.accent).frame(width: 24)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(rec.label).font(DS.Font.callout).foregroundStyle(DS.Color.textPrimary)
                                                Text(rec.date.formatted(.dateTime.day().month().year().locale(Format.fr)))
                                                    .font(.caption2).foregroundStyle(DS.Color.textTertiary)
                                            }
                                            Spacer()
                                            Text(rec.value).font(DS.Font.number(18)).foregroundStyle(DS.Color.textPrimary)
                                        }
                                        if rec.id != group.last?.id { Divider() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: services.sourceMode) { await load() }
    }

    private func load() async {
        guard let profile = profiles.first?.domain else { return }
        records = await services.records(profile: profile)
    }
}
