import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

private let zoneOptions: [(raw: String, label: String)] = [
    ("knee", "Genou"), ("ankle", "Cheville"), ("foot", "Pied"),
    ("calf", "Mollet"), ("hamstring", "Ischio-jambiers"), ("hip", "Hanche"),
    ("lowerBack", "Bas du dos"), ("shoulder", "Épaule"), ("other", "Autre")
]
private func zoneLabel(_ raw: String) -> String { zoneOptions.first { $0.raw == raw }?.label ?? raw }

/// Déclaration et gestion des blessures. Alimente les règles d'adaptation du moteur.
struct InjuryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \InjuryModel.since, order: .reverse) private var injuries: [InjuryModel]
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                Label("Déclare une douleur : les séances à risque sont adaptées automatiquement (ex. genou → natation avec pull buoy, course suspendue).",
                      systemImage: "cross.case.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if injuries.isEmpty {
                ContentUnavailableView("Aucune blessure déclarée", systemImage: "checkmark.seal",
                                       description: Text("Tant mieux ! Déclare-en une si besoin."))
            } else {
                ForEach(injuries) { injury in
                    NavigationLink { InjuryDetailView(injury: injury) } label: {
                        InjuryRow(injury: injury)
                    }
                }
                .onDelete(perform: delete)
            }
            Section {
                Text("Rappel : cette app ne remplace pas un avis médical. Douleur persistante → consulte.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Blessures")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { InjuryEditSheet() }
    }

    private func delete(_ offsets: IndexSet) {
        offsets.map { injuries[$0] }.forEach(context.delete)
        try? context.save()
    }
}

private struct InjuryRow: View {
    let injury: InjuryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(injury.detailName.isEmpty ? zoneLabel(injury.zoneRaw) : injury.detailName)
                .font(DS.Font.headline)
            Text("\(zoneLabel(injury.zoneRaw)) · intensité \(injury.intensity)/5 · depuis le \(injury.since.formatted(.dateTime.day().month().year().locale(Format.fr)))")
                .font(.caption).foregroundStyle(.secondary)
            if !injury.isActive {
                Text("Inactive — n'affecte plus le plan").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

/// Détail d'une blessure : ressenti + conseils d'étirement/renforcement adaptés.
private struct InjuryDetailView: View {
    @Bindable var injury: InjuryModel
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                DSCard {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        HStack {
                            Image(systemName: "cross.case.fill").foregroundStyle(DS.Color.danger)
                            Text(injury.detailName.isEmpty ? zoneLabel(injury.zoneRaw) : injury.detailName)
                                .font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                        }
                        Text("\(zoneLabel(injury.zoneRaw)) · intensité \(injury.intensity)/5")
                            .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                        if let sensation = InjuryCatalog.specifics(forZone: injury.zoneRaw).first(where: { $0.name == injury.detailName })?.sensation {
                            Text(sensation).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                                .padding(.top, DS.Space.xxs)
                        }
                        Toggle("Blessure active (adapte le plan)", isOn: $injury.isActive)
                            .padding(.top, DS.Space.xs)
                            .onChange(of: injury.isActive) { _, _ in try? context.save() }
                    }
                }

                Text("Étirements & renforcement adaptés")
                    .font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)

                ForEach(InjuryCatalog.rehab(forZone: injury.zoneRaw)) { ex in
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Space.xxs) {
                            HStack(spacing: DS.Space.xs) {
                                Text(ex.kind.rawValue.uppercased())
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .foregroundStyle(kindColor(ex.kind))
                                    .background(kindColor(ex.kind).opacity(0.15), in: Capsule())
                                Text(ex.name).font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                            }
                            Text(ex.howTo).font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }

                Text("Ces conseils sont éducatifs et ne remplacent pas un avis médical. Douleur vive, gonflement ou douleur persistante → consulte un professionnel avant de reprendre.")
                    .font(.caption2).foregroundStyle(DS.Color.textTertiary)
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle("Conseils")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kindColor(_ k: RehabExercise.Kind) -> Color {
        switch k {
        case .stretch: return DS.Color.swim
        case .strength: return DS.Color.strength
        case .mobility: return DS.Color.run
        case .care: return DS.Color.warning
        }
    }
}

private struct InjuryEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var zoneRaw = "knee"
    @State private var detail = ""
    @State private var intensity = 3
    @State private var since = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Où as-tu mal ?") {
                    BodyMapPicker(zone: $zoneRaw, detail: $detail)
                        .padding(.vertical, DS.Space.xs)
                }
                Section("Intensité") {
                    Picker("Intensité", selection: $intensity) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                    HStack { Text("Légère"); Spacer(); Text("Sévère") }
                        .font(.caption2).foregroundStyle(.secondary)
                }
                DatePicker("Depuis", selection: $since, in: ...Date.now, displayedComponents: .date)
                Section {
                    Text("À partir d'une intensité de 3/5, les séances des sports à risque sont remplacées par des alternatives sûres.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nouvelle blessure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Ajouter") { save() } }
            }
            .onAppear { if detail.isEmpty { detail = InjuryCatalog.specifics(forZone: zoneRaw).first?.name ?? "" } }
        }
    }

    private func save() {
        let m = InjuryModel()
        m.zoneRaw = zoneRaw; m.detailName = detail; m.intensity = intensity; m.since = since; m.isActive = true
        context.insert(m)
        try? context.save()
        DSHaptics.play(.success)
        dismiss()
    }
}
