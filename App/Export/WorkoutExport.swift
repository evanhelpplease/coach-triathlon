import Foundation
import TriathlonEngine

/// Génère des fichiers de séance importables manuellement dans Zwift (.zwo) et
/// sur une montre Garmin (.fit).
enum WorkoutExport {

    // MARK: Aplatissement des pas (les blocs répétés sont dépliés)

    struct FlatStep { var kind: StepKind; var seconds: TimeInterval; var target: StepTarget }

    static func flatten(_ steps: [WorkoutStep]) -> [FlatStep] {
        var out: [FlatStep] = []
        for s in steps {
            if s.kind == .repeatBlock, let reps = s.repeats, let children = s.children {
                for _ in 0..<reps {
                    for c in children { out.append(FlatStep(kind: c.kind, seconds: seconds(c), target: c.target)) }
                }
            } else {
                out.append(FlatStep(kind: s.kind, seconds: seconds(s), target: s.target))
            }
        }
        return out
    }

    private static func seconds(_ s: WorkoutStep) -> TimeInterval {
        max(1, s.duration.estimatedSeconds(paceSecPerKm: nil))
    }

    /// Fraction de FTP (0…) représentative d'un pas, pour l'export .zwo.
    static func powerFraction(_ f: FlatStep, ftp: Int?) -> Double {
        switch f.target {
        case .powerRange(let lo, let hi):
            if let ftp, ftp > 0 { return ((lo + hi) / 2) / Double(ftp) }
            return 0.85
        case .hrZone(let z):
            return [0.5, 0.65, 0.8, 0.95, 1.1][min(max(z, 1), 5) - 1]
        default:
            switch f.kind {
            case .warmup: return 0.55
            case .cooldown, .recovery, .rest: return 0.5
            default: return 0.75
            }
        }
    }

    // MARK: - Export .ZWO (Zwift, XML)

    static func zwo(session: PlannedSession, ftp: Int?) -> String {
        let sport = session.sport == .run ? "run" : "bike"
        var xml = """
        <workout_file>
          <author>Coach Triathlon IA</author>
          <name>\(escape(session.title))</name>
          <description>\(escape(session.notes))</description>
          <sportType>\(sport)</sportType>
          <workout>

        """
        let flat = flatten(session.steps)
        for f in flat {
            let p = String(format: "%.2f", powerFraction(f, ftp: ftp))
            let dur = Int(f.seconds.rounded())
            switch f.kind {
            case .warmup:
                xml += "    <Warmup Duration=\"\(dur)\" PowerLow=\"0.45\" PowerHigh=\"\(p)\"/>\n"
            case .cooldown:
                xml += "    <Cooldown Duration=\"\(dur)\" PowerLow=\"\(p)\" PowerHigh=\"0.4\"/>\n"
            default:
                xml += "    <SteadyState Duration=\"\(dur)\" Power=\"\(p)\"/>\n"
            }
        }
        xml += "  </workout>\n</workout_file>\n"
        return xml
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Export .FIT (binaire Garmin)

    static func fit(session: PlannedSession) -> Data {
        var enc = FITEncoder()
        enc.fileId(sport: session.sport, createdAt: session.date)
        let flat = flatten(session.steps)
        enc.workout(name: session.title, sport: session.sport, steps: flat.count)
        for (i, f) in flat.enumerated() {
            enc.workoutStep(index: i, step: f)
        }
        return enc.finalize()
    }

    // MARK: - Écriture de fichiers temporaires (pour le partage)

    static func writeFiles(for session: PlannedSession, ftp: Int?) -> [URL] {
        let dir = FileManager.default.temporaryDirectory
        let base = slug(session.title)
        var urls: [URL] = []
        let zwoURL = dir.appendingPathComponent("\(base).zwo")
        if (try? zwo(session: session, ftp: ftp).data(using: .utf8)?.write(to: zwoURL)) != nil {
            urls.append(zwoURL)
        }
        let fitURL = dir.appendingPathComponent("\(base).fit")
        if (try? fit(session: session).write(to: fitURL)) != nil {
            urls.append(fitURL)
        }
        return urls
    }

    private static func slug(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let cleaned = s.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(cleaned).replacingOccurrences(of: "--", with: "-")
    }
}

// MARK: - Encodeur FIT minimal mais conforme (header + messages + CRC)

/// Encode un fichier FIT « workout » : file_id (0), workout (26), workout_step (27).
/// Les pas sont temporels ; cibles puissance/FC/ouvert. Nécessite validation sur
/// un appareil Garmin réel avant diffusion.
struct FITEncoder {
    private var records = Data()
    private var stepDefWritten = false

    // Décalage epoch FIT (1989-12-31) vs Unix.
    private static let fitEpoch: TimeInterval = 631_065_600

    // Types de base FIT.
    private let tEnum: UInt8 = 0x00, tUint8: UInt8 = 0x02, tUint16: UInt8 = 0x84
    private let tUint32: UInt8 = 0x86, tString: UInt8 = 0x07, tUint32z: UInt8 = 0x8C

