import Foundation
import TriathlonEngine

/// Source **Garmin Connect** (Garmin Health API, OAuth 2.0 + PKCE).
///
/// Module optionnel : renseigne `clientID`/`clientSecret` obtenus après inscription
/// au *Garmin Developer Program* (voir docs/GARMIN.md). La structure OAuth/PKCE et
/// les endpoints sont en place ; il reste à brancher `ASWebAuthenticationSession`
/// et le parsing des réponses de l'API (balisé par des TODO).
struct GarminProvider: HealthDataProvider {
    let id = "garmin"
    let displayName = "Garmin Connect"
    // Lecture riche (activités détaillées, sommeil, VFC, Body Battery). L'écriture de
    // workouts vers la montre relève de la Phase 3 (push structuré).
    let capabilities = ProviderCapabilities(readsActivities: true, readsReadiness: true, writesWorkouts: false)

    // À renseigner depuis le Garmin Developer Program (vide = module désactivé).
    var clientID = ""
    var clientSecret = ""
    var accessToken: String?

    var redirectURI = "com.evanblanchard.coachtriathlon:/garmin-oauth"
    let authEndpoint = "https://connect.garmin.com/oauth2Confirm"
    let tokenEndpoint = "https://diauth.garmin.com/di-oauth2-service/oauth/token"
    let apiBase = "https://apis.garmin.com/wellness-api/rest"

    var isConfigured: Bool { !clientID.isEmpty }

    func authorize() async throws {
        guard isConfigured else { throw ProviderError.unavailable }
        // TODO : ASWebAuthenticationSession(url: authorizationURL(...)) → code → token (PKCE).
        throw ProviderError.notAuthorized
    }

    func importActivities(since: Date) async throws -> [CompletedActivity] {
        guard accessToken != nil else { throw ProviderError.notAuthorized }
        // TODO : GET \(apiBase)/activities?uploadStartTimeInSeconds=… → mapper vers CompletedActivity.
        return []
    }

    func importReadiness(since: Date) async throws -> [DailyReadiness] {
        guard accessToken != nil else { throw ProviderError.notAuthorized }
        // TODO : GET \(apiBase)/dailies + /sleeps + /hrv → mapper (VFC, Body Battery, sommeil).
        return []
    }

    func writeCompletedWorkout(_ activity: CompletedActivity) async throws {
        throw ProviderError.unsupported
    }

    /// URL d'autorisation OAuth 2.0 avec défi PKCE (réutilise `PKCE`).
    func authorizationURL(codeChallenge: String, state: String) -> URL? {
        var comps = URLComponents(string: authEndpoint)
        comps?.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state)
        ]
        return comps?.url
    }
}

/// Aperçu « démo Garmin » : jeu de données volontairement PLUS riche et précis
/// qu'Apple Santé (puissance normalisée, cadence via allure fine, VFC quotidienne,
/// Body Battery, sommeil détaillé) — pour montrer ce que Garmin apporte.
struct GarminMockProvider: HealthDataProvider {
    let id = "garminDemo"
    let displayName = "Garmin (démo)"
    let capabilities = ProviderCapabilities(readsActivities: true, readsReadiness: true, writesWorkouts: false)

    func authorize() async throws {}

    func importActivities(since: Date) async throws -> [CompletedActivity] {
        let cal = Calendar(identifier: .gregorian)
        var out: [CompletedActivity] = []
        for day in 0..<30 {
            guard let date = cal.date(byAdding: .day, value: -day, to: .now) else { continue }
            switch day % 4 {
            case 0:
                out.append(CompletedActivity(sport: .run, start: date, duration: 3300, distanceM: 9800,
                    avgHr: 151, maxHr: 176, avgPaceSecPerKm: 337, hrDriftPct: 2.8, rpe: 6, source: .garmin))
            case 1:
                out.append(CompletedActivity(sport: .bike, start: date, duration: 5400, distanceM: 46000,
                    avgHr: 143, maxHr: 172, avgPowerW: 212, normalizedPowerW: 228, rpe: 5, source: .garmin))
            case 2:
                out.append(CompletedActivity(sport: .swim, start: date, duration: 2700, distanceM: 2600,
                    avgHr: 137, poolLengths: 104, rpe: 5, source: .garmin))
            default:
                out.append(CompletedActivity(sport: .bike, start: date, duration: 3000, distanceM: 22000,
                    avgHr: 156, maxHr: 181, avgPowerW: 255, normalizedPowerW: 271, hrDriftPct: 4.1, rpe: 8, source: .garmin))
            }
        }
        return out.filter { $0.start >= since }
    }

    func importReadiness(since: Date) async throws -> [DailyReadiness] {
        let cal = Calendar(identifier: .gregorian)
        return (0..<30).compactMap { day in
            guard let date = cal.date(byAdding: .day, value: -day, to: .now) else { return nil }
            let wobble = Double((day * 13) % 17) - 8
            return DailyReadiness(date: date,
                                  sleepHours: 7.6 + wobble / 12,
                                  hrRest: 46 + (day % 5),
                                  hrvMs: 82 + wobble,               // VFC quotidienne (précieuse pour l'adaptation)
                                  bodyBattery: 72 - (day % 6) * 5,  // Body Battery Garmin
                                  subjective: nil)
        }.filter { $0.date >= since }
    }

    func writeCompletedWorkout(_ activity: CompletedActivity) async throws {}
}
