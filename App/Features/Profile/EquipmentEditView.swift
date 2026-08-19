import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Édition du matériel disponible (état durable). Pour une indisponibilité
/// ponctuelle et datée, utiliser plutôt « Disponibilités ».
struct EquipmentEditView: View {
    @Environment(\.modelContext) private var context
    @Bindable var equipment: EquipmentModel

    private let bikeTypes: [(raw: String, label: String)] = [
        ("road", "Route"), ("tt", "Chrono/CLM"), ("gravel", "Gravel"),
        ("mtb", "VTT"), ("trainer", "Home trainer")
    ]

    var body: some View {
        Form {
            Section("Vélo") {
                Toggle("J'ai un vélo", isOn: $equipment.hasBike)
                if equipment.hasBike {
                    Picker("Type", selection: bikeTypeBinding) {
                        ForEach(bikeTypes, id: \.raw) { Text($0.label).tag($0.raw) }
                    }
                    Toggle("Prolongateurs (aéro)", isOn: $equipment.hasAeroBars)
                    Toggle("Capteur de puissance", isOn: $equipment.hasPowerMeter)
                    Toggle("Home trainer connecté", isOn: $equipment.hasSmartTrainer)
                }
            }

            Section("Natation") {
                Toggle("Accès piscine", isOn: $equipment.poolAccess)
                Toggle("Eau libre accessible", isOn: $equipment.openWaterAccess)
                Toggle("Combinaison néoprène", isOn: $equipment.hasWetsuit)
                Toggle("Élastiques de traction (à sec)", isOn: $equipment.hasDrylandCords)
            }

            Section("Course") {
                Toggle("Extérieur", isOn: $equipment.runOutdoor)
                Toggle("Tapis de course", isOn: $equipment.hasTreadmill)
                Toggle("Piste d'athlétisme", isOn: $equipment.hasTrack)
            }

            Section("Renforcement") {
                Picker("Accès", selection: $equipment.strengthAccessRaw) {
                    Text("Salle de sport").tag("gym")
                    Text("Haltères à domicile").tag("homeWeights")
                    Text("Poids du corps").tag("bodyweightOnly")
                    Text("Aucun").tag("none")
                }
            }
        }
        .navigationTitle("Matériel")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { equipment.updatedAt = .now; try? context.save() }
    }

    /// bikeTypeRaw est optionnel : on le mappe sur une sélection non-optionnelle.
    private var bikeTypeBinding: Binding<String> {
        Binding(get: { equipment.bikeTypeRaw ?? "road" },
                set: { equipment.bikeTypeRaw = $0 })
    }
}
