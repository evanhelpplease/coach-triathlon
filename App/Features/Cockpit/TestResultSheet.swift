import SwiftUI
import DesignSystem
import TriathlonEngine

/// Saisie du résultat d'un test de terrain → référentiel recalculé.
/// Renvoie (vdot, ftp, css) — un seul est non-nil selon le sport.
struct TestResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sport: Sport
    var onApply: (_ vdot: Double?, _ ftp: Int?, _ css: Double?) -> Void

    // Course (test VMA 6 min) : distance parcourue.
    @State private var distanceM = 1500
    // Vélo (test FTP 20 min) : puissance moyenne.
    @State private var power20 = 220
    // Natation (test CSS) : temps 400 m et 200 m.
    @State private var t400Min = 6
    @State private var t400Sec = 30
    @State private var t200Min = 3
    @State private var t200Sec = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(intro).font(DS.Font.callout).foregroundStyle(.secondary)
                }
                switch sport {
                case .run:
                    Section("Test VMA (6 min)") {
                        Stepper("Distance : \(distanceM) m", value: $distanceM, in: 800...4000, step: 25)
                    }
                case .bike:
                    Section("Test FTP (20 min)") {
                        Stepper("Puissance moyenne : \(power20) W", value: $power20, in: 80...500, step: 5)
                    }
                default:
                    Section("Test CSS") {
                        timeRow("400 m", min: $t400Min, sec: $t400Sec, minRange: 4...15)
                        timeRow("200 m", min: $t200Min, sec: $t200Sec, minRange: 2...8)
                    }
                }
                Section("Résultat") {
                    LabeledContent(resultLabel, value: resultValue)
                    Text("Tes zones et ton plan seront recalibrés automatiquement.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Résultat du test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Appliquer") { apply() } }
            }
        }
    }

    // MARK: Calculs

    private var vma: Double { Double(distanceM) / 100 }           // km/h (6 min all-out)
    private var vdot: Double { VDOT.vo2Cost(velocityMetersPerMin: vma * 1000 / 60) }
    private var ftp: Int { Int((Double(power20) * 0.95).rounded()) }
    private var css: Double {
        CSS.pacePer100m(longDistanceM: 400, longTimeSec: Double(t400Min * 60 + t400Sec),
                        shortDistanceM: 200, shortTimeSec: Double(t200Min * 60 + t200Sec))
    }

    private var intro: String {
        switch sport {
        case .run: return "Saisis la distance parcourue pendant les 6 min à fond."
        case .bike: return "Saisis ta puissance moyenne sur les 20 min à fond."
        default: return "Saisis tes temps sur 400 m et 200 m contre-la-montre."
        }
    }
    private var resultLabel: String {
        switch sport { case .run: return "VMA"; case .bike: return "FTP estimée"; default: return "CSS" }
    }
    private var resultValue: String {
        switch sport {
        case .run: return String(format: "%.1f km/h (VDOT ~%.0f)", vma, vdot)
        case .bike: return "\(ftp) W"
        default:
            let s = Int(css.rounded()); return String(format: "%d:%02d/100m", s / 60, s % 60)
        }
    }

    private func apply() {
        switch sport {
        case .run: onApply(vdot, nil, nil)
        case .bike: onApply(nil, ftp, nil)
        default: onApply(nil, nil, css)
        }
        DSHaptics.play(.success)
        dismiss()
    }

    private func timeRow(_ title: String, min: Binding<Int>, sec: Binding<Int>, minRange: ClosedRange<Int>) -> some View {
        HStack {
            Text(title); Spacer()
            Text("\(min.wrappedValue):\(String(format: "%02d", sec.wrappedValue))").monospacedDigit().foregroundStyle(DS.Color.primary)
            Stepper("", value: min, in: minRange).labelsHidden()
            Stepper("", value: sec, in: 0...59, step: 5).labelsHidden()
        }
    }
}
