import SwiftUI
import SwiftData
import DesignSystem
import TriathlonEngine

/// Détail d'une séance : structure complète (échauffement / intervalles / retour au calme).
struct SessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var services
    @Query private var profiles: [ProfileModel]
    @Query private var equipments: [EquipmentModel]
    @State private var exportURLs: [URL] = []
    @State private var showTestResult = false
    @State private var liveRunning = false
    let session: PlannedSession

    private var isTest: Bool { TestSessions.isTest(session) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                header
                liveActivityButton
                if isTest { testResultCard }
                if !session.notes.isEmpty {
                    DSCard {
                        Label(session.notes, systemImage: "info.circle.fill")
                            .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                    }
                }
                Text("Déroulé").font(DS.Font.title).foregroundStyle(DS.Color.textPrimary)
                ForEach(Array(session.steps.enumerated()), id: \.offset) { _, step in
                    StepRow(step: step)
                }
                if session.sport != .strength {
                    unavailableButton
                }
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { exportURLs = WorkoutExport.writeFiles(for: session, ftp: profiles.first?.ftpWatts) }
        .toolbar {
            if !exportURLs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(items: exportURLs) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showTestResult) {
            TestResultSheet(sport: session.sport) { vdot, ftp, css in
                applyTestResult(vdot: vdot, ftp: ftp, css: css)
            }
        }
    }

    private var testResultCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Label("Séance de test", systemImage: "stopwatch.fill")
                    .font(DS.Font.headline).foregroundStyle(DS.Color.accent)
                Text("Une fois le test réalisé, saisis ton résultat : tes zones et ton plan se recalibrent automatiquement.")
                    .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                Button { showTestResult = true } label: {
                    Text("Saisir mon résultat").fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, DS.Space.sm)
                        .foregroundStyle(Color.black).background(DS.Color.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Met à jour le référentiel de l'athlète puis régénère le plan (zones recalculées).
    private func applyTestResult(vdot: Double?, ftp: Int?, css: Double?) {
        guard let p = profiles.first, let e = equipments.first else { return }
        if let vdot { p.vdot = vdot }
        if let ftp { p.ftpWatts = ftp }
        if let css { p.cssSecPer100m = css }
        try? context.save()
        services.regeneratePlan(profile: p, equipment: e, context: context)
        DSHaptics.play(.success)
        dismiss()
    }

    private var liveActivityButton: some View {
        Button {
            if liveRunning {
                SessionLiveActivityManager.end(); liveRunning = false
            } else {
                liveRunning = SessionLiveActivityManager.start(session: session)
                if liveRunning { DSHaptics.play(.success) }
            }
        } label: {
            Label(liveRunning ? "Terminer la séance" : "Démarrer la séance",
                  systemImage: liveRunning ? "stop.circle.fill" : "play.circle.fill")
                .font(DS.Font.headline)
                .frame(maxWidth: .infinity).padding(.vertical, DS.Space.sm)
                .foregroundStyle(liveRunning ? Color.white : Color.black)
                .background(liveRunning ? DS.Color.danger : DS.Color.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .onAppear { liveRunning = SessionLiveActivityManager.isRunning }
    }

    private var unavailableButton: some View {
        Button(role: .destructive) { markUnavailable() } label: {
            Label("Je ne peux pas faire cette séance", systemImage: "slash.circle")
                .font(DS.Font.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Space.sm)
        }
        .buttonStyle(.bordered)
        .tint(DS.Color.warning)
        .padding(.top, DS.Space.sm)
    }

    /// Crée une indisponibilité ponctuelle (ce sport, ce jour) → la séance sera convertie.
    private func markUnavailable() {
        let cal = Calendar(identifier: .gregorian)
        let m = UnavailabilityModel()
        m.sportRaw = session.sport.rawValue
        m.startDate = cal.startOfDay(for: session.date)
        m.endDate = session.date
        m.note = "Séance du \(Format.dayMonth(session.date))"
        context.insert(m)
        try? context.save()
        DSHaptics.play(.warning)
        dismiss()
    }

    private var header: some View {
        DSCard {
            HStack(spacing: DS.Space.md) {
                SportBadge(sportKey: session.sport.rawValue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title).font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                    Text("\(Format.minutes(session.estimatedDuration)) · charge \(Int(session.estimatedLoad))")
                        .font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                IntentTag(intent: session.intent)
            }
        }
    }
}

private struct StepRow: View {
    let step: WorkoutStep

    var body: some View {
        if step.kind == .repeatBlock, let children = step.children, let reps = step.repeats {
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("\(reps) ×").font(DS.Font.headline).foregroundStyle(DS.Color.accent)
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        line(for: child)
                    }
                }
            }
        } else {
            DSCard { line(for: step) }
        }
    }

    private func line(for step: WorkoutStep) -> some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            Text(kindLabel(step.kind))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textTertiary)
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(durationLabel(step.duration)).font(DS.Font.body).foregroundStyle(DS.Color.textPrimary)
                Text(targetLabel(step.target)).font(DS.Font.caption).foregroundStyle(DS.Color.primary)
                if let cue = step.cue {
                    Text(cue).font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func kindLabel(_ k: StepKind) -> String {
        switch k {
        case .warmup: return "ÉCHAUFF."
        case .work: return "EFFORT"
        case .recovery: return "RÉCUP"
        case .rest: return "REPOS"
        case .cooldown: return "RETOUR CALME"
        case .repeatBlock: return "SÉRIE"
        }
    }

    private func durationLabel(_ d: StepDuration) -> String {
        switch d {
        case .time(let s): return Format.duration(s)
        case .distance(let m): return Format.distanceKm(m)
        case .lengths(let count, let pool): return "\(count) × \(Int(pool)) m"
        }
    }

    private func targetLabel(_ t: StepTarget) -> String {
        switch t {
        case .hrZone(let z): return "Zone FC \(z)"
        case .paceRange(let lo, let hi): return "\(Format.runPace(lo)) – \(Format.runPace(hi))"
        case .swimPaceRange(let lo, let hi): return "\(Format.swimPace(lo)) – \(Format.swimPace(hi))"
        case .powerRange(let lo, let hi): return "\(Int(lo))–\(Int(hi)) W"
        case .rpe(let r): return "RPE \(r)/10"
        case .free: return "Libre"
        }
    }
}
