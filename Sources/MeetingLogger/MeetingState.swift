import Foundation
import Combine

enum MeetingPhase {
    case idle
    case tracking
    case pendingTitle  // Timer stopped, waiting for optional title
    case manualEntry
    case editingEntry
}

final class MeetingState: ObservableObject {
    @Published var phase: MeetingPhase = .idle
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var elapsedSeconds: Int = 0
    @Published var todaysEntries: [MeetingEntry] = []
    @Published var meetingTitle: String = ""
    @Published var manualDate: Date = Date()
    @Published var manualStartTime: Date = Date()
    @Published var manualEndTime: Date = Date()
    @Published var editingEntry: MeetingEntry?

    private var timer: Timer?
    private let logger = CSVLogger.shared

    var isTracking: Bool { phase == .tracking }

    init() {
        refreshTodaysEntries()
    }

    func toggle() {
        switch phase {
        case .idle:
            startMeeting()
        case .tracking:
            stopMeeting()
        case .pendingTitle, .manualEntry, .editingEntry:
            break
        }
    }

    private func startMeeting() {
        startTime = Date()
        endTime = nil
        meetingTitle = ""
        phase = .tracking
        elapsedSeconds = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    private func stopMeeting() {
        timer?.invalidate()
        timer = nil
        endTime = Date()
        manualStartTime = startTime ?? Date()
        manualEndTime = endTime ?? Date()
        phase = .pendingTitle
    }

    func saveMeeting(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try? logger.logMeeting(start: manualStartTime, end: manualEndTime, title: trimmed)
        resetToIdle()
    }

    func skipTitle() {
        saveMeeting(title: "")
    }

    private func resetToIdle() {
        phase = .idle
        startTime = nil
        endTime = nil
        elapsedSeconds = 0
        meetingTitle = ""
        refreshTodaysEntries()
    }

    func refreshTodaysEntries() {
        todaysEntries = logger.todaysEntries()
    }

    var formattedElapsed: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDuration: String {
        let minutes = elapsedSeconds / 60
        if minutes < 1 { return "< 1 min" }
        if minutes == 1 { return "1 min" }
        let hours = minutes / 60
        let rem = minutes % 60
        if hours > 0 {
            return rem > 0 ? "\(hours)h \(rem)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    var manualDurationFormatted: String {
        let seconds = manualEndTime.timeIntervalSince(manualStartTime)
        let minutes = max(0, Int(seconds / 60))
        if minutes < 1 { return "< 1 min" }
        if minutes == 1 { return "1 min" }
        let hours = minutes / 60
        let rem = minutes % 60
        if hours > 0 {
            return rem > 0 ? "\(hours)h \(rem)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    func startManualEntry() {
        let now = Date()
        manualDate = now
        manualStartTime = now
        manualEndTime = now
        meetingTitle = ""
        editingEntry = nil
        phase = .manualEntry
    }

    func saveManualEntry() {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: manualDate)
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: manualStartTime)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: manualEndTime)

        var startFull = DateComponents()
        startFull.year = dateComponents.year
        startFull.month = dateComponents.month
        startFull.day = dateComponents.day
        startFull.hour = startComponents.hour
        startFull.minute = startComponents.minute
        startFull.second = startComponents.second

        var endFull = DateComponents()
        endFull.year = dateComponents.year
        endFull.month = dateComponents.month
        endFull.day = dateComponents.day
        endFull.hour = endComponents.hour
        endFull.minute = endComponents.minute
        endFull.second = endComponents.second

        if let start = calendar.date(from: startFull),
           let end = calendar.date(from: endFull) {
            let trimmed = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try? logger.logMeeting(start: start, end: end, title: trimmed)
        }
        resetToIdle()
    }

    func startEditing(_ entry: MeetingEntry) {
        editingEntry = entry

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        if let date = dateFormatter.date(from: entry.date) {
            manualDate = date
        } else {
            manualDate = Date()
        }

        // Build full dates for the time pickers using today as base
        let today = Date()
        if let startTime = timeFormatter.date(from: entry.startTime) {
            let comps = calendar.dateComponents([.hour, .minute, .second], from: startTime)
            manualStartTime = calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: today) ?? today
        }
        if let endTime = timeFormatter.date(from: entry.endTime) {
            let comps = calendar.dateComponents([.hour, .minute, .second], from: endTime)
            manualEndTime = calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: today) ?? today
        }

        meetingTitle = entry.title
        phase = .editingEntry
    }

    func saveEdit() {
        guard let original = editingEntry else { return }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: manualDate)
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: manualStartTime)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: manualEndTime)

        var startFull = DateComponents()
        startFull.year = dateComponents.year
        startFull.month = dateComponents.month
        startFull.day = dateComponents.day
        startFull.hour = startComponents.hour
        startFull.minute = startComponents.minute
        startFull.second = startComponents.second

        var endFull = DateComponents()
        endFull.year = dateComponents.year
        endFull.month = dateComponents.month
        endFull.day = dateComponents.day
        endFull.hour = endComponents.hour
        endFull.minute = endComponents.minute
        endFull.second = endComponents.second

        if let start = calendar.date(from: startFull),
           let end = calendar.date(from: endFull) {
            let trimmed = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            try? logger.updateMeeting(original: original, newStart: start, newEnd: end, newTitle: trimmed)
        }
        resetToIdle()
    }

    func cancelEntry() {
        resetToIdle()
    }
}
