import SwiftUI

// MARK: - Carte

/// Conteneur surface arrondi, ombre douce, base de la hiérarchie visuelle.
public struct DSCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    public init(padding: CGFloat = DS.Space.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Color.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

// MARK: - Bouton principal

public struct PrimaryButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    public var body: some View {
        Button {
            DSHaptics.play(.medium)
            action()
        } label: {
            HStack(spacing: DS.Space.xs) {
                if let icon { Image(systemName: icon) }
                Text(title).font(DS.Font.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.md)
            .foregroundStyle(Color.black)
            .background(DS.Color.accent, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tuile statistique

public struct StatTile: View {
    public enum Trend { case up, down, flat }
    private let label: String
    private let value: String
    private let unit: String?
    private let trend: Trend?
    private let tint: Color

    public init(label: String, value: String, unit: String? = nil, trend: Trend? = nil, tint: Color = DS.Color.primary) {
        self.label = label; self.value = value; self.unit = unit; self.trend = trend; self.tint = tint
    }
    public var body: some View {
        DSCard(padding: DS.Space.sm) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(label.uppercased())
                    .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(DS.Font.number(24)).foregroundStyle(DS.Color.textPrimary)
                    if let unit { Text(unit).font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary) }
                    if let trend {
                        Image(systemName: trend == .up ? "arrow.up.right" : trend == .down ? "arrow.down.right" : "arrow.right")
                            .font(.caption2.bold())
                            .foregroundStyle(trendColor(trend))
                    }
                }
            }
        }
    }
    private func trendColor(_ t: Trend) -> Color {
        switch t { case .up: return DS.Color.success; case .down: return DS.Color.danger; case .flat: return DS.Color.textTertiary }
    }
}

// MARK: - Jauge circulaire (état de forme / TSB)

public struct RingGauge: View {
    private let progress: Double   // 0...1
    private let label: String
    private let value: String
    private let tint: Color

    public init(progress: Double, label: String, value: String, tint: Color = DS.Color.primary) {
        self.progress = max(0, min(1, progress)); self.label = label; self.value = value; self.tint = tint
    }
    public var body: some View {
        ZStack {
            Circle().stroke(DS.Color.separator, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.6), tint], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)
            VStack(spacing: 2) {
                Text(value).font(DS.Font.number(26)).foregroundStyle(DS.Color.textPrimary)
                Text(label.uppercased()).font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
            }
        }
    }
}

// MARK: - Badge de discipline

public struct SportBadge: View {
    private let systemImage: String
    private let sportKey: String
    public init(sportKey: String) {
        self.sportKey = sportKey
        self.systemImage = Self.icon(sportKey)
    }
    public static func icon(_ key: String) -> String {
        switch key {
        case "swim": return "figure.pool.swim"
        case "bike": return "figure.outdoor.cycle"
        case "run": return "figure.run"
        case "strength": return "dumbbell.fill"
        case "brick": return "bolt.fill"
        default: return "figure.mixed.cardio"
        }
    }
    public var body: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(DS.Color.sport(sportKey))
            .frame(width: 40, height: 40)
            .background(DS.Color.sport(sportKey).opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }
}

// MARK: - Compte à rebours course

public struct CountdownBadge: View {
    private let days: Int
    private let title: String
    public init(days: Int, title: String) { self.days = days; self.title = title }
    public var body: some View {
        HStack(spacing: DS.Space.sm) {
            VStack(spacing: 0) {
                Text("\(days)").font(DS.Font.number(30)).foregroundStyle(DS.Color.accent)
                Text("JOURS").font(.caption2).foregroundStyle(DS.Color.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Prochaine course").font(DS.Font.caption).foregroundStyle(DS.Color.textSecondary)
                Text(title).font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary).lineLimit(1)
            }
            Spacer()
        }
    }
}
