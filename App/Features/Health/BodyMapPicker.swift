import SwiftUI
import DesignSystem

/// Sélecteur interactif : silhouette dessinée + points tappables placés
/// précisément, puis liste déroulante des blessures précises de la zone.
struct BodyMapPicker: View {
    @Binding var zone: String     // raw value de InjuryRecord.BodyZone
    @Binding var detail: String   // nom de la blessure précise choisie

    private let mapSize = CGSize(width: 200, height: 360)

    private struct Marker: Identifiable { let id: String; let label: String; let pos: CGPoint }
    private let markers: [Marker] = [
        .init(id: "shoulder",  label: "Épaule",          pos: CGPoint(x: 0.30, y: 0.22)),
        .init(id: "lowerBack", label: "Bas du dos",      pos: CGPoint(x: 0.50, y: 0.46)),
        .init(id: "hip",       label: "Hanche",          pos: CGPoint(x: 0.60, y: 0.51)),
        .init(id: "hamstring", label: "Ischio-jambiers", pos: CGPoint(x: 0.42, y: 0.62)),
        .init(id: "knee",      label: "Genou",           pos: CGPoint(x: 0.42, y: 0.73)),
        .init(id: "calf",      label: "Mollet",          pos: CGPoint(x: 0.58, y: 0.82)),
        .init(id: "ankle",     label: "Cheville",        pos: CGPoint(x: 0.42, y: 0.90)),
        .init(id: "foot",      label: "Pied",            pos: CGPoint(x: 0.42, y: 0.955))
    ]

    var body: some View {
        VStack(spacing: DS.Space.sm) {
            Text("Zone : \(zoneLabel)")
                .font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
            Text("Touche l'endroit où tu as mal")
                .font(DS.Font.caption).foregroundStyle(DS.Color.textTertiary)

            silhouette
                .frame(width: mapSize.width, height: mapSize.height)
                .frame(maxWidth: .infinity)

            Button {
                select("other")
            } label: {
                Text("Autre / non localisée")
                    .font(DS.Font.caption)
                    .padding(.horizontal, DS.Space.sm).padding(.vertical, DS.Space.xxs)
                    .foregroundStyle(zone == "other" ? Color.black : DS.Color.textSecondary)
                    .background(zone == "other" ? DS.Color.accent : DS.Color.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(DS.Color.separator))
            }
            .buttonStyle(.plain)

            specificsPicker
        }
    }

    // MARK: Silhouette + points

    private var silhouette: some View {
        ZStack {
            // Corps (formes simples, contrôlées).
            let c = DS.Color.separator
            Circle().fill(c).frame(width: 42, height: 42).position(x: 100, y: 30)                  // tête
            Capsule().fill(c).frame(width: 104, height: 38).position(x: 100, y: 80)                // épaules
            RoundedRectangle(cornerRadius: 18).fill(c).frame(width: 70, height: 124).position(x: 100, y: 134) // tronc
            Capsule().fill(c).frame(width: 22, height: 112).position(x: 52, y: 134)                // bras g
            Capsule().fill(c).frame(width: 22, height: 112).position(x: 148, y: 134)               // bras d
            Capsule().fill(c).frame(width: 30, height: 176).position(x: 84, y: 260)                // jambe g
            Capsule().fill(c).frame(width: 30, height: 176).position(x: 116, y: 260)               // jambe d

            ForEach(markers) { m in
                marker(m)
            }
        }
    }

    private func marker(_ m: Marker) -> some View {
        let isSelected = zone == m.id
        return Circle()
            .fill(isSelected ? DS.Color.danger : DS.Color.surface)
            .overlay(Circle().strokeBorder(isSelected ? DS.Color.danger : DS.Color.textTertiary, lineWidth: 2))
            .frame(width: isSelected ? 26 : 18, height: isSelected ? 26 : 18)
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4)
            .frame(width: 44, height: 44)            // zone de tap élargie
            .contentShape(Circle())
            .position(x: mapSize.width * m.pos.x, y: mapSize.height * m.pos.y)
            .onTapGesture { select(m.id) }
            .animation(.spring(duration: 0.25), value: isSelected)
    }

    // MARK: Blessures précises

    @ViewBuilder private var specificsPicker: some View {
        let specifics = InjuryCatalog.specifics(forZone: zone)
        if !specifics.isEmpty {
            Divider().padding(.vertical, DS.Space.xxs)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Précise ta douleur").font(DS.Font.headline).foregroundStyle(DS.Color.textPrimary)
                Picker("Type", selection: $detail) {
                    ForEach(specifics) { s in Text(s.name).tag(s.name) }
                }
                .pickerStyle(.menu)
                .tint(DS.Color.primary)
                if let sel = specifics.first(where: { $0.name == detail }) {
                    Text(sel.sensation)
                        .font(DS.Font.callout).foregroundStyle(DS.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Sélection

    private func select(_ id: String) {
        zone = id
        // Réinitialise la blessure précise à la première option de la zone.
        detail = InjuryCatalog.specifics(forZone: id).first?.name ?? ""
        DSHaptics.play(.light)
    }

    private var zoneLabel: String {
        if zone == "other" { return "Autre" }
        return markers.first { $0.id == zone }?.label ?? "—"
    }
}
