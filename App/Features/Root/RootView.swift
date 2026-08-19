import SwiftUI
import SwiftData
import DesignSystem

/// Aiguillage : compte → onboarding si aucun profil → app principale.
struct RootView: View {
    @Environment(AccountStore.self) private var accounts
    @Query private var profiles: [ProfileModel]

    var body: some View {
        Group {
            if !accounts.isSignedIn {
                AuthView()
            } else if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .tint(DS.Color.accent)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            CockpitView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max.fill") }
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
            AnalyticsView()
                .tabItem { Label("Analyse", systemImage: "chart.xyaxis.line") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape.fill") }
        }
        .tint(DS.Color.accent)
    }
}