    // MARK: file_id (global 0) → local 0
    mutating func fileId(sport: Sport, createdAt: Date) {
        // Définition
        var def = Data([0x40, 0x00, 0x00])          // header def, reserved, little-endian
        def.append(uint16LE(0))                      // global message number = 0
        def.append(5)                                // 5 champs
        appendField(&def, num: 0, size: 1, type: tEnum)     // type
        appendField(&def, num: 1, size: 2, type: tUint16)   // manufacturer
        appendField(&def, num: 2, size: 2, type: tUint16)   // product
        appendField(&def, num: 3, size: 4, type: tUint32z)  // serial
        appendField(&def, num: 4, size: 4, type: tUint32)   // time_created
        records.append(def)
        // Données
        var d = Data([0x00])                         // header data, local 0
        d.append(5)                                  // type = workout(5)
        d.append(uint16LE(255))                      // manufacturer = development
        d.append(uint16LE(0))                        // product
        d.append(uint32LE(0))                        // serial
        d.append(uint32LE(fitTime(createdAt)))
        records.append(d)
    }

    // MARK: workout (global 26) → local 1
    mutating func workout(name: String, sport: Sport, steps: Int) {
        let nameData = fitString(name, maxLen: 32)
        var def = Data([0x41, 0x00, 0x00])
        def.append(uint16LE(26))
        def.append(3)                                                    // 3 champs
        appendField(&def, num: 8, size: UInt8(nameData.count), type: tString) // wkt_name
        appendField(&def, num: 4, size: 1, type: tEnum)                  // sport
        appendField(&def, num: 6, size: 2, type: tUint16)               // num_valid_steps
        records.append(def)

        var d = Data([0x01])
        d.append(nameData)
        d.append(fitSport(sport))
        d.append(uint16LE(UInt16(steps)))
        records.append(d)
    }

    // MARK: workout_step (global 27) → local 2
    mutating func workoutStep(index: Int, step: WorkoutExport.FlatStep) {
        if !stepDefWritten {
            var def = Data([0x42, 0x00, 0x00])
            def.append(uint16LE(27))
            def.append(7)                                       // 7 champs
            appendField(&def, num: 254, size: 2, type: tUint16) // message_index
            appendField(&def, num: 1, size: 1, type: tEnum)     // duration_type
            appendField(&def, num: 2, size: 4, type: tUint32)   // duration_value
            appendField(&def, num: 3, size: 1, type: tEnum)     // target_type
            appendField(&def, num: 4, size: 4, type: tUint32)   // target_value
            appendField(&def, num: 5, size: 4, type: tUint32)   // custom_low
            appendField(&def, num: 6, size: 4, type: tUint32)   // custom_high
            records.append(def)
            stepDefWritten = true
        }

        var d = Data([0x02])
        d.append(uint16LE(UInt16(index)))
        d.append(0)                                             // duration_type = time
        d.append(uint32LE(UInt32(step.seconds * 1000)))        // ms

        let (targetType, targetValue, low, high) = target(step.target)
        d.append(targetType)
        d.append(uint32LE(targetValue))
        d.append(uint32LE(low))
        d.append(uint32LE(high))
        records.append(d)
        // NB : l'intensité (échauffement/effort/récup) est omise ici pour rester
        // sur une définition stable ; les montres l'infèrent des cibles.
    }

    private func target(_ t: StepTarget) -> (UInt8, UInt32, UInt32, UInt32) {
        switch t {
        case .powerRange(let lo, let hi):
            // Puissance absolue : offset +1000 selon la spec FIT.
            return (4, 0, UInt32(lo + 1000), UInt32(hi + 1000))
        case .hrZone(let z):
            return (1, UInt32(max(1, z)), 0, 0)                 // cible par zone de FC
        default:
            return (2, 0, 0, 0)                                 // open
        }
    }

    // MARK: Finalisation (header 14 o + données + CRC)
    mutating func finalize() -> Data {
        var header = Data()
        header.append(14)                                       // taille header
        header.append(0x20)                                     // protocole 2.0
        header.append(uint16LE(2140))                           // version profil
        header.append(uint32LE(UInt32(records.count)))          // taille données
        header.append(contentsOf: Array(".FIT".utf8))
        header.append(uint16LE(Self.crc16(header)))             // CRC des 12 premiers octets

        var file = header
        file.append(records)
        file.append(uint16LE(Self.crc16(file)))                 // CRC global
        return file
    }

    // MARK: Helpers d'encodage
    private func appendField(_ d: inout Data, num: UInt8, size: UInt8, type: UInt8) {
        d.append(num); d.append(size); d.append(type)
    }
    private func uint16LE(_ v: UInt16) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
    private func uint32LE(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }
    private func fitTime(_ date: Date) -> UInt32 { UInt32(max(0, date.timeIntervalSince1970 - Self.fitEpoch)) }
    private func fitSport(_ s: Sport) -> UInt8 {
        switch s { case .run: return 1; case .bike: return 2; case .swim: return 5; default: return 10 }
    }
    private func fitString(_ s: String, maxLen: Int) -> Data {
        var bytes = Array(s.utf8.prefix(maxLen - 1))
        bytes.append(0)                                          // terminateur nul
        return Data(bytes)
    }

    // CRC-16 standard FIT.
    private static let crcTable: [UInt16] = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400
    ]
    static func crc16(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            var tmp = crcTable[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ crcTable[Int(byte & 0xF)]
            tmp = crcTable[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ crcTable[Int((UInt16(byte) >> 4) & 0xF)]
        }
        return crc
    }
}
