import Foundation

// MARK: - Sports & disciplines

/// Une activité planifiable ou réalisée.
public enum Sport: String, Codable, Sendable, CaseIterable {
    case swim, bike, run, strength, brick
}

/// Les trois disciplines chronométrées (support des zones et prédictions).
public enum Discipline: String, Codable, Sendable, CaseIterable {
    case swim, bike, run
}

public enum SkillLevel: Int, Codable, Sendable, Comparable {
    case beginner = 0, novice, intermediate, advanced, expert
    public static func < (l: SkillLevel, r: SkillLevel) -> Bool { l.rawValue < r.rawValue }
}

public enum BiologicalSex: String, Codable, Sendable { case male, female, other }

public enum BikeType: String, Codable, Sendable {
    case road, tt, gravel, mtb, trainer
}

// MARK: - Sexe / provenance des données

public enum DataSource: String, Codable, Sendable {
    case appleHealth, garmin, manual, generated
}

// MARK: - Phases de périodisation

public enum TrainingPhase: String, Codable, Sendable, CaseIterable {
    case base, build, specific, taper, recovery
}

// MARK: - Intentions de séance

public enum SessionIntent: String, Codable, Sendable, CaseIterable {
    case recovery, endurance, tempo, threshold, vo2, sprint, technique, brick, strength
}

// MARK: - Priorité & formats de course

public enum RacePriority: String, Codable, Sendable { case a, b, c }

/// Volonté de progression : arbitre la vitesse de montée de charge et le volume
/// d'intensité (donc le risque de blessure).
public enum ProgressionLevel: String, Codable, Sendable, CaseIterable {
    case prudent, balanced, performance
}

public enum RaceFormat: String, Codable, Sendable, CaseIterable {
    // triathlon
    case xs, sprint, olympic, half, full
    // mono-sport course
    case run10k, halfMarathon, marathon

    /// Distances par discipline (m). nil = pas concerné.
    public var swimMeters: Double? {
        switch self {
        case .xs: return 400
        case .sprint: return 750
        case .olympic: return 1500
        case .half: return 1900
        case .full: return 3800
        default: return nil
        }
    }
    public var bikeMeters: Double? {
        switch self {
        case .xs: return 10_000
        case .sprint: return 20_000
        case .olympic: return 40_000
        case .half: return 90_000
        case .full: return 180_000
        default: return nil
        }
    }
    public var runMeters: Double {
        switch self {
        case .xs: return 2_500
        case .sprint: return 5_000
        case .olympic: return 10_000
        case .half: return 21_097.5
        case .full: return 42_195
        case .run10k: return 10_000
        case .halfMarathon: return 21_097.5
        case .marathon: return 42_195
        }
    }
    public var isTriathlon: Bool { swimMeters != nil }
}
