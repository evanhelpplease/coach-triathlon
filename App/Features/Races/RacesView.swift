import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

private let raceFormatOptions: [(RaceFormat, String)] = [
    (.sprint, "Sprint"), (.olympic, "Olympique (M)"), (.half, "Half (L)"), (.full, "Ironman (XL)"),
    (.run10k, "10 km"), (.halfMarathon, "Semi"), (.marathon, "Marathon")
]
private func formatLabel(_ raw: String) -> String {
    raceFormatOptions.first { $0.0.rawValue == raw }?.1 ?? raw
}

/// Gestion de plusieurs courses objectifs. Le plan se re-périodise à chaque changement.
struct RacesView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services
    @Query(sort: \RaceModel.date) private var races: [RaceModel]
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]

    @State private var editing: RaceModel?
    @State private var showAdd = false
    private let cal = Calendar(identifier: .gregorian)

    var realRaces: [RaceModel] { races.filter { !$0.isOpenGoal } }

    var body: some View {
        List {
            Section {
                Label("Ajoute toutes tes courses (tri, semi, cyclosportive…) avec leurs chronos cibles. Le plan périodise vers la dernière et t'amène frais sur chacune.",
                      systemImage: "flag.checkered")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if realRaces.isEmpty {
                ContentUnavailableView("Aucune course", systemImage: "flag",
                                       description: Text("Ajoute une course objectif."))
            } else {
                ForEach(realRaces) { race in
                    NavigationLink { RacePrepView(race: race) } label: { raceRow(race) }
                        .swipeActions(edge: .leading) {
                            Button { editing = race } label: { Label("Modifier", systemImage: "pencil") }
                                .tint(DS.Color.primary)
                        }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Mes courses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { RaceEditSheet(race: nil, onSave: regenerate) }
        .sheet(item: $editing) { race in RaceEditSheet(race: race, onSave: regenerate) }
    }

    private func raceRow(_ race: RaceModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(race.title).font(DS.Font.headline)
                Spacer()
                Text("Prio \(race.priorityRaw.uppercased())").font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(DS.Color.accent.opacity(0.2), in: Capsule())
            }
            Text("\(formatLabel(race.formatRaw)) · \(race.date.formatted(.dateTime.day().month().year().locale(Format.fr)))")
                .font(.caption).foregroundStyle(.secondary)
            if race.targetTimeSec > 0 {
                Text("Objectif : \(Format.duration(race.targetTimeSec))").font(.caption).foregroundStyle(DS.Color.primary)
            }
            if !race.location.isEmpty {
                Text(race.location).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        offsets.map { realRaces[$0] }.forEach(context.delete)
        try? context.save()
        regenerate()
    }

    private func regenerate() {
        guard let p = profiles.first, let e = equipments.first else { return }
        services.regeneratePlan(profile: p, equipment: e, context: context)
        DSHaptics.play(.success)
    }
}

private struct RaceEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let race: RaceModel?
    let onSave: () -> Void

    @State private var title = "Nouvelle course"
    @State private var format: RaceFormat = .olympic
    @State private var date = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now) ?? .now
    @State private var location = ""
    @State private var priority: RacePriority = .a
    @State private var hasTarget = false
    @State private var targetH = 2
    @State private var targetM = 30

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom", text: $title)
                TextField("Lieu", text: $location)
                DatePicker("Date", selection: $date, in: Date.now..., displayedComponents: .date)
                Picker("Format", selection: $format) {
                    ForEach(raceFormatOptions, id: \.0) { Text($0.1).tag($0.0) }
                }
                Picker("Priorité", selection: $priority) {
                    Text("A (majeur)").tag(RacePriority.a); Text("B").tag(RacePriority.b); Text("C").tag(RacePriority.c)
                }
                Section("Objectif de temps") {
                    Toggle("J'ai un chrono cible", isOn: $hasTarget)
                    if hasTarget {
                        HStack {
                            Stepper("\(targetH) h", value: $targetH, in: 0...17)
                            Stepper("\(targetM) min", value: $targetM, in: 0...59, step: 5)
                        }
                    }
                }
            }
            .navigationTitle(race == nil ? "Nouvelle course" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() } }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let race else { return }
        title = race.title
        format = RaceFormat(rawValue: race.formatRaw) ?? .olympic
        date = race.date
        location = race.location
        priority = RacePriority(rawValue: race.priorityRaw) ?? .a
        if race.targetTimeSec > 0 {
            hasTarget = true
            targetH = Int(race.targetTimeSec) / 3600
            targetM = (Int(race.targetTimeSec) % 3600) / 60
        }
    }

    private func save() {
        let model = race ?? { let m = RaceModel(); context.insert(m); return m }()
        model.title = title
        model.formatRaw = format.rawValue
        model.date = date
        model.location = location
        model.priorityRaw = priority.rawValue
        model.targetTimeSec = hasTarget ? Double(targetH * 3600 + targetM * 60) : 0
        model.isOpenGoal = false
        try? context.save()
        onSave()
        dismiss()
    }
}
