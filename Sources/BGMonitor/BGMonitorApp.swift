import SwiftUI
import AppKit

@main
struct BGMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = AgentListViewModel()

    var body: some Scene {
        MenuBarExtra("BG Monitor", systemImage: "bolt.horizontal.circle") {
            MenuBarContentView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "log-tail", for: String.self) { $label in
            if let label {
                LogTailWindowView(label: label, viewModel: viewModel)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
