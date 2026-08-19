import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Prédictions de course : chrono cible décomposé (disciplines + transitions + IC),
/// temps de référence par distance, et projection sur tous les formats.
struct PredictionsView: View {
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]
    @Query private var races: [RaceModel]

    private let predictor = RacePredictor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if let profile = profiles.first?.domain, let equipment = equipments.first?.domain {
                    if let race = targetRace {
                        targetSection(race: race, profile: profile, equipment: equipment)
                    }
                    referenceSection(profile: profile)
                    formatsSection(profile: profile, equipment: equipment)
                    disclaimer(profile: profile)
                } else {
                    ContentUnavailableView("Profil incomplet", systemImage: "person.crop.circle.badge.questionmark",
                                           description: Text("Renseigne ton profil pour obtenir des prédictions."))
                }
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("Prédictions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var targetRace: RaceModel? {
        races.filter { !$0.isOpenGoal }.min { $0.date < $1.date }
    }

    // MARK: Course cible

    @ViewBuilder
    private func targetSection(race: RaceModel, profile: AthleteProfile, equipment: Equipment) -> some View {
        let format = RaceFormat(rawValue: race.formatRaw) ?? .olympic
        let p = predictor.predict(format: format, profile: profile, equipment: equipment)

        Text(race.title).font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)

        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.duration(p.totalSeconds)).font(DS.Font.number(40)).foregroundStyle(DS.Color.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("± \(Int(p.confidenceHalfWidth * 100)) %").font(DS.Font.headline).foregroundStyle(DS.Color.accent)
                        Text("\(Format.duration(p.lowSeconds)) – \(Format.duration(p.highSeconds))")
                            .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                    }
                }
                if race.targetTimeSec > 0 {
                    let delta = p.totalSeconds - race.targetTimeSec
                    Label(delta <= 0 ? "En avance de \(Format.duration(-delta)) sur ton objectif"
                                     : "Retard de \(Format.duration(delta)) sur ton objectif",
                          systemImage: delta <= 0 ? "checkmark.circle.fill" : "target")
                        .font(DS.Font.caption)
                        .foregroundStyle(delta <= 0 ? DS.Color.success : DS.Color.warning)
                }

                if format.isTriathlon {
                    breakdownBar(p)
                    breakdownList(p)
                }
            }
        }
    }

    /// Barre horizontale des proportions par segment.
    private func breakdownBar(_ p: RacePrediction) -> some View {
        let segments: [(Double, Color)] = [
            (p.swimSeconds ?? 0, DS.Color.swim),
            (p.t1Seconds ?? 0, DS.Color.textTertiary),
            (p.bikeSeconds ?? 0, DS.Color.bike),
            (p.t2Seconds ?? 0, DS.Color.textTertiary),
            (p.runSeconds, DS.Color.run)
        ]
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    seg.1.frame(width: max(2, geo.size.width * seg.0 / p.totalSeconds))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    private func breakdownList(_ p: RacePrediction) -> some View {
        VStack(spacing: DS.Space.xs) {
            row("Natation", p.swimSeconds, DS.Color.swim, icon: "figure.pool.swim")
            row("Transition 1", p.t1Seconds, DS.Color.textSecondary, icon: "arrow.triangle.swap")
            row("Vélo", p.bikeSeconds, DS.Color.bike, icon: "figure.outdoor.cycle")
            row("Transition 2", p.t2Seconds, DS.Color.textSecondary, icon: "arrow.triangle.swap")
            row("Course", p.runSeconds, DS.Color.run, icon: "figure.run")
        }
    }

    private func row(_ label: String, _ seconds: Double?, _ tint: Color, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 24)
            Text(label).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
            Spacer()
            Text(seconds.map(Format.duration) ?? "—").font(DS.Font.number(16)).foregroundStyle(DS.Color.textPrimary)
        }
    }

    // MARK: Temps de référence par distance

    @ViewBuilder
    private func referenceSection(profile: AthleteProfile) -> some View {
        Text("Temps de référence").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)

        disciplineCard(title: "Natation", tint: DS.Color.swim, missing: profile.cssSecPer100m == nil, testName: "test CSS") {
            if let css = profile.cssSecPer100m {
                refRow("400 m", CSS.predictTimeSeconds(cssPacePer100m: css, distanceM: 400))
                refRow("1500 m", CSS.predictTimeSeconds(cssPacePer100m: css, distanceM: 1500))
            }
        }
        disciplineCard(title: "Vélo", tint: DS.Color.bike, missing: profile.ftpWatts == nil, testName: "test FTP") {
            if let ftp = profile.ftpWatts {
                let model = bikeModel(profile: profile)
                let power = Double(ftp)
                refRow("20 km", model.predictTimeSeconds(distanceM: 20_000, sustainedPowerW: power * 0.94))
                refRow("40 km", model.predictTimeSeconds(distanceM: 40_000, sustainedPowerW: power * 0.90))
                refRow("90 km", model.predictTimeSeconds(distanceM: 90_000, sustainedPowerW: power * 0.83))
            }
        }
        disciplineCard(title: "Course", tint: DS.Color.run, missing: profile.vdot == nil, testName: "test VMA") {
            if let vdot = profile.vdot {
                refRow("5 km", VDOT.predictTimeSeconds(vdot: vdot, distanceMeters: 5000))
                refRow("10 km", VDOT.predictTimeSeconds(vdot: vdot, distanceMeters: 10_000))
                refRow("Semi", VDOT.predictTimeSeconds(vdot: vdot, distanceMeters: 21_097.5))
                refRow("Marathon", VDOT.predictTimeSeconds(vdot: vdot, distanceMeters: 42_195))
            }
        }
    }

    private func disciplineCard<Content: View>(title: String, tint: Color, missing: Bool, testName: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(title).font(DS.Font.headline).foregroundStyle(tint)
                if missing {
                    Label("Fais le \(testName) pour débloquer ces prédictions.", systemImage: "lock.fill")
                        .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                } else {
                    content()
                }
            }
        }
    }

    private func refRow(_ label: String, _ seconds: Double) -> some View {
        HStack {
            Text(label).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
            Spacer()
            Text(Format.duration(seconds)).font(DS.Font.number(16)).foregroundStyle(DS.Color.textPrimary)
        }
    }

    // MARK: Tous les formats de triathlon

    @ViewBuilder
    private func formatsSection(profile: AthleteProfile, equipment: Equipment) -> some View {
        Text("Sur chaque format").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
        DSCard {
            VStack(spacing: DS.Space.xs) {
                formatRow("Sprint", .sprint, profile, equipment)
                Divider()
                formatRow("Olympique (M)", .olympic, profile, equipment)
                Divider()
                formatRow("Half (L)", .half, profile, equipment)
                Divider()
                formatRow("Ironman (XL)", .full, profile, equipment)
            }
        }
    }

    private func formatRow(_ label: String, _ format: RaceFormat, _ profile: AthleteProfile, _ equipment: Equipment) -> some View {
        let p = predictor.predict(format: format, profile: profile, equipment: equipment)
        return HStack {
            Text(label).font(DS.Font.callout).foregroundStyle(DS.Color.textPrimary)
            Spacer()
            Text("± \(Int(p.confidenceHalfWidth * 100)) %").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
            Text(Format.duration(p.totalSeconds)).font(DS.Font.number(18)).foregroundStyle(DS.Color.textPrimary)
                .frame(minWidth: 90, alignment: .trailing)
        }
    }

    // MARK: Utilitaires

    private func bikeModel(profile: AthleteProfile) -> CyclingPowerModel {
        let eq = equipments.first?.domain
        let cda = CyclingPowerModel.typicalCdA(bikeType: eq?.bikeType ?? .road, aeroBars: eq?.hasAeroBars ?? false)
        let mass = profile.weightKg + (eq?.bikeWeightKg ?? 9.0)
        return CyclingPowerModel(totalMassKg: mass, cda: cda)
    }

    private func disclaimer(profile: AthleteProfile) -> some View {
        Text("Prédictions basées sur tes référentiels (VDOT, CSS, puissance) et le matériel déclaré. L'intervalle se resserre à mesure que tu ajoutes des données réelles.")
            .font(.caption2).foregroundStyle(DS.Color.textTertiary)
    }
}
