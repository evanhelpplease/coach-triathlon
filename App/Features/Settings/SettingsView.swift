import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

struct SettingsView: View {
    @Environment(AppServices.self) private var services
    @Environment(AccountStore.self) private var accounts
    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]
    @Query private var races: [RaceModel]
    @Query(sort: \PlannedSessionModel.date) private var sessions: [PlannedSessionModel]

    @State private var regenerated = false
    @AppStorage("remindersOn") private var remindersOn = false
    @State private var calendarStatus = ""
    @State private var garminStatus = ""

    var body: some View {
        @Bindable var services = services
        NavigationStack {
            Form {
                Section("Source de données") {
                    Picker("Source", selection: $services.sourceMode) {
                        Text("Démo").tag(SourceMode.demo)
                        Text("Apple Santé").tag(SourceMode.appleHealth)
                        Text("Garmin").tag(SourceMode.garminDemo)
                    }
                    .pickerStyle(.segmented)
                    switch services.sourceMode {
                    case .appleHealth:
                        Label("Apple Santé sera sollicité pour tes activités et ta récupération.",
                              systemImage: "heart.text.square").font(.caption).foregroundStyle(.secondary)
                    case .garminDemo:
                        Label("Aperçu Garmin : données plus riches (VFC quotidienne, Body Battery, puissance normalisée). Simulé tant que le compte n'est pas connecté ci-dessous.",
                              systemImage: "applewatch.radiowaves.left.and.right").font(.caption).foregroundStyle(.secondary)
                    case .demo:
                        EmptyView()
                    }
                }

                Section {
                    Button { connectGarmin() } label: {
                        Label(services.garminConnected ? "Garmin Connect connecté ✓" : "Connecter Garmin Connect",
                              systemImage: "applewatch.radiowaves.left.and.right")
                            .foregroundStyle(services.garminConnected ? DS.Color.success : DS.Color.primary)
                    }
                    if !garminStatus.isEmpty {
                        Text(garminStatus).font(.caption).foregroundStyle(DS.Color.warning)
                    }
                } header: {
                    Text("Garmin Connect")
                } footer: {
                    Text("Une fois connecté, tes données Garmin (plus complètes qu'Apple Santé) sont fusionnées automatiquement. Nécessite l'inscription au Garmin Developer Program (voir docs/GARMIN.md).")
                }

                Section("Plan d'entraînement") {
                    if let p = profiles.first {
                        Picker("Progression", selection: progressionBinding(p)) {
                            Text("Prudent").tag("prudent")
                            Text("Équilibré").tag("balanced")
                            Text("Performance").tag("performance")
                        }
                        .pickerStyle(.segmented)
                        if p.progressionRaw == "performance" {
                            Label("Montée de charge rapide + plus d'intensité : progrès accélérés mais risque de blessure accru.",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(DS.Color.warning)
                        } else if p.progressionRaw == "prudent" {
                            Label("Progression douce, priorité à la prévention des blessures.", systemImage: "shield.fill")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        regenerate()
                    } label: {
                        Label("Régénérer le plan", systemImage: "arrow.triangle.2.circlepath")
                    }
                    if regenerated {
                        Label("Plan régénéré", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.success)
                    }
                }

                Section("Profil & matériel") {
                    if let p = profiles.first {
                        NavigationLink { ProfileEditView(profile: p) } label: {
                            Label("Modifier le profil", systemImage: "person.fill")
                        }
                    }
                    if let e = equipments.first {
                        NavigationLink { EquipmentEditView(equipment: e) } label: {
                            Label("Modifier le matériel", systemImage: "bicycle")
                        }
                    }
                }

                Section("Objectifs & disponibilités") {
                    NavigationLink { RacesView() } label: {
                        Label("Mes courses", systemImage: "flag.checkered")
                    }
                    if let p = profiles.first {
                        NavigationLink { AvailabilityRulesView(profile: p) } label: {
                            Label("Jours & lieux d'entraînement", systemImage: "calendar.badge.clock")
                        }
                    }
                    NavigationLink { AvailabilityView() } label: {
                        Label("Indisponibilités ponctuelles", systemImage: "slash.circle")
                    }
                    NavigationLink { InjuryView() } label: {
                        Label("Blessures", systemImage: "cross.case.fill")
                    }
                }

                Section {
                    Toggle("Rappels de séance", isOn: $remindersOn)
                        .onChange(of: remindersOn) { _, on in toggleReminders(on) }
                    Button {
                        syncCalendar()
                    } label: {
                        Label("Ajouter au calendrier Apple", systemImage: "calendar.badge.plus")
                    }
                    if !calendarStatus.isEmpty {
                        Text(calendarStatus).font(.caption).foregroundStyle(DS.Color.success)
                    }
                    Label("Google Agenda : bientôt (OAuth).", systemImage: "calendar")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text("Synchronisations")
                } footer: {
                    Text("Exporte une séance en .zwo / .fit depuis son écran de détail (bouton partager).")
                }

                Section("Compte") {
                    if let account = accounts.account {
                        LabeledContent("Connecté", value: account.label)
                    }
                    Button(role: .destructive) { accounts.signOut() } label: {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    Button(role: .destructive) { reset() } label: {
                        Label("Tout réinitialiser", systemImage: "trash")
                    }
                } footer: {
                    Text("Cette app ne remplace pas un avis médical.")
                }
            }
            .navigationTitle("Réglages")
        }
    }

    /// Change le niveau de progression et régénère immédiatement le plan.
    private func progressionBinding(_ p: ProfileModel) -> Binding<String> {
        Binding(
            get: { p.progressionRaw },
            set: { newValue in
                p.progressionRaw = newValue
                try? context.save()
                if let e = equipments.first { services.regeneratePlan(profile: p, equipment: e, context: context) }
                DSHaptics.play(.light)
            }
        )
    }

    private func regenerate() {
        guard let p = profiles.first, let e = equipments.first else { return }
        services.regeneratePlan(profile: p, equipment: e, context: context)
        regenerated = true
        DSHaptics.play(.success)
    }

    private func toggleReminders(_ on: Bool) {
        let domainSessions = sessions.map { $0.domain }
        Task {
            if on {
                if await NotificationService.requestAuthorization() {
                    await NotificationService.scheduleReminders(for: domainSessions)
                    DSHaptics.play(.success)
                } else {
                    remindersOn = false   // permission refusée
                }
            } else {
                NotificationService.cancelAll()
            }
        }
    }

    private func connectGarmin() {
        Task {
            do {
                try await GarminProvider().authorize()
                services.garminConnected = true
                garminStatus = ""
                DSHaptics.play(.success)
            } catch {
                garminStatus = "Connexion Garmin indisponible : configure tes identifiants du Garmin Developer Program (docs/GARMIN.md). En attendant, sélectionne « Garmin » ci-dessus pour un aperçu des données."
            }
        }
    }

    private func syncCalendar() {
        let domainSessions = sessions.map { $0.domain }
        Task {
            guard await CalendarSyncService.requestAccess() else {
                calendarStatus = "Accès calendrier refusé."
                return
            }
            do {
                try await CalendarSyncService.sync(sessions: domainSessions)
                calendarStatus = "Séances ajoutées au calendrier ✓"
                DSHaptics.play(.success)
            } catch {
                calendarStatus = "Échec de la synchronisation."
            }
        }
    }

    private func reset() {
        try? context.delete(model: ProfileModel.self)
        try? context.delete(model: EquipmentModel.self)
        try? context.delete(model: RaceModel.self)
        try? context.delete(model: PlannedSessionModel.self)
        try? context.delete(model: DailyCheckinModel.self)
        try? context.delete(model: InjuryModel.self)
        try? context.delete(model: UnavailabilityModel.self)
        try? context.save()
    }
}
