import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

private let sportOptions: [(raw: String, label: String)] = [
    ("swim", "Natation"), ("bike", "Vélo"), ("run", "Course"), ("strength", "Renforcement")
]
private func sportLabel(_ raw: String) -> String { sportOptions.first { $0.raw == raw }?.label ?? raw }

/// Gestion des indisponibilités : « pas de piscine jusqu'à nouvel ordre »,
/// « pas de vélo ce week-end »… Le plan bascule automatiquement.
struct AvailabilityView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UnavailabilityModel.startDate) private var items: [UnavailabilityModel]
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                Label("Indique ce que tu ne peux pas faire, et sur quelle période. Les séances concernées sont converties (ex. pas de piscine → travail à sec) et rebasculent au retour.",
                      systemImage: "slash.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if items.isEmpty {
                ContentUnavailableView("Tout est disponible", systemImage: "checkmark.circle",
                                       description: Text("Ajoute une indisponibilité si besoin."))
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pas de \(sportLabel(item.sportRaw).lowercased())").font(DS.Font.headline)
                        Text(periodLabel(item)).font(.caption).foregroundStyle(.secondary)
                        if !item.note.isEmpty {
                            Text(item.note).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Disponibilités")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AvailabilityEditSheet() }
    }

    private func periodLabel(_ item: UnavailabilityModel) -> String {
        let start = item.startDate.formatted(.dateTime.day().month().locale(Format.fr))
        if let end = item.endDate {
            return "Du \(start) au \(end.formatted(.dateTime.day().month().locale(Format.fr)))"
        }
        return "À partir du \(start) — durée indéterminée"
    }

    private func delete(_ offsets: IndexSet) {
        offsets.map { items[$0] }.forEach(context.delete)
        try? context.save()
    }
}

private struct AvailabilityEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var sportRaw = "swim"
    @State private var start = Date.now
    @State private var hasEnd = false
    @State private var end = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Sport indisponible", selection: $sportRaw) {
                    ForEach(sportOptions, id: \.raw) { Text($0.label).tag($0.raw) }
                }
                DatePicker("À partir du", selection: $start, displayedComponents: .date)
                Toggle("Date de fin connue", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("Jusqu'au", selection: $end, in: start..., displayedComponents: .date)
                } else {
                    Text("Durée indéterminée — jusqu'à ce que tu retires cette indisponibilité.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                TextField("Note (optionnel)", text: $note)
            }
            .navigationTitle("Indisponibilité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Ajouter") { save() } }
            }
        }
    }

    private func save() {
        let m = UnavailabilityModel()
        m.sportRaw = sportRaw
        m.startDate = start
        m.endDate = hasEnd ? end : nil
        m.note = note
        context.insert(m)
        try? context.save()
        DSHaptics.play(.success)
        dismiss()
    }
}
