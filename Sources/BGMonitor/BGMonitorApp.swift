import AppKit
import SwiftUI

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

    private static let panelWidth: CGFloat = 480
    private static let minPanelHeight: CGFloat = 240

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        setUpPanel()
        observeListChanges()
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
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.minPanelHeight),
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
        updatePanelFrame(animate: false)
        panel.makeKeyAndOrderFront(nil)
        startMonitoringOutsideClicks()
    }

    private func closePanel() {
        panel.orderOut(nil)
        stopMonitoringOutsideClicks()
    }

    /// Re-registers itself after every fire, since `withObservationTracking`
    /// only fires once per registration — so the panel keeps resizing to
    /// match the list for as long as the app runs, not just the first time
    /// the item count changes.
    private func observeListChanges() {
        withObservationTracking {
            _ = viewModel.items.count
            _ = viewModel.groupingKey
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.panel.isVisible {
                    self.updatePanelFrame(animate: true)
                }
                self.observeListChanges()
            }
        }
    }

    /// Sizes the panel to fit the current list (more items/sections = a
    /// taller panel), capped to the screen's visible height, and keeps it
    /// anchored just below the status item as it grows downward.
    private func updatePanelFrame(animate: Bool) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)

        var frame = panel.frame
        frame.size.width = Self.panelWidth
        frame.size.height = idealPanelHeight()
        frame.origin.x = buttonFrame.midX - frame.width / 2
        frame.origin.y = buttonFrame.minY - frame.height - 4
        panel.setFrame(frame, display: true, animate: animate)
    }

    private func idealPanelHeight() -> CGFloat {
        let chrome: CGFloat = 100  // header + footer + dividers/padding
        let rowHeight: CGFloat = 52
        let sectionHeaderHeight: CGFloat = 24

        let natural =
            chrome
            + sectionHeaderHeight * CGFloat(viewModel.groupedSections.count)
            + rowHeight * CGFloat(viewModel.items.count)

        let screenMax = (NSScreen.main?.visibleFrame.height ?? 900) - 40
        return min(max(natural, Self.minPanelHeight), screenMax)
    }

    private func startMonitoringOutsideClicks() {
        // A global monitor only fires for events delivered to OTHER
        // applications — clicks inside any of our own windows (the panel,
        // a log-tail window, a sheet) never reach it, so the panel stays
        // open through all of those.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
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

/// A borderless, non-activating panel that can still become key so
/// controls inside it work normally.
final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
