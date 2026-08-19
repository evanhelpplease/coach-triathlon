import ActivityKit
import WidgetKit
import SwiftUI
import DesignSystem

private func sportIcon(_ key: String) -> String {
    switch key {
    case "swim": return "figure.pool.swim"
    case "bike": return "figure.outdoor.cycle"
    case "run": return "figure.run"
    case "strength": return "dumbbell.fill"
    case "brick": return "bolt.fill"
    default: return "figure.mixed.cardio"
    }
}

struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            // Écran verrouillé / bannière
            HStack(spacing: DS.Space.md) {
                Image(systemName: sportIcon(context.attributes.sportKey))
                    .font(.title2).foregroundStyle(DS.Color.sport(context.attributes.sportKey))
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title).font(.headline).foregroundStyle(DS.Color.textPrimary).lineLimit(1)
                    Text(context.state.stepName).font(.caption).foregroundStyle(DS.Color.textSecondary).lineLimit(1)
                }
                Spacer()
                Text(context.state.startedAt, style: .timer)
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(DS.Color.primary)
                    .frame(width: 84)
            }
            .padding()
            .activityBackgroundTint(DS.Color.background)
            .activitySystemActionForegroundColor(DS.Color.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.title).font(.caption).lineLimit(1)
                    } icon: {
                        Image(systemName: sportIcon(context.attributes.sportKey))
                            .foregroundStyle(DS.Color.sport(context.attributes.sportKey))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.title3.monospacedDigit().bold())
                        .foregroundStyle(DS.Color.primary)
                        .frame(width: 70)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stepName).font(.caption).foregroundStyle(DS.Color.textSecondary)
                }
            } compactLeading: {
                Image(systemName: sportIcon(context.attributes.sportKey))
                    .foregroundStyle(DS.Color.sport(context.attributes.sportKey))
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.Color.primary)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: sportIcon(context.attributes.sportKey))
                    .foregroundStyle(DS.Color.sport(context.attributes.sportKey))
            }
        }
    }
}
