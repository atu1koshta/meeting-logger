import SwiftUI
import AppKit
import Combine

@main
struct MeetingLoggerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var state = MeetingState()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateIcon()

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 350)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView(state: state))

        // Observe phase changes to update icon
        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        // Keep popover open during title input, manual entry, and editing
        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                switch phase {
                case .pendingTitle, .manualEntry, .editingEntry:
                    self?.popover.behavior = .applicationDefined
                default:
                    self?.popover.behavior = .transient
                }
            }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        if let button = statusItem.button {
            if state.phase == .tracking {
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
                let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Meeting in progress")?
                    .withSymbolConfiguration(config)
                image?.isTemplate = false
                button.image = image
            } else {
                let image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Meeting Logger")
                image?.isTemplate = true
                button.image = image
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            state.refreshTodaysEntries()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Ensure popover gets focus
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
