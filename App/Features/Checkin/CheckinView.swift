import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Check-in quotidien : ressenti + sommeil. Alimente le moteur d'adaptation.
struct CheckinView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var checkins: [DailyCheckinModel]

    @State private var form = 3
    @State private var sleepQuality = 3
    @State private var soreness = 3        // 5 = aucune courbature
    @State private var motivation = 3
    @State private var sleepHours = 7.5

    private let cal = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Comment tu te sens aujourd'hui ? Ces réponses ajustent ta séance en temps réel.")
                        .font(DS.Font.callout).foregroundStyle(.secondary)
                }
                ratingRow("Forme générale", value: $form, lowLabel: "À plat", highLabel: "Au top")
                ratingRow("Qualité du sommeil", value: $sleepQuality, lowLabel: "Mauvaise", highLabel: "Excellente")
                ratingRow("Fraîcheur musculaire", value: $soreness, lowLabel: "Courbatu", highLabel: "Frais")
                ratingRow("Motivation", value: $motivation, lowLabel: "Faible", highLabel: "Grande")

                Section("Sommeil") {
                    Stepper("Durée : \(String(format: "%.1f", sleepHours)) h", value: $sleepHours, in: 3...12, step: 0.5)
                }
            }
            .navigationTitle("Check-in du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Valider") { save() } }
            }
            .onAppear(perform: prefillFromToday)
        }
    }

    private func ratingRow(_ title: String, value: Binding<Int>, lowLabel: String, highLabel: String) -> some View {
        Section(title) {
            Picker(title, selection: value) {
                ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text(lowLabel); Spacer(); Text(highLabel)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func prefillFromToday() {
        guard let today = checkins.first(where: { cal.isDateInToday($0.date) }) else { return }
        form = today.form ?? 3
        sleepQuality = today.sleepQuality ?? 3
        soreness = today.soreness ?? 3
        motivation = today.motivation ?? 3
        sleepHours = today.sleepHours ?? 7.5
    }

    private func save() {
        // Upsert : un seul check-in par jour.
        let model = checkins.first { cal.isDateInToday($0.date) } ?? {
            let m = DailyCheckinModel(); context.insert(m); return m
        }()
        model.date = .now
        model.form = form
        model.sleepQuality = sleepQuality
        model.soreness = soreness
        model.motivation = motivation
        model.sleepHours = sleepHours
        try? context.save()
        DSHaptics.play(.success)
        dismiss()
    }
}
