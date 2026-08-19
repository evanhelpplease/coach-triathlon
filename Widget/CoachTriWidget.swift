import WidgetKit
import SwiftUI
import DesignSystem

struct CoachTriEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot?
}

struct CoachTriProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoachTriEntry {
        CoachTriEntry(date: .now, snap: .sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (CoachTriEntry) -> Void) {
        completion(CoachTriEntry(date: .now, snap: WidgetStore.load() ?? .sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoachTriEntry>) -> Void) {
        let entry = CoachTriEntry(date: .now, snap: WidgetStore.load())
        // Rafraîchit dans ~2 h (ou au prochain lancement de l'app).
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CoachTriWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CoachTriEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        default: medium
        }
    }

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

    @ViewBuilder private var small: some View {
        if let s = entry.snap, s.hasSession {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: sportIcon(s.todaySportKey))
                        .foregroundStyle(DS.Color.sport(s.todaySportKey))
                    Spacer()
                    if let tsb = s.formTSB {
                        Text("\(tsb > 0 ? "+" : "")\(tsb)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
                Spacer()
                Text("Aujourd'hui").font(.caption2).foregroundStyle(DS.Color.textTertiary)
                Text(s.todayTitle).font(.headline).foregroundStyle(DS.Color.textPrimary).lineLimit(2)
                Text("\(s.todayMinutes) min · charge \(s.todayLoad)")
                    .font(.caption2).foregroundStyle(DS.Color.textSecondary)
            }
        } else {
            emptyView
        }
    }

    @ViewBuilder private var medium: some View {
        if let s = entry.snap {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Séance du jour").font(.caption2).foregroundStyle(DS.Color.textTertiary)
                    if s.hasSession {
                        HStack(spacing: 8) {
                            Image(systemName: sportIcon(s.todaySportKey))
                                .foregroundStyle(DS.Color.sport(s.todaySportKey))
                            Text(s.todayTitle).font(.headline).foregroundStyle(DS.Color.textPrimary).lineLimit(2)
                        }
                        Text("\(s.todayMinutes) min · charge \(s.todayLoad)")
                            .font(.caption).foregroundStyle(DS.Color.textSecondary)
                    } else {
                        Text("Repos aujourd'hui").font(.headline).foregroundStyle(DS.Color.textPrimary)
                    }
                    Spacer()
                    if let days = s.raceDays, let title = s.raceTitle {
                        Text("\(days) j → \(title)").font(.caption2).foregroundStyle(DS.Color.accent)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(s.formTSB.map { "\($0 > 0 ? "+" : "")\($0)" } ?? "—")
                        .font(.title.bold().monospacedDigit()).foregroundStyle(DS.Color.primary)
                    Text("FORME").font(.caption2).foregroundStyle(DS.Color.textTertiary)
                    Text(s.formLabel).font(.caption2).foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center).lineLimit(2)
                }
                .frame(width: 96)
            }
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.mixed.cardio").foregroundStyle(DS.Color.textTertiary)
            Text("Ouvre Coach Tri").font(.caption).foregroundStyle(DS.Color.textSecondary)
        }
    }
}

struct CoachTriWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CoachTriWidget", provider: CoachTriProvider()) { entry in
            CoachTriWidgetView(entry: entry)
                .containerBackground(DS.Color.background, for: .widget)
        }
        .configurationDisplayName("Coach Triathlon")
        .description("Ta séance du jour et ton état de forme.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CoachTriWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoachTriWidget()
        SessionLiveActivity()
    }
}
