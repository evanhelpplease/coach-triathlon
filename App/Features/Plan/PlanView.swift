import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Vue « Plan » : séances à venir groupées par jour, ajustées aux indisponibilités.
struct PlanView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]
    @Query private var unavailabilities: [UnavailabilityModel]
    @Query(sort: \PlannedSessionModel.date) private var sessions: [PlannedSessionModel]
    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Space.lg, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedDays, id: \.self) { day in
                        Section {
                            ForEach(sessionsByDay[day] ?? []) { session in
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    SessionCard(session: session, highlighted: cal.isDateInToday(day))
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(dayLabel(day))
                                .font(DS.Font.headline)
                                .foregroundStyle(DS.Color.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DS.Space.xs)
                                .background(DS.Color.background)
                        }
                    }
                }
                .padding(DS.Space.md)
            }
            .background(DS.Color.background.ignoresSafeArea())
            .navigationTitle("Plan")
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("Aucune séance", systemImage: "calendar.badge.plus",
                                           description: Text("Génère ton plan depuis les réglages."))
                }
            }
        }
    }

    /// Séances converties selon les indisponibilités actives à chaque date.
    private var adjusted: [PlannedSession] {
        let base = sessions.filter { $0.date >= cal.startOfDay(for: .now) }.map { $0.domain }
        guard let p = profiles.first, let e = equipments.first else { return base }
        return services.adjustedForAvailability(base, profile: p.domain, baseEquipment: e.domain,
                                                unavailabilities: unavailabilities.map { $0.domain })
    }

    private var sessionsByDay: [Date: [PlannedSession]] {
        Dictionary(grouping: adjusted) { cal.startOfDay(for: $0.date) }
    }
    private var groupedDays: [Date] { sessionsByDay.keys.sorted() }

    private func dayLabel(_ date: Date) -> String {
        if cal.isDateInToday(date) { return "Aujourd'hui" }
        if cal.isDateInTomorrow(date) { return "Demain" }
        return Format.dayMonth(date)
    }
}
