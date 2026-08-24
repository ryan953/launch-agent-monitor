import SwiftUI
import AppKit

@main
struct BGMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "log-tail", for: String.self) { $label in
            if let label {
                LogTailWindowView(label: label, viewModel: appDelegate.viewModel)
            }
        }
    }
}

/// Owns a manually-managed status item + panel instead of `MenuBarExtra`.
/// `MenuBarExtra(.window)` closes itself whenever *any* window loses key
/// status — including one of this app's own windows (e.g. a log-tail
/// window) becoming key — which reads as the menu randomly vanishing while
/// you're still using the app. This panel only closes on an explicit toggle
/// or a genuine click outside the app (via a global event monitor, which by
/// definition never fires for clicks inside our own windows).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = AgentListViewModel()

    private var statusItem: NSStatusItem!
    private var panel: MenuPanel!
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        setUpPanel()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "BG Monitor")
            button.target = self
            button.action = #selector(statusItemClicked)
        }
        statusItem = item
    }

    private func setUpPanel() {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let contentView = MenuBarContentView(viewModel: viewModel)
            .background(.regularMaterial, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))

        let newPanel = MenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.hidesOnDeactivate = false
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.contentViewController = NSHostingController(rootView: contentView)
        panel = newPanel
    }

    @objc private func statusItemClicked() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        startMonitoringOutsideClicks()
    }

    private func closePanel() {
        panel.orderOut(nil)
        stopMonitoringOutsideClicks()
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        var frame = panel.frame
        frame.origin.x = buttonFrame.midX - frame.width / 2
        frame.origin.y = buttonFrame.minY - frame.height - 4
        panel.setFrame(frame, display: false)
    }

    private func startMonitoringOutsideClicks() {
        // A global monitor only fires for events delivered to OTHER
        // applications — clicks inside any of our own windows (the panel,
        // a log-tail window, a sheet) never reach it, so the panel stays
        // open through all of those.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }
}

/// A borderless, non-activating panel that can still become key so text
/// fields inside it (e.g. the status-command editor) work normally.
final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
