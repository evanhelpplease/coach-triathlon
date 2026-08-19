import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Jours d'entraînement + règles par lieu (piscine lun/mer/ven, piste, etc.).
/// Le plan les respecte : une séance natation ne sera placée qu'un jour « piscine ».
struct AvailabilityRulesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services
    @Bindable var profile: ProfileModel
    @Query private var equipments: [EquipmentModel]

    var body: some View {
        Form {
            Section("Jours d'entraînement") {
                DayMaskEditor(mask: $profile.availableWeekdaysMask)
                Stepper("Max \(profile.maxSessionsPerWeek) séances / semaine", value: $profile.maxSessionsPerWeek, in: 3...12)
            }

            facilitySection("Piscine (natation)", mask: $profile.swimDaysMask, hint: "Ex. accès seulement lun/mer/ven.")
            facilitySection("Vélo", mask: $profile.bikeDaysMask, hint: "Ex. home trainer en semaine, extérieur le week-end.")
            facilitySection("Course / piste", mask: $profile.runDaysMask, hint: "Ex. piste d'athlé ouverte mar/jeu.")

            Section {
                Text("Les jours par lieu s'appliquent en plus de tes jours d'entraînement généraux.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Disponibilités")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { save() }
    }

    @ViewBuilder
    private func facilitySection(_ title: String, mask: Binding<Int>, hint: String) -> some View {
        Section(title) {
            Toggle("Jours spécifiques", isOn: Binding(
                get: { mask.wrappedValue != 0 },
                set: { on in mask.wrappedValue = on ? profile.availableWeekdaysMask : 0 }
            ))
            if mask.wrappedValue != 0 {
                DayMaskEditor(mask: mask)
            } else {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        try? context.save()
        if let e = equipments.first {
            services.regeneratePlan(profile: profile, equipment: e, context: context)
        }
    }
}

/// Sept interrupteurs de jours de la semaine, liés à un masque binaire.
struct DayMaskEditor: View {
    @Binding var mask: Int
    private let days: [(Int, String)] = [
        (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"), (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi"), (1, "Dimanche")
    ]
    var body: some View {
        ForEach(days, id: \.0) { wd, label in
            Toggle(label, isOn: Binding(
                get: { mask & (1 << (wd - 1)) != 0 },
                set: { on in
                    if on { mask |= (1 << (wd - 1)) } else { mask &= ~(1 << (wd - 1)) }
                }
            ))
        }
    }
}
