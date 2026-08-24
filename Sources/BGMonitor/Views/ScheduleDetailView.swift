import SwiftUI

/// Full schedule detail for one agent — the badge in the row only shows a
/// short summary; this expands it into every trigger configured in the
/// plist.
struct ScheduleDetailView: View {
    let item: LaunchAgentItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Text(item.displayName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    row(label: "At load", value: item.runAtLoad ? "Yes" : "No")

                    if let interval = item.startInterval {
                        row(label: "Interval", value: "Every \(Int(interval))s")
                    }

                    if !item.calendarRules.isEmpty {
                        section(title: "Calendar rules") {
                            ForEach(Array(item.calendarRules.enumerated()), id: \.offset) { _, rule in
                                Text("• \(rule.summary)")
                            }
                        }
                    }

                    if let keepAlive = item.keepAliveDescription {
                        row(label: "Keep alive", value: keepAlive)
                    }

                    if !item.watchPaths.isEmpty {
                        section(title: "Watch paths") {
                            ForEach(item.watchPaths, id: \.self) { path in
                                Text("• \(path)")
                            }
                        }
                    }

                    if !item.queueDirectories.isEmpty {
                        section(title: "Queue directories") {
                            ForEach(item.queueDirectories, id: \.self) { path in
                                Text("• \(path)")
                            }
                        }
                    }

                    if item.schedule.summary == AgentSchedule.manual.summary {
                        Text("No load-time, interval, calendar, or on-demand trigger is configured — this agent only runs when started manually.")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(width: 420, height: 360)
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
                .font(.callout)
            content()
                .font(.system(.caption, design: .monospaced))
        }
    }
}
