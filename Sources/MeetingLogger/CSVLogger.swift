import Foundation
import AppKit

struct MeetingEntry: Identifiable {
    let id = UUID()
    let date: String
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let title: String
}

final class CSVLogger {
    static let shared = CSVLogger()

    private let directoryURL: URL
    private let fileURL: URL
    private let header = "date,start_time,end_time,duration_hours,duration_minutes,title"

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        directoryURL = home.appendingPathComponent(".meeting-logger")
        fileURL = directoryURL.appendingPathComponent("meetings.csv")
    }

    private func ensureFileExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: fileURL.path) {
            let data = (header + "\n").data(using: .utf8)!
            fm.createFile(atPath: fileURL.path, contents: data)
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    func logMeeting(start: Date, end: Date, title: String) throws {
        try ensureFileExists()

        let dateStr = dateFormatter.string(from: start)
        let startStr = timeFormatter.string(from: start)
        let endStr = timeFormatter.string(from: end)
        let durationMinutes = Int(end.timeIntervalSince(start) / 60)
        let durationHours = String(format: "%.2f", end.timeIntervalSince(start) / 3600)
        let safeTitle = csvEscape(title)

        let newRow = "\(dateStr),\(startStr),\(endStr),\(durationHours),\(durationMinutes),\(safeTitle)"

        // Prepend after header so most recent entry is at the top
        let existing = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = existing.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var output = [header, newRow]
        for line in lines where line != header {
            output.append(line)
        }
        output.append("") // trailing newline

        try output.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func todaysEntries() -> [MeetingEntry] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let today = dateFormatter.string(from: Date())
        var entries: [MeetingEntry] = []

        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != header else { continue }

            let cols = parseCSVRow(trimmed)
            guard cols.count >= 5, cols[0] == today else { continue }

            entries.append(MeetingEntry(
                date: cols[0],
                startTime: cols[1],
                endTime: cols[2],
                durationMinutes: Int(cols[4]) ?? 0,
                title: cols.count > 5 ? cols[5] : ""
            ))
        }
        return entries
    }

    /// Parse a CSV row respecting quoted fields
    private func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if inQuotes {
                if char == "\"" {
                    // Check for escaped quote (next char is also quote)
                    inQuotes = false
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
        }
        fields.append(current)
        return fields
    }

    func openLogFile() {
        NSWorkspace.shared.open(fileURL)
    }
}
