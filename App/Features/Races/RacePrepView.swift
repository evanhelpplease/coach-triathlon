import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Préparation de course : chrono prédit, pacing par discipline, nutrition,
/// checklist matériel et briefing J-7 / J-1. Réutilise le moteur (RacePredictor,
/// RacePacing, RaceNutrition) — additif, sans toucher au plan.
struct RacePrepView: View {
    let race: RaceModel
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]

    private let cal = Calendar(identifier: .gregorian)
    private var format: RaceFormat { RaceFormat(rawValue: race.formatRaw) ?? .olympic }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if let profile = profiles.first?.domain, let equipment = equipments.first?.domain {
                    header(profile: profile, equipment: equipment)
                    pacingSection(profile: profile)
                    nutritionSection(profile: profile, equipment: equipment)
                    checklistSection
                    briefingSection
                } else {
                    ContentUnavailableView("Profil incomplet", systemImage: "person.crop.circle.badge.questionmark",
                                           description: Text("Renseigne ton profil pour préparer cette course."))
                }
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle(race.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: En-tête : compte à rebours + chrono prédit vs objectif

    private func header(profile: AthleteProfile, equipment: Equipment) -> some View {
        let pred = RacePredictor().predict(format: format, profile: profile, equipment: equipment)
        let days = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: race.date)).day ?? 0)
        return DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(days)").font(DS.Font.number(34)).foregroundStyle(DS.Color.accent)
                    Text("jours").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                    Spacer()
                    if !race.location.isEmpty {
                        Label(race.location, systemImage: "mappin.and.ellipse")
                            .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Chrono prédit").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                        Text(Format.duration(pred.totalSeconds)).font(DS.Font.number(24)).foregroundStyle(DS.Color.textPrimary)
                    }
                    Spacer()
                    if race.targetTimeSec > 0 {
                        VStack(alignment: .trailing) {
                            Text("Ton objectif").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                            Text(Format.duration(race.targetTimeSec)).font(DS.Font.number(24)).foregroundStyle(DS.Color.primary)
                        }
                    }
                }
                if race.targetTimeSec > 0 {
                    let delta = pred.totalSeconds - race.targetTimeSec
                    Label(delta <= 0 ? "Objectif atteignable (marge ~\(Format.duration(-delta)))."
                                     : "Objectif ambitieux : ~\(Format.duration(delta)) au-dessus de la prédiction. On peut y arriver en soignant l'affûtage.",
                          systemImage: delta <= 0 ? "checkmark.seal.fill" : "flame.fill")
                        .font(DS.Font.caption).foregroundStyle(delta <= 0 ? DS.Color.success : DS.Color.warning)
                }
            }
        }
    }

    // MARK: Pacing

    private func pacingSection(profile: AthleteProfile) -> some View {
        let targets = RacePacing.targets(format: format, profile: profile)
        return Group {
            sectionTitle("Pacing cible")
            if targets.isEmpty {
                DSCard { Text("Renseigne tes référentiels (VMA, FTP, CSS) pour un pacing personnalisé.").font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary) }
            } else {
                ForEach(targets) { t in
                    DSCard {
                        HStack(spacing: DS.Space.sm) {
                            SportBadge(sportKey: t.sportKey)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.label).font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                                Text(t.value).font(DS.Font.number(20)).foregroundStyle(DS.Color.textPrimary)
                                Text(t.note).font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: Nutrition

    private func nutritionSection(profile: AthleteProfile, equipment: Equipment) -> some View {
        let pred = RacePredictor().predict(format: format, profile: profile, equipment: equipment)
        let plan = RaceNutrition.plan(durationSec: pred.totalSeconds, weightKg: profile.weightKg, format: format)
        return Group {
            sectionTitle("Nutrition & hydratation")
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    HStack(spacing: DS.Space.md) {
                        nutriTile("Glucides", "\(plan.carbsPerHour) g/h")
                        nutriTile("Total", "\(plan.totalCarbs) g")
                        nutriTile("Liquide", "\(plan.fluidPerHour) ml/h")
                        nutriTile("Sodium", "\(plan.sodiumPerHour) mg/h")
                    }
                    Text(plan.summary).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
    }

    private func nutriTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(DS.Font.number(15)).foregroundStyle(DS.Color.textPrimary)
            Text(label).font(.caption2).foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Checklist

    private var checklistSection: some View {
        Group {
            sectionTitle("Checklist matériel")
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    ForEach(checklist, id: \.self) { item in
                        Label(item, systemImage: "square").font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
        }
    }

    private var checklist: [String] {
        var items = ["Dossard + épingles / ceinture", "Montre chargée", "Ravitaillement (gels, barres, boisson)", "Chaussures de course"]
        if format.isTriathlon {
            items += ["Combinaison (si eau froide)", "Bonnet + lunettes de natation", "Vélo vérifié (pneus, freins, transmission)", "Casque", "Chaussures vélo", "Trifonction", "Élastiques / talc pour T1-T2"]
        }
        items += ["Crème solaire", "Vêtement de récupération", "Nutrition d'après-course"]
        return items
    }

    // MARK: Briefing

    private var briefingSection: some View {
        Group {
            sectionTitle("Briefing")
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    briefingBlock("J-7", "Affûtage : réduis le volume (~40 %), garde de courtes touches d'intensité pour rester affûté. Soigne le sommeil et l'hydratation. Prépare et teste ton matériel de course.")
                    Divider()
                    briefingBlock("J-1", "Repérage du parcours et des transitions si possible. Repas riche en glucides, hydratation régulière. Vérifie tout le matériel (checklist ci-dessus). Couche-toi tôt, visualise ta course.")
                    Divider()
                    briefingBlock("Jour J", "Petit-déjeuner 3 h avant, échauffement progressif, pars sur ton pacing (ne te laisse pas emballer). Respecte ton plan nutrition dès le début.")
                }
            }
            Text("Rappel : écoute tes sensations. En cas de douleur inhabituelle, ne force pas.")
                .font(.caption2).foregroundStyle(DS.Color.textTertiary)
        }
    }

    private func briefingBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.Font.headline).foregroundStyle(DS.Color.accent)
            Text(text).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(DS.Font.title).foregroundStyle(DS.Color.textPrimary).padding(.top, DS.Space.xs)
    }
}
