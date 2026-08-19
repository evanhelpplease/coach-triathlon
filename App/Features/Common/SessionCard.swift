import SwiftUI
import DesignSystem
import TriathlonEngine

/// Carte de séance réutilisable (cockpit, plan).
struct SessionCard: View {
    let session: PlannedSession
    var highlighted: Bool = false

    var body: some View {
        DSCard {
            HStack(spacing: DS.Space.sm) {
                SportBadge(sportKey: session.sport.rawValue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(DS.Font.headline)
                        .foregroundStyle(DS.Color.textPrimary)
                        .lineLimit(1)
                    Text("\(Format.minutes(session.estimatedDuration)) · charge \(Int(session.estimatedLoad))")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer(minLength: DS.Space.xs)
                IntentTag(intent: session.intent)
            }
        }
        .overlay(alignment: .leading) {
            if highlighted {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Color.accent)
                    .frame(width: 4)
                    .padding(.vertical, DS.Space.sm)
            }
        }
    }
}

struct IntentTag: View {
    let intent: SessionIntent
    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, DS.Space.xs)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
    private var label: String {
        switch intent {
        case .recovery: return "Récup"
        case .endurance: return "Endurance"
        case .tempo: return "Tempo"
        case .threshold: return "Seuil"
        case .vo2: return "VO2max"
        case .sprint: return "Sprint"
        case .technique: return "Technique"
        case .brick: return "Brick"
        case .strength: return "Force"
        }
    }
    private var color: Color {
        switch intent {
        case .recovery, .endurance, .technique: return DS.Color.success
        case .tempo, .threshold: return DS.Color.warning
        case .vo2, .sprint, .brick: return DS.Color.danger
        case .strength: return DS.Color.strength
        }
    }
}
