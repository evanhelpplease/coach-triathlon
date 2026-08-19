import Foundation

/// Profil physiologique de l'athlète. Immuable ; on en crée une nouvelle
/// version quand une donnée évolue (les zones se recalibrent en conséquence).
public struct AthleteProfile: Codable, Sendable, Equatable {
    public var birthDate: Date
    public var sex: BiologicalSex
    public var heightCm: Double
    public var weightKg: Double

    // Référentiels physiologiques (optionnels ; estimés si absents).
    public var hrMax: Int?
    public var hrRest: Int?
    public var ftpWatts: Int?
    public var cssSecPer100m: Double?     // Critical Swim Speed
    public var vdot: Double?              // Daniels (course)

    public var levels: [Discipline: SkillLevel]

    public init(
        birthDate: Date,
        sex: BiologicalSex,
        heightCm: Double,
        weightKg: Double,
        hrMax: Int? = nil,
        hrRest: Int? = nil,
        ftpWatts: Int? = nil,
        cssSecPer100m: Double? = nil,
        vdot: Double? = nil,
        levels: [Discipline: SkillLevel] = [:]
    ) {
        self.birthDate = birthDate
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.hrMax = hrMax
        self.hrRest = hrRest
        self.ftpWatts = ftpWatts
        self.cssSecPer100m = cssSecPer100m
        self.vdot = vdot
        self.levels = levels
    }

    /// Âge en années à une date de référence donnée.
    public func age(on date: Date = Date(), calendar: Calendar = .init(identifier: .gregorian)) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }

    /// FC max estimée si non mesurée — formule de Nes (2013), plus juste que 220−âge.
    public func estimatedHRMax(on date: Date = Date()) -> Int {
        Int((211.0 - 0.64 * Double(age(on: date))).rounded())
    }
}

/// Blessure ou zone fragile déclarée.
public struct InjuryRecord: Codable, Sendable, Equatable {
    public enum BodyZone: String, Codable, Sendable {
        case ankle, knee, hip, lowerBack, shoulder, calf, hamstring, foot, other
    }
    public var zone: BodyZone
    public var intensity: Int          // 1–5
    public var since: Date
    public var affectedSports: Set<Sport>

    public init(zone: BodyZone, intensity: Int, since: Date, affectedSports: Set<Sport>) {
        self.zone = zone
        self.intensity = intensity
        self.since = since
        self.affectedSports = affectedSports
    }
}
