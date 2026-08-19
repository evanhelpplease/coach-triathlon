import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Onboarding riche multi-étapes : collecte un maximum d'informations pour bâtir
/// le plan le plus adapté. Les disciplines sans référentiel reçoivent un test de terrain.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppServices.self) private var services

    @State private var step = 0
    private let lastStep = 8

    // MARK: Physique
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var sex: BiologicalSex = .male
    @State private var heightCm = 178.0
    @State private var weightKg = 72.0
    @State private var hrMax: Int? = nil
    @State private var hrRest: Int? = nil

    // MARK: Niveaux
    @State private var swimLevel = 1
    @State private var bikeLevel = 2
    @State private var runLevel = 2
    @State private var weeklyHours = 6.0

    // MARK: Référentiels
    enum RunRef: String, CaseIterable { case none, vma, time }
    @State private var runRef: RunRef = .none
    @State private var vma = 15.0
    @State private var runDistKm = 5
    @State private var runMin = 22
    @State private var runSec = 0

    @State private var hasFTP = false
    @State private var ftp = 220

    enum SwimRef: String, CaseIterable { case none, css }
    @State private var swimRef: SwimRef = .none
    @State private var t400Min = 6
    @State private var t400Sec = 30
    @State private var t200Min = 3
    @State private var t200Sec = 5

    // MARK: Matériel
    @State private var hasBike = true
    @State private var bikeType = "road"
    @State private var hasAeroBars = false
    @State private var hasPowerMeter = false
    @State private var hasSmartTrainer = false
    @State private var poolAccess = true
    @State private var openWaterAccess = false
    @State private var hasWetsuit = false
    @State private var hasDrylandCords = false
    @State private var hasTreadmill = false
    @State private var hasTrack = false
    @State private var strengthAccess = "bodyweightOnly"

    // MARK: Disponibilités
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6, 7, 1]
    @State private var maxSessions = 6
    @State private var progression = "balanced"

    // MARK: Objectif
    enum GoalType: String, CaseIterable { case fun, improve, race }
    @State private var goalType: GoalType = .race
    @State private var raceTitle = "Triathlon M"
    @State private var raceFormat: RaceFormat = .olympic
    @State private var raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 14, to: .now) ?? .now
    @State private var raceLocation = ""
    @State private var priority: RacePriority = .a
    @State private var hasTargetTime = false
    @State private var targetH = 2
    @State private var targetM = 30

    // MARK: Blessures
    struct InjuryEntry: Identifiable { let id = UUID(); var zone: String; var detailName: String; var intensity: Int; var since: Date; var present: Bool }
    @State private var injuryList: [InjuryEntry] = []
    @State private var showInjurySheet = false

    // MARK: Connexions
    @State private var healthConnected = false

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView { stepContent.padding(DS.Space.md) }
            bottomBar
        }
        .background(DS.Color.background.ignoresSafeArea())
        .tint(DS.Color.accent)
        .sheet(isPresented: $showInjurySheet) {
            OnboardingInjurySheet { injuryList.append($0) }
        }
    }

    private var progressBar: some View {
        VStack(spacing: DS.Space.xs) {
            ProgressView(value: Double(step + 1), total: Double(lastStep + 1))
                .tint(DS.Color.accent)
            Text("Étape \(step + 1) / \(lastStep + 1)")
                .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
        }
        .padding(.horizontal, DS.Space.md).padding(.top, DS.Space.md)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: physiqueStep
        case 2: levelsStep
        case 3: referentialsStep
        case 4: equipmentStep
        case 5: availabilityStep
        case 6: goalStep
        case 7: injuriesStep
        default: connectionsStep
        }
    }

    // MARK: - Étapes

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("Bienvenue 👋").font(DS.Font.display(32)).foregroundStyle(DS.Color.textPrimary)
            Text("Quelques questions pour bâtir ton plan sur mesure. Plus tu es précis, plus le coach est juste. Tout reste modifiable ensuite.")
                .font(DS.Font.body).foregroundStyle(DS.Color.textSecondary)
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Label("Profil & niveau", systemImage: "person.fill")
                    Label("Référentiels ou tests de terrain", systemImage: "stopwatch.fill")
                    Label("Matériel & disponibilités", systemImage: "bicycle")
                    Label("Objectif & blessures", systemImage: "flag.checkered")
                    Label("Connexions (Santé, agenda)", systemImage: "link")
                }
                .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
            }
            Button("Charger un athlète démo (test rapide)") { loadDemo() }
                .font(DS.Font.callout).padding(.top, DS.Space.xs)
        }
    }

    private var physiqueStep: some View {
        Form {
            Section("Toi") {
                DatePicker("Naissance", selection: $birthDate, displayedComponents: .date)
                Picker("Sexe", selection: $sex) {
                    Text("Homme").tag(BiologicalSex.male); Text("Femme").tag(BiologicalSex.female); Text("Autre").tag(BiologicalSex.other)
                }
                Stepper("Taille : \(Int(heightCm)) cm", value: $heightCm, in: 140...210)
                Stepper("Poids : \(Int(weightKg)) kg", value: $weightKg, in: 40...140)
            }
            Section("Fréquence cardiaque (optionnel)") {
                OptionalIntRow(title: "FC max", value: $hrMax, range: 150...220, defaultValue: 190, unit: "bpm")
                OptionalIntRow(title: "FC repos", value: $hrRest, range: 35...80, defaultValue: 55, unit: "bpm")
            }
        }
        .frame(minHeight: 520).scrollDisabled(true)
    }

    private var levelsStep: some View {
        Form {
            Section("Niveau par discipline") {
                levelPicker("Natation", $swimLevel)
                levelPicker("Vélo", $bikeLevel)
                levelPicker("Course", $runLevel)
            }
            Section("Volume actuel") {
                Stepper("≈ \(Int(weeklyHours)) h / semaine", value: $weeklyHours, in: 1...25)
            }
        }
        .frame(minHeight: 420).scrollDisabled(true)
    }

    private var referentialsStep: some View {
        Form {
            Section {
                Text("Renseigne ce que tu connais. Pour une discipline laissée vide, le plan démarrera par un **test de terrain** pour établir tes bases.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Course") {
                Picker("Donnée connue", selection: $runRef) {
                    Text("Aucune (→ test VMA)").tag(RunRef.none)
                    Text("VMA").tag(RunRef.vma)
                    Text("Chrono récent").tag(RunRef.time)
                }
                if runRef == .vma {
                    Stepper("VMA : \(String(format: "%.1f", vma)) km/h", value: $vma, in: 8...25, step: 0.5)
                } else if runRef == .time {
                    Picker("Distance", selection: $runDistKm) { Text("5 km").tag(5); Text("10 km").tag(10) }
                    timeRow("Temps", min: $runMin, sec: $runSec, minRange: 12...80)
                }
            }
            Section("Vélo") {
                Toggle("Je connais ma FTP", isOn: $hasFTP)
                if hasFTP { Stepper("FTP : \(ftp) W", value: $ftp, in: 80...500, step: 5) }
                else { Text("Sans FTP → test de 20 min planifié.").font(.caption).foregroundStyle(.secondary) }
            }
            Section("Natation") {
                Picker("Donnée connue", selection: $swimRef) {
                    Text("Aucune (→ test CSS)").tag(SwimRef.none)
                    Text("Chronos 400 m & 200 m").tag(SwimRef.css)
                }
                if swimRef == .css {
                    timeRow("400 m", min: $t400Min, sec: $t400Sec, minRange: 4...15)
                    timeRow("200 m", min: $t200Min, sec: $t200Sec, minRange: 2...8)
                }
            }
        }
        .frame(minHeight: 640).scrollDisabled(true)
    }

    private var equipmentStep: some View {
        Form {
            Section("Vélo") {
                Toggle("J'ai un vélo", isOn: $hasBike)
                if hasBike {
                    Picker("Type", selection: $bikeType) {
                        Text("Route").tag("road"); Text("Chrono/CLM").tag("tt"); Text("Gravel").tag("gravel"); Text("VTT").tag("mtb"); Text("Home trainer").tag("trainer")
                    }
                    Toggle("Prolongateurs (aéro)", isOn: $hasAeroBars)
                    Toggle("Capteur de puissance", isOn: $hasPowerMeter)
                    Toggle("Home trainer connecté", isOn: $hasSmartTrainer)
                }
            }
            Section("Natation") {
                Toggle("Accès piscine", isOn: $poolAccess)
                Toggle("Eau libre", isOn: $openWaterAccess)
                Toggle("Combinaison néoprène", isOn: $hasWetsuit)
                Toggle("Élastiques à sec", isOn: $hasDrylandCords)
            }
            Section("Course & renfo") {
                Toggle("Tapis de course", isOn: $hasTreadmill)
                Toggle("Piste", isOn: $hasTrack)
                Picker("Renforcement", selection: $strengthAccess) {
                    Text("Salle").tag("gym"); Text("Haltères maison").tag("homeWeights"); Text("Poids du corps").tag("bodyweightOnly"); Text("Aucun").tag("none")
                }
            }
        }
        .frame(minHeight: 680).scrollDisabled(true)
    }

    private var availabilityStep: some View {
        Form {
            Section("Jours d'entraînement possibles") {
                ForEach(weekdayOptions, id: \.0) { wd, label in
                    Toggle(label, isOn: Binding(
                        get: { weekdays.contains(wd) },
                        set: { on in if on { weekdays.insert(wd) } else { weekdays.remove(wd) } }
                    ))
                }
            }
            Section("Charge") {
                Stepper("Max \(maxSessions) séances / semaine", value: $maxSessions, in: 3...12)
            }
            Section("Volonté de progression") {
                Picker("Progression", selection: $progression) {
                    Text("Prudent").tag("prudent")
                    Text("Équilibré").tag("balanced")
                    Text("Performance").tag("performance")
                }.pickerStyle(.segmented)
                Text(progression == "performance" ? "Progrès accélérés, plus d'intensité — risque de blessure accru."
                     : progression == "prudent" ? "Progression douce, priorité anti-blessure."
                     : "Progression standard, bon équilibre.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 720).scrollDisabled(true)
    }

    private var goalStep: some View {
        Form {
            Section("Ton objectif") {
                Picker("Type", selection: $goalType) {
                    Text("Prendre du plaisir").tag(GoalType.fun)
                    Text("Progresser (sans course)").tag(GoalType.improve)
                    Text("Une course programmée").tag(GoalType.race)
                }.pickerStyle(.inline)
            }
            if goalType == .race {
                Section("La course") {
                    TextField("Nom", text: $raceTitle)
                    TextField("Lieu", text: $raceLocation)
                    DatePicker("Date", selection: $raceDate, in: Date.now..., displayedComponents: .date)
                    Picker("Format", selection: $raceFormat) {
                        Text("Sprint").tag(RaceFormat.sprint); Text("Olympique (M)").tag(RaceFormat.olympic)
                        Text("Half (L)").tag(RaceFormat.half); Text("Ironman (XL)").tag(RaceFormat.full)
                        Text("10 km").tag(RaceFormat.run10k); Text("Semi").tag(RaceFormat.halfMarathon); Text("Marathon").tag(RaceFormat.marathon)
                    }
                    Picker("Priorité", selection: $priority) {
                        Text("A (majeur)").tag(RacePriority.a); Text("B").tag(RacePriority.b); Text("C").tag(RacePriority.c)
                    }
                }
                Section("Objectif de temps (optionnel)") {
                    Toggle("J'ai un chrono cible", isOn: $hasTargetTime)
                    if hasTargetTime {
                        HStack {
                            Stepper("\(targetH) h", value: $targetH, in: 0...17)
                            Stepper("\(targetM) min", value: $targetM, in: 0...59, step: 5)
                        }
                    }
                }
            } else {
                Section { Text("Le plan visera une progression continue, avec des semaines de décharge régulières.").font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(minHeight: 640).scrollDisabled(true)
    }

    private var injuriesStep: some View {
        Form {
            Section {
                Text("Déclare tes blessures passées ou actuelles, en précisant si la douleur est **encore présente** — le coach adapte en conséquence.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Blessures") {
                if injuryList.isEmpty {
                    Text("Aucune déclarée.").foregroundStyle(.secondary)
                } else {
                    ForEach(injuryList) { inj in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zoneLabelFR(inj.zone)).font(DS.Font.headline)
                            Text("Intensité \(inj.intensity)/5 · \(inj.present ? "douleur encore présente" : "résolue")")
                                .font(.caption).foregroundStyle(inj.present ? DS.Color.danger : DS.Color.textTertiary)
                        }
                    }
                    .onDelete { injuryList.remove(atOffsets: $0) }
                }
                Button { showInjurySheet = true } label: { Label("Ajouter une blessure", systemImage: "plus.circle") }
            }
        }
        .frame(minHeight: 440).scrollDisabled(true)
    }

    private var connectionsStep: some View {
        Form {
            Section("Connexions") {
                Button { connectHealth() } label: {
                    Label(healthConnected ? "Apple Santé connecté ✓" : "Connecter Apple Santé", systemImage: "heart.text.square.fill")
                        .foregroundStyle(healthConnected ? DS.Color.success : DS.Color.primary)
                }
                Button { services.sourceMode = .garminDemo } label: {
                    Label("Connecter Garmin Connect", systemImage: "applewatch.radiowaves.left.and.right")
                }
                Label("Garmin fournit des données plus riches (VFC, Body Battery, puissance). La connexion réelle se configure dans les Réglages ; ici tu peux déjà en voir un aperçu.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Google Agenda : synchronisation des séances — bientôt disponible.", systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text(summaryText).font(.caption).foregroundStyle(.secondary)
            } header: { Text("Récapitulatif") }
        }
        .frame(minHeight: 520).scrollDisabled(true)
    }

    // MARK: - Barre de navigation

    private var bottomBar: some View {
        HStack(spacing: DS.Space.md) {
            if step > 0 {
                Button { withAnimation { step -= 1 } } label: {
                    Text("Retour").frame(maxWidth: .infinity).padding(.vertical, DS.Space.sm)
                }
                .buttonStyle(.bordered)
            }
            if step < lastStep {
                Button { withAnimation { step += 1 } } label: {
                    Text("Suivant").frame(maxWidth: .infinity).fontWeight(.semibold).padding(.vertical, DS.Space.sm)
                }
                .buttonStyle(.borderedProminent).tint(DS.Color.accent)
            } else {
                Button { finish() } label: {
                    Text("Créer mon plan").frame(maxWidth: .infinity).fontWeight(.semibold).padding(.vertical, DS.Space.sm)
                }
                .buttonStyle(.borderedProminent).tint(DS.Color.accent)
            }
        }
        .padding(DS.Space.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Composants réutilisables

    private let levels = ["Débutant", "Novice", "Intermédiaire", "Avancé", "Expert"]
    private func levelPicker(_ title: String, _ value: Binding<Int>) -> some View {
        Picker(title, selection: value) { ForEach(0..<levels.count, id: \.self) { Text(levels[$0]).tag($0) } }
    }
    private func timeRow(_ title: String, min: Binding<Int>, sec: Binding<Int>, minRange: ClosedRange<Int>) -> some View {
        HStack {
            Text(title); Spacer()
            Text("\(min.wrappedValue):\(String(format: "%02d", sec.wrappedValue))").monospacedDigit().foregroundStyle(DS.Color.primary)
            Stepper("", value: min, in: minRange).labelsHidden()
            Stepper("", value: sec, in: 0...59, step: 5).labelsHidden()
        }
    }
    private let weekdayOptions: [(Int, String)] = [
        (2, "Lundi"), (3, "Mardi"), (4, "Mercredi"), (5, "Jeudi"), (6, "Vendredi"), (7, "Samedi"), (1, "Dimanche")
    ]

    private var summaryText: String {
        let missing = [runRef == .none ? "course" : nil, !hasFTP ? "vélo" : nil, swimRef == .none ? "natation" : nil].compactMap { $0 }
        let testLine = missing.isEmpty ? "Référentiels complets." : "Tests de terrain planifiés : \(missing.joined(separator: ", "))."
        let goalLine = goalType == .race ? "Objectif : \(raceTitle)." : "Objectif : progression continue."
        return "\(goalLine) \(testLine) \(weekdays.count) jours/sem, max \(maxSessions) séances."
    }

    private func zoneLabelFR(_ raw: String) -> String {
        ["knee": "Genou", "ankle": "Cheville", "foot": "Pied", "calf": "Mollet", "hamstring": "Ischio-jambiers",
         "hip": "Hanche", "lowerBack": "Bas du dos", "shoulder": "Épaule", "other": "Autre"][raw] ?? raw
    }

    // MARK: - Finalisation

    private func computedVDOT() -> Double? {
        switch runRef {
        case .none: return nil
        case .vma: return VDOT.vo2Cost(velocityMetersPerMin: vma * 1000 / 60)
        case .time:
            let d = Double(runDistKm) * 1000
            return VDOT.vdot(distanceMeters: d, timeSeconds: Double(runMin * 60 + runSec))
        }
    }
    private func computedCSS() -> Double? {
        guard swimRef == .css else { return nil }
        return CSS.pacePer100m(longDistanceM: 400, longTimeSec: Double(t400Min * 60 + t400Sec),
                               shortDistanceM: 200, shortTimeSec: Double(t200Min * 60 + t200Sec))
    }

    private func makeProfile() -> AthleteProfile {
        AthleteProfile(
            birthDate: birthDate, sex: sex, heightCm: heightCm, weightKg: weightKg,
            hrMax: hrMax, hrRest: hrRest, ftpWatts: hasFTP ? ftp : nil,
            cssSecPer100m: computedCSS(), vdot: computedVDOT(),
            levels: [.swim: SkillLevel(rawValue: swimLevel) ?? .beginner,
                     .bike: SkillLevel(rawValue: bikeLevel) ?? .beginner,
                     .run: SkillLevel(rawValue: runLevel) ?? .beginner]
        )
    }
    private func makeEquipment() -> Equipment {
        Equipment(hasBike: hasBike, bikeType: hasBike ? BikeType(rawValue: bikeType) : nil,
                  hasAeroBars: hasAeroBars, hasPowerMeter: hasPowerMeter, hasSmartTrainer: hasSmartTrainer,
                  poolAccess: poolAccess, openWaterAccess: openWaterAccess, hasWetsuit: hasWetsuit,
                  hasDrylandCords: hasDrylandCords, runOutdoor: true, hasTreadmill: hasTreadmill, hasTrack: hasTrack,
                  strengthAccess: Equipment.StrengthAccess(rawValue: strengthAccess) ?? .bodyweightOnly)
    }

    private func finish() {
        let pModel = ProfileModel()
        pModel.apply(makeProfile())
        pModel.weeklyHours = weeklyHours
        pModel.goalTypeRaw = goalType.rawValue
        pModel.progressionRaw = progression
        pModel.maxSessionsPerWeek = maxSessions
        pModel.availableWeekdaysMask = weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }

        let eModel = EquipmentModel(); eModel.apply(makeEquipment())

        let rModel = RaceModel()
        if goalType == .race {
            rModel.apply(Race(date: raceDate, format: raceFormat, priority: priority, title: raceTitle))
            rModel.location = raceLocation
            rModel.targetTimeSec = hasTargetTime ? Double(targetH * 3600 + targetM * 60) : 0
            rModel.isOpenGoal = false
        } else {
            // Objectif ouvert : bloc de 12 semaines de progression continue.
            let date = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now) ?? .now
            let race = Race(date: date, format: .olympic, priority: .a, title: "Progression continue")
            rModel.apply(race)
            rModel.isOpenGoal = true
        }

        context.insert(pModel); context.insert(eModel); context.insert(rModel)
        for inj in injuryList where inj.present {
            let m = InjuryModel()
            m.zoneRaw = inj.zone; m.detailName = inj.detailName; m.intensity = inj.intensity
            m.since = inj.since; m.isActive = true
            context.insert(m)
        }
        services.regeneratePlan(profile: pModel, equipment: eModel, context: context)
        DSHaptics.play(.success)
    }

    private func connectHealth() {
        Task {
            do {
                try await AppleHealthProvider().authorize()
                healthConnected = true
                services.sourceMode = .appleHealth
                DSHaptics.play(.success)
            } catch {
                healthConnected = false // reste en mode démo si indisponible
            }
        }
    }

    private func loadDemo() {
        let pModel = ProfileModel()
        pModel.apply(AthleteProfile(
            birthDate: Calendar.current.date(byAdding: .year, value: -32, to: .now) ?? .now,
            sex: .male, heightCm: 180, weightKg: 72, hrMax: 190, hrRest: 48,
            ftpWatts: 250, cssSecPer100m: 95, vdot: 50,
            levels: [.swim: .novice, .bike: .advanced, .run: .intermediate]))
        let eModel = EquipmentModel()
        eModel.apply(Equipment(hasBike: true, bikeType: .road, hasAeroBars: true, poolAccess: true,
                               runOutdoor: true, strengthAccess: .homeWeights))
        let rModel = RaceModel()
        rModel.apply(Race(date: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now) ?? .now,
                          format: .olympic, priority: .a, title: "Triathlon M"))
        context.insert(pModel); context.insert(eModel); context.insert(rModel)
        services.regeneratePlan(profile: pModel, equipment: eModel, context: context)
        DSHaptics.play(.success)
    }
}

/// Feuille d'ajout d'une blessure pendant l'onboarding.
private struct OnboardingInjurySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (OnboardingView.InjuryEntry) -> Void

    @State private var zone = "knee"
    @State private var detail = ""
    @State private var intensity = 3
    @State private var since = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var present = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Où as-tu mal ?") {
                    BodyMapPicker(zone: $zone, detail: $detail)
                        .padding(.vertical, DS.Space.xs)
                }
                Section("Intensité") {
                    Picker("Intensité", selection: $intensity) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }
                        .pickerStyle(.segmented)
                }
                DatePicker("Depuis", selection: $since, in: ...Date.now, displayedComponents: .date)
                Toggle("Douleur encore présente", isOn: $present)
            }
            .navigationTitle("Blessure").navigationBarTitleDisplayMode(.inline)
            .onAppear { if detail.isEmpty { detail = InjuryCatalog.specifics(forZone: zone).first?.name ?? "" } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onAdd(.init(zone: zone, detailName: detail, intensity: intensity, since: since, present: present))
                        dismiss()
                    }
                }
            }
        }
    }
}
