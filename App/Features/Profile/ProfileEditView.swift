import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Édition du profil. Les zones et prédictions se recalculent automatiquement ;
/// pense à régénérer le plan (Réglages) après un changement majeur de référentiel.
struct ProfileEditView: View {
    @Environment(\.modelContext) private var context
    @Bindable var profile: ProfileModel

    private let levels = ["Débutant", "Novice", "Intermédiaire", "Avancé", "Expert"]

    var body: some View {
        Form {
            Section("Toi") {
                DatePicker("Naissance", selection: $profile.birthDate, displayedComponents: .date)
                Picker("Sexe", selection: $profile.sexRaw) {
                    Text("Homme").tag("male"); Text("Femme").tag("female"); Text("Autre").tag("other")
                }
                Stepper("Taille : \(Int(profile.heightCm)) cm", value: $profile.heightCm, in: 140...210)
                Stepper("Poids : \(Int(profile.weightKg)) kg", value: $profile.weightKg, in: 40...140)
            }

            Section("Niveau par discipline") {
                Picker("Natation", selection: $profile.swimLevel) { levelOptions }
                Picker("Vélo", selection: $profile.bikeLevel) { levelOptions }
                Picker("Course", selection: $profile.runLevel) { levelOptions }
            }

            Section("Référentiels") {
                OptionalIntRow(title: "FC max", value: $profile.hrMax, range: 150...220, defaultValue: 190, unit: "bpm")
                OptionalIntRow(title: "FC repos", value: $profile.hrRest, range: 35...80, defaultValue: 55, unit: "bpm")
                OptionalIntRow(title: "FTP vélo", value: $profile.ftpWatts, range: 80...500, step: 5, defaultValue: 220, unit: "W")
            }

            Section {
                Text("À la modification d'un référentiel (FTP, niveau…), régénère ton plan depuis les Réglages pour en tenir compte.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    private var levelOptions: some View {
        ForEach(0..<levels.count, id: \.self) { Text(levels[$0]).tag($0) }
    }
}

/// Ligne « valeur optionnelle » : un interrupteur « connu » + un pas de réglage.
struct OptionalIntRow: View {
    let title: String
    @Binding var value: Int?
    var range: ClosedRange<Int>
    var step: Int = 1
    var defaultValue: Int
    var unit: String

    var body: some View {
        Toggle("\(title) connue", isOn: Binding(
            get: { value != nil },
            set: { value = $0 ? defaultValue : nil }
        ))
        if value != nil {
            Stepper("\(title) : \(value ?? defaultValue) \(unit)",
                    value: Binding(get: { value ?? defaultValue }, set: { value = $0 }),
                    in: range, step: step)
        }
    }
}
