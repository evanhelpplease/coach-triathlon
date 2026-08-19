import SwiftUI
import Charts
import SwiftData
import DesignSystem
import TriathlonEngine

/// Tableau de bord : charge d'entraînement (CTL/ATL/TSB) et volumes par sport.
struct AnalyticsView: View {
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]

    @State private var analytics: TrainingAnalytics?
    @State private var rangeDays = 90
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    linkCard("Prédictions de course", icon: "flag.checkered") { PredictionsView() }
                    linkCard("Dernières séances (analyse)", icon: "text.magnifyingglass") { ActivitiesView() }
                    linkCard("Records personnels", icon: "trophy.fill") { RecordsView() }
                    rangePicker
                    if let a = analytics, !a.points.isEmpty {
                        statTiles(a)
                        formChart(a)
                        fitnessFatigueChart(a)
                        weeklyLoadChart(a)
                        legend
                    } else {
                        placeholder
                    }
                }
                .padding(DS.Space.md)
            }
            .background(DS.Color.background.ignoresSafeArea())
            .navigationTitle("Analyse")
            .task(id: services.sourceMode) { await refresh() }
            .refreshable { await refresh() }
        }
    }

    // MARK: Contrôles

    private func linkCard<Destination: View>(_ title: String, icon: String,
                                             @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            DSCard {
                HStack {
                    Label(title, systemImage: icon)
                        .font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(DS.Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var rangePicker: some View {
        Picker("Période", selection: $rangeDays) {
            Text("30 j").tag(30)
            Text("90 j").tag(90)
            Text("120 j").tag(120)
        }
        .pickerStyle(.segmented)
    }

    private func statTiles(_ a: TrainingAnalytics) -> some View {
        HStack(spacing: DS.Space.sm) {
            StatTile(label: "Fitness", value: intStr(a.latest?.ctl), tint: DS.Color.accent)
            StatTile(label: "Fatigue", value: intStr(a.latest?.atl), tint: DS.Color.danger)
            StatTile(label: "Forme", value: intStr(a.latest?.tsb), tint: DS.Color.primary)
            StatTile(label: "ACWR", value: acwrStr(a.latest?.acwr), tint: DS.Color.warning)
        }
    }

    // MARK: Graphique de forme (TSB)

    private func formChart(_ a: TrainingAnalytics) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Forme (TSB)").font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                Text("Positif = frais · négatif = chargé").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                Chart {
                    ForEach(points(a), id: \.date) { p in
                        AreaMark(x: .value("Jour", p.date), y: .value("Forme", p.tsb))
                            .foregroundStyle(
                                .linearGradient(colors: [DS.Color.primary.opacity(0.35), DS.Color.primary.opacity(0.02)],
                                                startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Jour", p.date), y: .value("Forme", p.tsb))
                            .foregroundStyle(DS.Color.primary)
                            .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Zéro", 0))
                        .foregroundStyle(DS.Color.textTertiary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 180)
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { _ in AxisGridLine(); AxisTick() } }
            }
        }
    }

    // MARK: Fitness vs fatigue (CTL/ATL)

    private func fitnessFatigueChart(_ a: TrainingAnalytics) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Fitness & Fatigue").font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                Chart {
                    ForEach(points(a), id: \.date) { p in
                        LineMark(x: .value("Jour", p.date), y: .value("Charge", p.ctl))
                            .foregroundStyle(by: .value("Indicateur", "Fitness"))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Jour", p.date), y: .value("Charge", p.atl))
                            .foregroundStyle(by: .value("Indicateur", "Fatigue"))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 180)
                .chartForegroundStyleScale(["Fitness": DS.Color.accent, "Fatigue": DS.Color.danger])
                .chartLegend(position: .bottom)
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) { _ in AxisGridLine(); AxisTick() } }
            }
        }
    }

    // MARK: Charge hebdo par sport

    private func weeklyLoadChart(_ a: TrainingAnalytics) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Charge par semaine").font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                Chart(bars(a)) { b in
                    BarMark(
                        x: .value("Semaine", b.weekStart, unit: .weekOfYear),
                        y: .value("Charge", b.load)
                    )
                    .foregroundStyle(by: .value("Sport", b.sportLabel))
                    .cornerRadius(3)
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    "Natation": DS.Color.swim, "Vélo": DS.Color.bike,
                    "Course": DS.Color.run, "Renfo": DS.Color.strength, "Brick": DS.Color.primary
                ])
                .chartLegend(position: .bottom)
            }
        }
    }

    private var legend: some View {
        Text("CTL (fitness, 42 j) et ATL (fatigue, 7 j) sont des moyennes exponentielles de ta charge. TSB = fitness − fatigue. ACWR = charge aiguë / chronique (garde-fou anti-blessure).")
            .font(.caption2).foregroundStyle(DS.Color.textTertiary)
    }

    private var placeholder: some View {
        ContentUnavailableView("Pas encore de données", systemImage: "chart.xyaxis.line",
                               description: Text("Réalise des séances (ou active le mode démo) pour voir tes tendances."))
            .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: Données filtrées

    private func points(_ a: TrainingAnalytics) -> [LoadPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: .now) ?? .now
        return a.points.filter { $0.date >= cutoff }
    }
    private func bars(_ a: TrainingAnalytics) -> [SportLoadBar] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: .now) ?? .now
        return a.bars.filter { $0.weekStart >= cutoff }
    }

    private func intStr(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))" } ?? "—" }
    private func acwrStr(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "—" }

    private func refresh() async {
        guard let profile = profiles.first else { return }
        isLoading = true
        analytics = await services.loadAnalytics(profile: profile.domain)
        isLoading = false
    }
}
