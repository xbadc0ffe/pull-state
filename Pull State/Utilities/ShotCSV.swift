// ShotCSV.swift
//
// CSV export of the shot history (About → Your Data → Export shots). The
// formatting is pure (`ShotCSV`) and unit-tested; `ShotCSVExport` is the
// `Transferable` handed to `ShareLink`, and builds the file only when the
// share sheet asks for it, so opening About never walks the whole history.
//
// The file is RFC 4180 CSV with CRLF line endings and a UTF-8 byte-order
// mark, so Excel on Windows shows accented bean names and the degree sign
// correctly. One row per shot, oldest first. Photos are not exported.
import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// One shot flattened to plain values, so formatting never touches SwiftData
/// (and never loads a photo).
struct ShotCSVRow: Equatable {
    var date: Date
    var bean: String
    var bagNumber: Int?
    var roaster: String
    var machine: String
    var grinder: String
    var grind: String
    var dose: Double
    var yield: Double
    var waterTempC: Double
    var preInfPressure: Double
    var preInfusion: Double
    var pullPressure: Double
    var pull: Double
    var extraction: String
    var tastingNotes: [String]
    var rating: Int
    var paperFilter: Bool
    var notes: String
}

extension ShotCSVRow {
    init(shot: Shot) {
        self.init(
            date: shot.date,
            bean: shot.bean?.name ?? "",
            bagNumber: shot.bean?.bagNumber,
            roaster: shot.bean?.roaster ?? "",
            machine: shot.machine?.name ?? "",
            grinder: shot.grinder?.name ?? "",
            grind: shot.grindSetting,
            dose: shot.dose,
            yield: shot.yield,
            waterTempC: shot.waterTemp,
            preInfPressure: shot.preInfPressure,
            preInfusion: shot.preInfusion,
            pullPressure: shot.pressure,
            pull: shot.pull,
            extraction: shot.extraction?.rawValue ?? "",
            tastingNotes: shot.tags.map(\.label),
            rating: shot.rating,
            paperFilter: shot.usedPaperFilter,
            notes: shot.notes
        )
    }
}

enum ShotCSV {
    static func header(unit: TemperatureUnit) -> [String] {
        [
            "Date", "Bean", "Bag #", "Roaster", "Machine", "Grinder", "Grind",
            "Dose (g)", "Yield (g)", "Ratio (1:x)", "Water Temp (\(unit.label))",
            "Pre-Infusion Pressure (bar)", "Pre-Infusion Time (s)",
            "Pull Pressure (bar)", "Pull Time (s)",
            "Extraction", "Tasting Notes", "Rating", "Paper Filter", "Notes"
        ]
    }

    /// One shot's cells, in `header` order. Unrated shots (rating 0) and
    /// missing values export as empty cells rather than zeros.
    static func fields(for row: ShotCSVRow, unit: TemperatureUnit) -> [String] {
        [
            dateFormatter.string(from: row.date),
            text(row.bean),
            row.bagNumber.map(String.init) ?? "",
            text(row.roaster),
            text(row.machine),
            text(row.grinder),
            text(row.grind),
            decimal(row.dose, places: 1),
            decimal(row.yield, places: 1),
            row.dose > 0 ? decimal(row.yield / row.dose, places: 2) : "",
            decimal(unit.display(celsius: row.waterTempC), places: 1),
            decimal(row.preInfPressure, places: 1),
            decimal(row.preInfusion, places: 1),
            decimal(row.pullPressure, places: 1),
            decimal(row.pull, places: 1),
            row.extraction,
            text(row.tastingNotes.joined(separator: "; ")),
            row.rating > 0 ? String(row.rating) : "",
            row.paperFilter ? "Yes" : "No",
            text(row.notes)
        ]
    }

    /// The whole file as text: byte-order mark, header, then one line per
    /// shot sorted oldest first, every line ending in CRLF.
    static func document(rows: [ShotCSVRow], unit: TemperatureUnit) -> String {
        let lines = [line(header(unit: unit))]
            + rows.sorted { $0.date < $1.date }.map { line(fields(for: $0, unit: unit)) }
        return "\u{FEFF}" + lines.map { $0 + "\r\n" }.joined()
    }

    static func data(rows: [ShotCSVRow], unit: TemperatureUnit) -> Data {
        Data(document(rows: rows, unit: unit).utf8)
    }

    static func line(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// RFC 4180: a field holding a comma, quote or line break is wrapped in
    /// quotes, with inner quotes doubled.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Free text that starts like a spreadsheet formula (=, +, -, @, tab)
    /// gets a leading apostrophe, so a note such as "-1 step finer" shows as
    /// text instead of becoming #NAME? (and nothing in a note can run as a
    /// formula). Excel hides the apostrophe.
    static func text(_ value: String) -> String {
        guard let first = value.first, "=+-@\t".contains(first) else { return value }
        return "'" + value
    }

    /// e.g. "PullState-Shots-2026-10-30.csv".
    static func fileName(on date: Date) -> String {
        "PullState-Shots-\(fileDateFormatter.string(from: date)).csv"
    }

    private static func decimal(_ value: Double, places: Int) -> String {
        guard value.isFinite else { return "" }
        return String(format: "%.\(places)f", value)
    }

    /// Fixed POSIX/Gregorian pattern so the file reads the same on every
    /// device regardless of region settings; the device's time zone.
    private static let dateFormatter: DateFormatter = posixFormatter("yyyy-MM-dd HH:mm")
    private static let fileDateFormatter: DateFormatter = posixFormatter("yyyy-MM-dd")

    private static func posixFormatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = pattern
        return f
    }
}

/// What the About sheet hands to `ShareLink`. It carries only the container
/// and the temperature unit; the shots are fetched and formatted on the main
/// actor when the share sheet requests the data.
nonisolated struct ShotCSVExport: Transferable, Sendable {
    let container: ModelContainer
    /// `TemperatureUnit.rawValue`, kept as a plain string so this value can
    /// cross into the share sheet's export closure.
    let unitRaw: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            await export.makeData()
        }
        .suggestedFileName { $0.fileName }
    }

    @MainActor
    func makeData() -> Data {
        let unit = TemperatureUnit(rawValue: unitRaw) ?? .celsius
        let shots = (try? container.mainContext.fetch(FetchDescriptor<Shot>())) ?? []
        return ShotCSV.data(rows: shots.map(ShotCSVRow.init(shot:)), unit: unit)
    }
}
