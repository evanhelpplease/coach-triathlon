import Foundation
import CryptoKit
import Security

/// Compte utilisateur (identité locale — le multi-appareils nécessitera un backend).
struct Account: Codable, Equatable {
    enum Provider: String, Codable { case apple, google, email }
    var provider: Provider
    var userID: String
    var email: String?
    var displayName: String?

    var label: String {
        switch provider {
        case .apple: return "Apple" + (displayName.map { " · \($0)" } ?? "")
        case .google: return "Google" + (email.map { " · \($0)" } ?? "")
        case .email: return email ?? "Compte"
        }
    }
}

/// Gère l'état d'authentification. Persistance locale (UserDefaults + Keychain).
@Observable
final class AccountStore {
    private let storageKey = "coachtri.account"
    private(set) var account: Account?
    var isSignedIn: Bool { account != nil }

    init() { load() }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let a = try? JSONDecoder().decode(Account.self, from: data) {
            account = a
        }
    }
    private func persist() {
        if let a = account, let d = try? JSONEncoder().encode(a) {
            UserDefaults.standard.set(d, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    // MARK: Sign in with Apple

    func signInWithApple(userID: String, email: String?, fullName: String?) {
        // Le nom/email ne sont fournis qu'au tout premier login → on les conserve.
        var name = fullName
        if name == nil || name?.isEmpty == true { name = account?.displayName }
        account = Account(provider: .apple, userID: userID, email: email ?? account?.email, displayName: name)
        persist()
    }

    // MARK: Compte email local

    enum AuthError: LocalizedError {
        case weakPassword, alreadyExists, notFound, wrongPassword, googleNotConfigured
        var errorDescription: String? {
            switch self {
            case .weakPassword: return "Mot de passe trop court (6 caractères minimum)."
            case .alreadyExists: return "Un compte existe déjà pour cet email."
            case .notFound: return "Aucun compte pour cet email."
            case .wrongPassword: return "Mot de passe incorrect."
            case .googleNotConfigured: return "Connexion Google à configurer (voir docs/GOOGLE_CALENDAR.md pour l'OAuth)."
            }
        }
    }

    func createEmailAccount(email: String, password: String) throws {
        let key = "pw:\(email.lowercased())"
        guard password.count >= 6 else { throw AuthError.weakPassword }
        guard Keychain.get(key) == nil else { throw AuthError.alreadyExists }
        let salt = UUID().uuidString
        try Keychain.set("\(salt):\(Self.hash(password, salt: salt))", for: key)
        account = Account(provider: .email, userID: email.lowercased(), email: email, displayName: nil)
        persist()
    }

    func signInEmail(email: String, password: String) throws {
        let key = "pw:\(email.lowercased())"
        guard let stored = Keychain.get(key) else { throw AuthError.notFound }
        let parts = stored.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, Self.hash(password, salt: String(parts[0])) == String(parts[1]) else {
            throw AuthError.wrongPassword
        }
        account = Account(provider: .email, userID: email.lowercased(), email: email, displayName: nil)
        persist()
    }

    func signInGoogle() throws {
        // TODO : OAuth Google (réutiliser PKCE) → profil. Nécessite un client ID.
        throw AuthError.googleNotConfigured
    }

    func signOut() {
        account = nil
        persist()
    }

    private static func hash(_ password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Petit accès Keychain (chaînes), pour ne pas stocker les mots de passe en clair.
enum Keychain {
    private static let service = "com.evanblanchard.coachtriathlon"

    static func set(_ value: String, for account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
