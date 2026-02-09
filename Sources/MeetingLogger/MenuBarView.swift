import SwiftUI

struct MenuBarView: View {
    @ObservedObject var state: MeetingState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state.phase {
            case .idle:
                idleView
            case .tracking:
                trackingView
            case .pendingTitle:
                titleInputView
            }
        }
        .padding(12)
        .frame(width: 260)
        .onAppear {
            state.refreshTodaysEntries()
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text("No meeting")
                    .font(.headline)
            }

            Divider()

            Button(action: { state.toggle() }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    Text("Start Meeting")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)

            Divider()

            todaysList

            Divider()

            footerButtons
        }
    }

    // MARK: - Tracking

    private var trackingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("Meeting in progress")
                    .font(.headline)
            }

            Text(state.formattedElapsed)
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.red)

            Divider()

            Button(action: { state.toggle() }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    Text("Stop Meeting")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.plain)

            Divider()

            todaysList

            Divider()

            footerButtons
        }
    }

    // MARK: - Title Input

    private var titleInputView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Meeting ended")
                    .font(.headline)
            }

            Text(state.formattedDuration)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            Text("Meeting title")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("e.g. Standup, Sprint Review...", text: $state.meetingTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    state.saveMeeting(title: state.meetingTitle)
                }

            HStack(spacing: 8) {
                Button("Skip") {
                    state.skipTitle()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                Button("Save") {
                    state.saveMeeting(title: state.meetingTitle)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(6)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Today's Meetings

    private var todaysList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Meetings")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if state.todaysEntries.isEmpty {
                Text("No meetings yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(state.todaysEntries) { entry in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("\(entry.startTime) - \(entry.endTime)")
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text("\(entry.durationMinutes) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !entry.title.isEmpty {
                            Text(entry.title)
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 1)
                }

                let totalMinutes = state.todaysEntries.reduce(0) { $0 + $1.durationMinutes }
                HStack {
                    Text("Total")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(totalMinutes) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { CSVLogger.shared.openLogFile() }) {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Open Log File")
                }
            }
            .buttonStyle(.plain)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
        }
    }
}
