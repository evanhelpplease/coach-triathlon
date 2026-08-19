import Foundation

/// Calcul de la charge d'une activité (TSS-like), avec repli progressif
/// selon les données disponibles : puissance → allure → FC (TRIMP).
public struct LoadCalculator: Sendable {
    public init() {}

    /// Charge d'une activité vélo depuis puissance normalisée & FTP.
    /// `TSS = (durée_s · NP · IF) / (FTP · 3600) · 100`, IF = NP/FTP.
    public func cyclingTSS(durationSec: Double, normalizedPowerW np: Double, ftpW ftp: Double) -> Double {
        guard ftp > 0 else { return 0 }
        let intensity = np / ftp
        return durationSec * np * intensity / (ftp * 3600.0) * 100.0
    }

    /// Charge course/nat depuis l'allure réalisée vs allure au seuil.
    /// Analogue au TSS : IF = vitesse/vitesseSeuil ; 1 h au seuil = 100.
    public func paceTSS(durationSec: Double, avgSpeed: Double, thresholdSpeed: Double) -> Double {
        guard thresholdSpeed > 0 else { return 0 }
        let intensity = avgSpeed / thresholdSpeed
        return durationSec / 3600.0 * intensity * intensity * 100.0
    }

    /// TRIMP de Banister (repli FC). `TRIMP = min · HRr · 0.64·e^(1.92·HRr)` (homme).
    public func trimp(durationSec: Double, avgHr: Int, hrRest: Int, hrMax: Int, sex: BiologicalSex) -> Double {
        guard hrMax > hrRest else { return 0 }
        let hrr = Double(avgHr - hrRest) / Double(hrMax - hrRest)
        let clamped = max(0, min(1, hrr))
        let k = sex == .female ? 1.67 : 1.92
        let b = sex == .female ? 0.86 : 0.64
        let minutes = durationSec / 60.0
        // Normalisé pour approcher l'échelle TSS (1 h au seuil ≈ 100).
        return minutes * clamped * b * exp(k * clamped) * 1.92
    }

    /// Charge d'une activité en choisissant la meilleure méthode disponible.
    public func load(for a: CompletedActivity, profile: AthleteProfile) -> Double {
        // 1) Puissance (vélo)
        if a.sport == .bike, let np = a.normalizedPowerW ?? a.avgPowerW, let ftp = profile.ftpWatts {
            return cyclingTSS(durationSec: a.duration, normalizedPowerW: Double(np), ftpW: Double(ftp))
        }
        // 2) Allure (course)
        if a.sport == .run, let pace = a.avgPaceSecPerKm, pace > 0, let vdot = profile.vdot {
            let thr = VDOT.trainingPaces(vdot: vdot).thresholdSecPerKm
            return paceTSS(durationSec: a.duration, avgSpeed: 1000.0 / pace, thresholdSpeed: 1000.0 / thr)
        }
        // 3) Allure (natation) via CSS
        if a.sport == .swim, let dist = a.distanceM, dist > 0, let css = profile.cssSecPer100m {
            let avgSpeed = dist / a.duration
            let thr = 100.0 / css
            return paceTSS(durationSec: a.duration, avgSpeed: avgSpeed, thresholdSpeed: thr)
        }
        // 4) FC (TRIMP)
        if let hr = a.avgHr, let rest = profile.hrRest {
            let max = profile.hrMax ?? profile.estimatedHRMax()
            return trimp(durationSec: a.duration, avgHr: hr, hrRest: rest, hrMax: max, sex: profile.sex)
        }
        // 5) Dernier repli : durée pondérée par un RPE.
        let rpe = Double(a.rpe ?? 5)
        return a.duration / 3600.0 * rpe * 12.0
    }
}

/// Indicateurs de charge d'un jour.
public struct LoadPoint: Sendable, Equatable {
    public var date: Date
    public var dailyLoad: Double
    public var ctl: Double        // fitness (chronic training load, τ=42j)
    public var atl: Double        // fatigue (acute, τ=7j)
    public var tsb: Double        // forme = CTL(veille) − ATL(veille)
    public var acwr: Double       // charge aiguë 7j / chronique 28j

    public init(date: Date, dailyLoad: Double, ctl: Double, atl: Double, tsb: Double, acwr: Double) {
        self.date = date
        self.dailyLoad = dailyLoad
        self.ctl = ctl
        self.atl = atl
        self.tsb = tsb
        self.acwr = acwr
    }
}

/// Construit la série CTL/ATL/TSB/ACWR à partir des charges quotidiennes.
public struct LoadSeries: Sendable {
    public init() {}

    static let ctlTau = 42.0
    static let atlTau = 7.0

    /// `dailyLoads` : charge totale par jour, triée du plus ancien au plus récent,
    /// un point par jour (0 pour les jours de repos).
    public func series(dailyLoads: [(date: Date, load: Double)], startCTL: Double = 0, startATL: Double = 0) -> [LoadPoint] {
        let alphaCTL = 1 - exp(-1.0 / Self.ctlTau)
        let alphaATL = 1 - exp(-1.0 / Self.atlTau)

        var ctl = startCTL, atl = startATL
        var points: [LoadPoint] = []
        var window: [Double] = []          // charges récentes pour l'ACWR

        for (i, day) in dailyLoads.enumerated() {
            // TSB = forme de la veille (avant absorption de la charge du jour).
            let tsb = ctl - atl

            ctl += alphaCTL * (day.load - ctl)
            atl += alphaATL * (day.load - atl)

            window.append(day.load)
            if window.count > 28 { window.removeFirst() }
            let acute = window.suffix(7).reduce(0, +) / 7.0
            let chronicCount = min(window.count, 28)
            let chronic = window.suffix(28).reduce(0, +) / Double(chronicCount)
            let acwr = chronic > 0 ? acute / chronic : 0

            points.append(LoadPoint(
                date: day.date,
                dailyLoad: day.load,
                ctl: ctl, atl: atl,
                tsb: i == 0 ? 0 : tsb,
                acwr: acwr
            ))
        }
        return points
    }
}
