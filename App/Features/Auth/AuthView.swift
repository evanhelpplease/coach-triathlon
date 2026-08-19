import SwiftUI
import AuthenticationServices
import DesignSystem

/// Écran de création de compte / connexion (Apple, Google, email).
struct AuthView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRegistering = true
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                header

                VStack(spacing: DS.Space.sm) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(Capsule())

                    Button { handleGoogle() } label: {
                        HStack(spacing: DS.Space.xs) {
                            Image(systemName: "globe")
                            Text("Continuer avec Google").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(DS.Color.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(DS.Color.separator))
                        .foregroundStyle(DS.Color.textPrimary)
                    }
                    .buttonStyle(.plain)
                }

                dividerOr
                emailForm

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(DS.Font.caption).foregroundStyle(DS.Color.danger)
                        .multilineTextAlignment(.center)
                }

                Text("Compte local sur cet appareil. La synchronisation multi-appareils (email) arrivera avec la sauvegarde iCloud/serveur.")
                    .font(.caption2).foregroundStyle(DS.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(DS.Space.lg)
        }
        .background(DS.Color.background.ignoresSafeArea())
        .tint(DS.Color.accent)
    }

    private var header: some View {
        VStack(spacing: DS.Space.xs) {
            Text("🏊‍♂️🚴 🏃").font(.system(size: 44))
            Text("Coach Triathlon").font(DS.Font.display(30)).foregroundStyle(DS.Color.textPrimary)
            Text("Ton coach IA, personnalisé et adaptatif.")
                .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.top, DS.Space.xl)
    }

    private var dividerOr: some View {
        HStack {
            Rectangle().fill(DS.Color.separator).frame(height: 0.5)
            Text("ou").font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)
            Rectangle().fill(DS.Color.separator).frame(height: 0.5)
        }
    }

    private var emailForm: some View {
        VStack(spacing: DS.Space.sm) {
            Picker("", selection: $isRegistering) {
                Text("Créer un compte").tag(true)
                Text("Se connecter").tag(false)
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding().background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            SecureField("Mot de passe", text: $password)
                .textContentType(isRegistering ? .newPassword : .password)
                .padding().background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            Button { handleEmail() } label: {
                Text(isRegistering ? "Créer mon compte" : "Se connecter")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, DS.Space.md)
                    .foregroundStyle(Color.black).background(DS.Color.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
        }
    }

    // MARK: Actions

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                let name = cred.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) }
                accounts.signInWithApple(userID: cred.user, email: cred.email, fullName: name?.isEmpty == true ? nil : name)
                DSHaptics.play(.success)
            }
        case .failure(let error):
            errorMessage = "Connexion Apple annulée ou indisponible : \(error.localizedDescription)"
        }
    }

    private func handleGoogle() {
        do { try accounts.signInGoogle() }
        catch { errorMessage = error.localizedDescription }
    }

    private func handleEmail() {
        errorMessage = ""
        do {
            if isRegistering { try accounts.createEmailAccount(email: email, password: password) }
            else { try accounts.signInEmail(email: email, password: password) }
            DSHaptics.play(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
