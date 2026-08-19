import Foundation
import CryptoKit
import TriathlonEngine

/// Abstraction d'un agenda distant (interchangeable : Google, plus tard d'autres).
protocol RemoteCalendar {
    var isConfigured: Bool { get }
    func connect() async throws
    func push(sessions: [PlannedSession]) async throws
}

enum RemoteCalendarError: Error { case notConfigured, notConnected }

/// Client Google Agenda (OAuth 2.0 + PKCE). **Module optionnel activable plus tard** :
/// renseigne `clientID`/`redirectURI` (projet Google Cloud gratuit) pour l'activer.
/// La partie cryptographique PKCE est implémentée ; il reste à brancher le flux
/// `ASWebAuthenticationSession` et les appels à l'API Calendar (voir docs/GOOGLE_CALENDAR.md).
struct GoogleCalendarClient: RemoteCalendar {
    // À renseigner depuis un projet Google Cloud (laisser vide = module désactivé).
    var clientID = ""
    var redirectURI = "com.evanblanchard.coachtriathlon:/oauth2redirect"
    let scope = "https://www.googleapis.com/auth/calendar.events"
    let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    let tokenEndpoint = "https://oauth2.googleapis.com/token"

    var isConfigured: Bool { !clientID.isEmpty }

    func connect() async throws {
        guard isConfigured else { throw RemoteCalendarError.notConfigured }
        // TODO(Phase ultérieure) : ASWebAuthenticationSession(url: authorizationURL())
        // → récupérer le code → échanger contre un token sur `tokenEndpoint` (PKCE).
        throw RemoteCalendarError.notConfigured
    }

    func push(sessions: [PlannedSession]) async throws {
        guard isConfigured else { throw RemoteCalendarError.notConfigured }
        // TODO : POST https://www.googleapis.com/calendar/v3/calendars/primary/events
        throw RemoteCalendarError.notConnected
    }

    /// Construit l'URL d'autorisation OAuth avec le défi PKCE.
    func authorizationURL(codeChallenge: String, state: String) -> URL? {
        var comps = URLComponents(string: authEndpoint)
        comps?.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "access_type", value: "offline")
        ]
        return comps?.url
    }
}

/// PKCE (RFC 7636) : vérifieur aléatoire + défi SHA-256 en base64url.
enum PKCE {
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }
    static func challenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return base64URL(Data(hash))
    }
    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
