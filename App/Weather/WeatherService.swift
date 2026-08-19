import Foundation
import CoreLocation
import TriathlonEngine

/// Conditions météo courantes + suggestion extérieur ↔ indoor.
struct WeatherNow: Sendable {
    var tempC: Double
    var precipitationMm: Double
    var windKmh: Double
    var code: Int

    var description: String {
        switch code {
        case 0: return "Ciel dégagé"
        case 1, 2: return "Peu nuageux"
        case 3: return "Couvert"
        case 45, 48: return "Brouillard"
        case 51, 53, 55, 56, 57: return "Bruine"
        case 61, 63, 65, 66, 67: return "Pluie"
        case 71, 73, 75, 77: return "Neige"
        case 80, 81, 82: return "Averses"
        case 95, 96, 99: return "Orage"
        default: return "—"
        }
    }
    var symbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Conditions défavorables à une séance extérieure.
    var isRoughOutdoor: Bool {
        precipitationMm >= 0.3 || (61...99).contains(code) || windKmh >= 40 || tempC <= 0 || tempC >= 35
    }

    /// Suggestion selon le sport prévu (extérieur uniquement).
    func suggestion(for sport: Sport?) -> String? {
        guard isRoughOutdoor else {
            return "Bonnes conditions pour t'entraîner dehors."
        }
        switch sport {
        case .bike, .brick: return "Conditions difficiles dehors → home trainer conseillé aujourd'hui."
        case .run: return "Conditions difficiles dehors → tapis de course si possible."
        default: return "Conditions difficiles dehors : privilégie l'indoor."
        }
    }
}

/// Récupère la météo via Open-Meteo (gratuit, sans clé) à la position de l'utilisateur.
enum WeatherService {
    private static let parisFallback = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

    static func fetch() async -> WeatherNow? {
        let coord = await locatedCoordinate()
        return try? await current(lat: coord.latitude, lon: coord.longitude)
    }

    /// Position de l'utilisateur, avec timeout (repli Paris) pour ne jamais bloquer.
    private static func locatedCoordinate() async -> CLLocationCoordinate2D {
        let located = await withTaskGroup(of: CLLocationCoordinate2D?.self) { group -> CLLocationCoordinate2D? in
            group.addTask { await LocationProvider().current() }
            group.addTask {
                try? await Task.sleep(nanoseconds: 4_000_000_000)   // 4 s
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        return located ?? parisFallback
    }

    static func current(lat: Double, lon: Double) async throws -> WeatherNow {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,precipitation,weather_code,wind_speed_10m")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return WeatherNow(
            tempC: decoded.current.temperature_2m,
            precipitationMm: decoded.current.precipitation,
            windKmh: decoded.current.wind_speed_10m,
            code: decoded.current.weather_code
        )
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let precipitation: Double
            let weather_code: Int
            let wind_speed_10m: Double
        }
        let current: Current
    }
}

/// Récupération one-shot de la position (CoreLocation), avec repli si refusé.
/// @MainActor : CLLocationManager doit vivre sur le thread principal pour recevoir
/// ses callbacks.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    func current() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { cont in
            self.continuation = cont
            manager.delegate = self
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            default: finish(nil)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        finish(locs.first?.coordinate)
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }
    private func finish(_ coord: CLLocationCoordinate2D?) {
        continuation?.resume(returning: coord)
        continuation = nil
    }
}
