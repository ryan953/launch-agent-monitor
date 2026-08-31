import AppKit
import SwiftUI

/// Raw `launchctl print` / `launchctl blame` output for one agent, shown
/// verbatim — useful for diagnosing an agent that's registered but won't
/// start, or confirming it isn't loaded at all.
struct DebugInfoSheetView: View {
    let item: LaunchAgentItem

    @Environment(\.dismiss) private var dismiss
    @State private var printOutput: String = "Loading…"
    @State private var blameOutput: String = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Debug Info")
                    .font(.headline)
                Spacer()
                Button("Copy All") {
                    copyToPasteboard()
                }
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Text(item.displayName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "launchctl print", text: printOutput)
                    section(title: "launchctl blame", text: blameOutput)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 520, height: 420)
        .task {
            guard let label = item.label else {
                printOutput = "No Label in this plist — launchctl cannot query it."
                blameOutput = printOutput
                return
            }
            async let printResult = Task.detached { LaunchctlDebugInfo.rawPrint(label: label) }.value
            async let blameResult = Task.detached { LaunchctlDebugInfo.rawBlame(label: label) }.value
            printOutput = await printResult
            blameOutput = await blameResult
        }
    }

    private func section(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func copyToPasteboard() {
        let combined = "== launchctl print ==\n\(printOutput)\n\n== launchctl blame ==\n\(blameOutput)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(combined, forType: .string)
    }
}
