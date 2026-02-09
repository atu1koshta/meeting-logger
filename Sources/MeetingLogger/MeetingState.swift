import Foundation
import Combine

enum MeetingPhase {
    case idle
    case tracking
    case pendingTitle  // Timer stopped, waiting for optional title
}

final class MeetingState: ObservableObject {
    @Published var phase: MeetingPhase = .idle
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var elapsedSeconds: Int = 0
    @Published var todaysEntries: [MeetingEntry] = []
    @Published var meetingTitle: String = ""

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
        case .pendingTitle:
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
        phase = .pendingTitle
    }

    func saveMeeting(title: String) {
        if let start = startTime, let end = endTime {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            try? logger.logMeeting(start: start, end: end, title: trimmed)
        }
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
}
