import SwiftUI
import SwiftData
import WidgetKit
import DesignSystem
import TriathlonEngine

/// Écran d'accueil = « cockpit du jour » : forme, séance du jour, prochaine course.
struct CockpitView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]
    @Query private var races: [RaceModel]
    @Query private var checkins: [DailyCheckinModel]
    @Query private var injuries: [InjuryModel]
    @Query private var unavailabilities: [UnavailabilityModel]
    @Query(sort: \PlannedSessionModel.date) private var sessions: [PlannedSessionModel]

    @State private var snapshot: HealthSnapshot?
    @State private var weather: WeatherNow?
    @State private var showCheckin = false
    @State private var isLoading = false

    private let cal = Calendar(identifier: .gregorian)

    // Dérivés PURS de l'instantané santé + des @Query : recalculés automatiquement
    // à chaque changement de donnée (suppression d'indispo, check-in, blessure…).
    private var form: LoadPoint? {
        guard let snapshot, let profile = profiles.first else { return nil }
        return services.formPoint(snapshot: snapshot, profile: profile.domain)
    }

    private var outcome: AdaptationOutcome? {
        guard let snapshot, let profile = profiles.first, let equip = equipments.first else { return nil }
        let unavail = unavailabilities.map { $0.domain }
        let effEquip = Availability.effectiveEquipment(base: equip.domain, unavailabilities: unavail, on: cal.startOfDay(for: .now))
        return services.adapt(
            base: sessions.map { $0.domain },
            profile: profile.domain,
            equipment: effEquip,
            injuries: injuries.filter(\.isActive).map { $0.domain },
            localCheckins: checkins.map { $0.domain },
            snapshot: snapshot
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    header
                    formAndCountdown
                    weatherCard
                    checkinCard
                    adaptationBanner
                    todaySection
                    weekSection
                    disclaimer
                }
                .padding(DS.Space.md)
            }
            .background(DS.Color.background.ignoresSafeArea())
            .navigationTitle("Aujourd'hui")
            .task(id: services.sourceMode) { await refresh() }
            .task { if weather == nil { weather = await WeatherService.fetch() } }
            .refreshable { await refresh() }
            .sheet(isPresented: $showCheckin, onDismiss: { Task { await refresh() } }) {
                CheckinView()
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting).font(DS.Font.display(30)).foregroundStyle(DS.Color.textPrimary)
            Text(Format.longDate(.now))
                .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
        }
    }

    private var formAndCountdown: some View {
        HStack(spacing: DS.Space.md) {
            DSCard {
                HStack(spacing: DS.Space.md) {
                    RingGauge(progress: formProgress, label: "Forme", value: formValue, tint: formTint)
                        .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text("État de forme").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                        Text(formHeadline).font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                        if let f = form {
                            Text("Fitness \(Int(f.ctl)) · Fatigue \(Int(f.atl))")
                                .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .overlay {
            if isLoading { ProgressView().tint(DS.Color.accent) }
        }
    }

    @ViewBuilder private var weatherCard: some View {
        if let w = weather {
            let outdoorSport = outdoorSessionSport
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack(spacing: DS.Space.sm) {
                        Image(systemName: w.symbol)
                            .font(.title2).foregroundStyle(DS.Color.primary)
                            .frame(width: 32)
                        Text("\(Int(w.tempC.rounded()))° · \(w.description)")
                            .font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        Text("\(Int(w.windKmh.rounded())) km/h")
                            .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                    }
                    if let suggestion = w.suggestion(for: outdoorSport) {
                        Label(suggestion, systemImage: w.isRoughOutdoor ? "house.fill" : "figure.outdoor.cycle")
                            .font(DS.Font.caption)
                            .foregroundStyle(w.isRoughOutdoor ? DS.Color.warning : DS.Color.success)
                    }
                }
            }
        }
    }

    /// Sport de la séance du jour s'il se pratique dehors (pour la suggestion météo).
    private var outdoorSessionSport: Sport? {
        guard let s = adaptedToday?.sport, s == .run || s == .bike || s == .brick else { return nil }
        return s
    }

    @ViewBuilder private var checkinCard: some View {
        if !hasCheckinToday {
            Button { showCheckin = true } label: {
                DSCard {
                    HStack(spacing: DS.Space.sm) {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .font(.title2).foregroundStyle(DS.Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check-in du jour").font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                            Text("Comment tu te sens ? On ajuste ta séance.")
                                .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(DS.Color.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var adaptationBanner: some View {
        if let events = outcome?.todayEvents, !events.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ForEach(events) { event in
                    DSCard(padding: DS.Space.sm) {
                        HStack(alignment: .top, spacing: DS.Space.sm) {
                            Image(systemName: icon(for: event.kind))
                                .foregroundStyle(color(for: event.kind))
                            Text(event.message)
                                .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var todaySection: some View {
        sectionTitle("Séance du jour")
        if let today = adaptedToday {
            SessionCard(session: today, highlighted: true)
            NavigationLink {
                SessionDetailView(session: today)
            } label: {
                PrimaryButtonLabel(title: "Voir la séance", icon: "play.fill")
            }
            .buttonStyle(.plain)
        } else {
            DSCard {
                HStack {
                    Image(systemName: "moon.zzz.fill").foregroundStyle(DS.Color.textTertiary)
                    Text("Repos aujourd'hui — récupération active si tu en ressens le besoin.")
                        .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
    }

    private func icon(for kind: AdaptationEvent.Kind) -> String {
        switch kind {
        case .eased: return "arrow.down.heart.fill"
        case .deload: return "tortoise.fill"
        case .rescheduled: return "calendar.badge.clock"
        case .substituted: return "arrow.triangle.swap"
        case .injuryAdjusted: return "cross.case.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .recalibrated: return "gauge.with.dots.needle.67percent"
        }
    }
    private func color(for kind: AdaptationEvent.Kind) -> Color {
        switch kind {
        case .injuryAdjusted, .alert: return DS.Color.danger
        case .eased, .deload: return DS.Color.warning
        default: return DS.Color.primary
        }
    }

    @ViewBuilder private var weekSection: some View {
        if let nextRace {
            sectionTitle("Objectif")
            NavigationLink {
                PredictionsView()
            } label: {
                DSCard {
                    HStack {
                        CountdownBadge(days: daysUntil(nextRace.date), title: nextRace.title)
                        Image(systemName: "chevron.right").foregroundStyle(DS.Color.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        sectionTitle("Cette semaine")
        HStack(spacing: DS.Space.sm) {
            StatTile(label: "Séances", value: "\(weekSessions.count)", tint: DS.Color.primary)
            StatTile(label: "Charge", value: "\(Int(weekLoad))", tint: DS.Color.accent)
            StatTile(label: "Durée", value: Format.minutes(weekDuration), tint: DS.Color.swim)
        }
    }

    private var disclaimer: some View {
        Text("Cette app ne remplace pas un avis médical. En cas de douleur persistante, consulte un professionnel.")
            .font(.caption2).foregroundStyle(DS.Color.textTertiary)
            .padding(.top, DS.Space.sm)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
            .padding(.top, DS.Space.xs)
    }

    // MARK: Données dérivées

    private var greeting: String {
        let h = cal.component(.hour, from: .now)
        switch h { case 5..<12: return "Bonjour 👋"; case 12..<18: return "Bel après-midi"; default: return "Bonsoir" }
    }

    private var todaySessionModel: PlannedSessionModel? {
        sessions.first { cal.isDateInToday($0.date) }
    }
    /// Séance du jour après passe d'adaptation (allègement, substitution…), sinon la séance de base.
    private var adaptedToday: PlannedSession? {
        outcome?.todaySession ?? todaySessionModel?.domain
    }
    private var hasCheckinToday: Bool {
        checkins.contains { cal.isDateInToday($0.date) }
    }

    private var nextRace: RaceModel? {
        races.filter { !$0.isOpenGoal && $0.date >= cal.startOfDay(for: .now) }.min { $0.date < $1.date }
    }

    private var weekSessions: [PlannedSessionModel] {
        guard let interval = cal.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return sessions.filter { interval.contains($0.date) }
    }
    private var weekLoad: Double { weekSessions.reduce(0) { $0 + $1.estimatedLoad } }
    private var weekDuration: TimeInterval { weekSessions.reduce(0) { $0 + $1.estimatedDuration } }

    private func daysUntil(_ date: Date) -> Int {
        max(0, cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0)
    }

    // Forme (TSB) → anneau. Plage typique −30…+25 mappée sur 0…1.
    private var formProgress: Double {
        guard let tsb = form?.tsb else { return 0.5 }
        return (tsb + 30) / 55
    }
    private var formValue: String { form.map { "\(Int($0.tsb))" } ?? "—" }
    private var formTint: Color {
        guard let tsb = form?.tsb else { return DS.Color.textTertiary }
        if tsb > 5 { return DS.Color.success }
        if tsb > -15 { return DS.Color.warning }
        return DS.Color.danger
    }
    private var formHeadline: String {
        guard let tsb = form?.tsb else { return "Données à venir" }
        if tsb > 15 { return "Frais et prêt" }
        if tsb > 5 { return "En forme" }
        if tsb > -10 { return "Charge productive" }
        if tsb > -20 { return "Fatigue installée" }
        return "Récupération nécessaire"
    }

    /// Ne fait QUE recharger l'instantané santé (asynchrone). L'adaptation et la
    /// forme se recalculent ensuite d'elles-mêmes à partir des @Query réactives.
    private func refresh() async {
        isLoading = true
        snapshot = await services.fetchHealth()
        isLoading = false
        saveWidgetSnapshot()
    }

    /// Écrit l'instantané lu par le widget iOS (via App Group).
    private func saveWidgetSnapshot() {
        let today = adaptedToday
        let snap = WidgetSnapshot(
            hasSession: today != nil,
            todayTitle: today?.title ?? "Repos",
            todaySportKey: today?.sport.rawValue ?? "",
            todayMinutes: Int((today?.estimatedDuration ?? 0) / 60),
            todayLoad: Int(today?.estimatedLoad ?? 0),
            formTSB: form.map { Int($0.tsb.rounded()) },
            formLabel: formHeadline,
            raceDays: nextRace.map { daysUntil($0.date) },
            raceTitle: nextRace?.title,
            updated: .now
        )
        WidgetStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Étiquette visuelle d'un bouton (pour NavigationLink stylé comme un bouton principal).
struct PrimaryButtonLabel: View {
    let title: String
    let icon: String?
    var body: some View {
        HStack(spacing: DS.Space.xs) {
            if let icon { Image(systemName: icon) }
            Text(title).font(DS.Font.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.md)
        .foregroundStyle(Color.black)
        .background(DS.Color.accent, in: Capsule())
    }
}
