import SwiftUI
import SwiftData

@main
struct CoachTriathlonApp: App {
    @State private var services = AppServices()
    @State private var accounts = AccountStore()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        let schema = Schema(AppSchema.models)
        // Tente la sync iCloud (CloudKit) ; repli sur un store local si le conteneur
        // iCloud n'est pas disponible (pas de compte / capability non activée).
        // → Pour activer la sync : ajouter la capability iCloud/CloudKit + le
        //   conteneur, décommenter le bloc dans CoachTriathlon.entitlements.
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let c = try? ModelContainer(for: schema, configurations: cloud) {
            container = c
        } else if let local = try? ModelContainer(for: schema) {
            container = local
        } else {
            fatalError("Impossible de créer le ModelContainer.")
        }
        BackgroundRefresh.container = container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(accounts)
                .environment(\.locale, Locale(identifier: "fr_FR")) // app francophone
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) {
            await BackgroundRefresh.handle()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
    }
}
