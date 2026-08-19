import Foundation

public struct PersonalRecord: Sendable, Equatable, Identifiable {
    public var id: String { sportKey + label }
    public var sportKey: String
    public var label: String
    public var value: String
    public var date: Date
    public init(sportKey: String, label: String, value: String, date: Date) {
        self.sportKey = sportKey; self.label = label; self.value = value; self.date = date
    }
}

/// Calcule les records personnels à partir des activités réalisées.
public struct PersonalRecords: Sendable {
    public init() {}

    public func compute(from activities: [CompletedActivity]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []

        for sport in [Sport.swim, .bike, .run] {
            let acts = activities.filter { $0.sport == sport }
            guard !acts.isEmpty else { continue }

            // Plus longue distance.
            if let longest = acts.filter({ $0.distanceM != nil }).max(by: { ($0.distanceM ?? 0) < ($1.distanceM ?? 0) }),
               let d = longest.distanceM {
                records.append(.init(sportKey: sport.rawValue, label: "Plus longue distance",
                                     value: km(d), date: longest.start))
            }
            // Plus longue durée.
            if let longest = acts.max(by: { $0.duration < $1.duration }) {
                records.append(.init(sportKey: sport.rawValue, label: "Plus longue durée",
                                     value: duration(longest.duration), date: longest.start))
            }
            // Records spécifiques.
            switch sport {
            case .bike:
                if let best = acts.compactMap({ a in (a.normalizedPowerW ?? a.avgPowerW).map { (a, $0) } })
                    .max(by: { $0.1 < $1.1 }) {
                    records.append(.init(sportKey: sport.rawValue, label: "Meilleure puissance",
                                         value: "\(best.1) W", date: best.0.start))
                }
            case .run:
                if let best = acts.filter({ ($0.distanceM ?? 0) >= 3000 })
                    .compactMap({ a in a.avgPaceSecPerKm.map { (a, $0) } })
                    .min(by: { $0.1 < $1.1 }) {
                    records.append(.init(sportKey: sport.rawValue, label: "Meilleure allure (≥3 km)",
                                         value: pace(best.1), date: best.0.start))
                }
            case .swim:
                if let best = acts.filter({ ($0.distanceM ?? 0) > 0 })
                    .map({ a in (a, 100.0 / (a.distanceM! / a.duration)) })
                    .min(by: { $0.1 < $1.1 }) {
                    records.append(.init(sportKey: sport.rawValue, label: "Meilleure allure /100 m",
                                         value: pace100(best.1), date: best.0.start))
                }
            default: break
            }
        }
        return records
    }

    private func km(_ m: Double) -> String { String(format: "%.1f km", m / 1000) }
    private func duration(_ s: TimeInterval) -> String {
        let t = Int(s.rounded()); let h = t / 3600, m = (t % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
    private func pace(_ secPerKm: Double) -> String {
        let s = Int(secPerKm.rounded()); return String(format: "%d:%02d/km", s / 60, s % 60)
    }
    private func pace100(_ secPer100: Double) -> String {
        let s = Int(secPer100.rounded()); return String(format: "%d:%02d/100m", s / 60, s % 60)
    }
}
