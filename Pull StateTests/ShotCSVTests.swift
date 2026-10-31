import Foundation
import Testing
@testable import Pull_State

/// Covers the CSV export format (DESIGN.md §3.5 / §10.3).
struct ShotCSVTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let comps = DateComponents(year: year, month: month, day: day, hour: 7, minute: 45)
        return try #require(calendar.date(from: comps))
    }

    private func sample(on date: Date) -> ShotCSVRow {
        ShotCSVRow(
            date: date, bean: "Black Gold", bagNumber: 3, roaster: "Onyx",
            machine: "Flair 58", grinder: "J-Ultra", grind: "22",
            dose: 18, yield: 36, waterTempC: 93.5, preInfPressure: 1, preInfusion: 8,
            pullPressure: 9, pull: 27.5, extraction: "Perfect",
            tastingNotes: ["Chocolate", "Caramel"], rating: 4, paperFilter: true,
            notes: "Sweet, round"
        )
    }

    @Test func escapesOnlyWhenNeeded() {
        #expect(ShotCSV.escape("plain") == "plain")
        #expect(ShotCSV.escape("a,b") == "\"a,b\"")
        #expect(ShotCSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(ShotCSV.escape("two\nlines") == "\"two\nlines\"")
        #expect(ShotCSV.escape("two\r\nlines") == "\"two\r\nlines\"")
    }

    @Test func formulaLikeTextIsNeutralised() {
        #expect(ShotCSV.text("=SUM(A1:A2)") == "'=SUM(A1:A2)")
        #expect(ShotCSV.text("-1 step finer") == "'-1 step finer")
        #expect(ShotCSV.text("+2") == "'+2")
        #expect(ShotCSV.text("@home") == "'@home")
        #expect(ShotCSV.text("Fine") == "Fine")
        #expect(ShotCSV.text("") == "")
    }

    @Test func headerMatchesFieldsAndUnit() throws {
        let row = sample(on: try date(2026, 10, 30))
        #expect(ShotCSV.header(unit: .celsius).count == ShotCSV.fields(for: row, unit: .celsius).count)
        #expect(ShotCSV.header(unit: .celsius).contains("Water Temp (°C)"))
        #expect(ShotCSV.header(unit: .fahrenheit).contains("Water Temp (°F)"))
    }

    @Test func formatsEveryField() throws {
        let fields = ShotCSV.fields(for: sample(on: try date(2026, 10, 30)), unit: .celsius)
        #expect(fields == [
            "2026-10-30 07:45", "Black Gold", "3", "Onyx", "Flair 58", "J-Ultra", "22",
            "18.0", "36.0", "2.00", "93.5", "1.0", "8.0", "9.0", "27.5",
            "Perfect", "Chocolate; Caramel", "4", "Yes", "Sweet, round"
        ])
    }

    @Test func missingValuesExportAsEmptyCells() throws {
        var row = sample(on: try date(2026, 10, 30))
        row.bean = ""
        row.bagNumber = nil
        row.machine = ""
        row.grinder = ""
        row.dose = 0
        row.extraction = ""
        row.tastingNotes = []
        row.rating = 0
        row.paperFilter = false
        let f = ShotCSV.fields(for: row, unit: .celsius)
        #expect(f[1].isEmpty)
        #expect(f[2].isEmpty)
        #expect(f[4].isEmpty)
        #expect(f[5].isEmpty)
        #expect(f[9].isEmpty)   // ratio needs a dose
        #expect(f[15].isEmpty)
        #expect(f[16].isEmpty)
        #expect(f[17].isEmpty)  // unrated, not "0"
        #expect(f[18] == "No")
    }

    @Test func fahrenheitConvertsWaterTemp() throws {
        var row = sample(on: try date(2026, 10, 30))
        row.waterTempC = 100
        #expect(ShotCSV.fields(for: row, unit: .fahrenheit)[10] == "212.0")
    }

    @Test func documentIsChronologicalWithBOMAndCRLF() throws {
        let older = sample(on: try date(2026, 10, 1))
        let newer = sample(on: try date(2026, 10, 2))
        let doc = ShotCSV.document(rows: [newer, older], unit: .celsius)
        #expect(doc.hasPrefix("\u{FEFF}Date,Bean,Bag #,"))
        let lines = String(doc.dropFirst()).components(separatedBy: "\r\n")
        #expect(lines.count == 4) // header, two shots, empty after the final CRLF
        #expect(lines[1].hasPrefix("2026-10-01 07:45,"))
        #expect(lines[2].hasPrefix("2026-10-02 07:45,"))
        #expect(lines[1].hasSuffix(",\"Sweet, round\""))
        #expect(lines[3].isEmpty)
    }

    @Test func dataStartsWithUTF8ByteOrderMark() {
        let data = ShotCSV.data(rows: [], unit: .celsius)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    @Test func fileNameCarriesTheDate() throws {
        #expect(ShotCSV.fileName(on: try date(2026, 10, 30)) == "PullState-Shots-2026-10-30.csv")
    }
}
