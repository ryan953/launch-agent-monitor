import AppKit
import SwiftUI

struct AgentRowView: View {
    let item: LaunchAgentItem
    var onShowDebugInfo: () -> Void
    var onShowSchedule: () -> Void
    var onToggleRegistration: () -> Void
    var onToggleRunning: () -> Void

    @Environment(\.openWindow) private var openWindow

    private var hasLogPath: Bool {
        item.standardOutPath != nil || item.standardErrorPath != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    domainBadge
                    registrationBadge
                    runningBadge
                    scheduleBadge
                }

                if let parseError = item.parseError {
                    Text(parseError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            actionButton(
                systemImage: item.isRunning ? "stop.fill" : "play.fill",
                isDisabled: item.label == nil || !item.isRegistered,
                help: item.label == nil || !item.isRegistered
                    ? "Register this agent first before it can be started"
                    : item.isRunning
                        ? "Stop now (launchctl kill SIGTERM) — the agent may restart on its own if it's configured to KeepAlive"
                        : "Start now (launchctl kickstart) — runs it immediately without waiting for its schedule",
                action: onToggleRunning
            )

            actionButton(
                systemImage: "doc.text",
                isDisabled: item.label == nil,
                help: hasLogPath ? "View log and plist" : "No log configured — view plist",
                action: {
                    if let label = item.label {
                        openWindow(id: "log-tail", value: label)
                        // openWindow brings an already-open window to the
                        // front of the app, but won't raise the app itself
                        // above other apps — without this, clicking the
                        // button while the log window sits behind another
                        // app's window does nothing visible.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            )

            actionButton(
                systemImage: "stethoscope",
                isDisabled: item.label == nil,
                help: item.label == nil
                    ? "Unavailable for unlabeled/invalid plists" : "Show launchctl print/blame output",
                action: onShowDebugInfo
            )
        }
        .padding(.vertical, 4)
    }

    /// Every row renders the same fixed set of action buttons — only
    /// `.disabled`, never conditionally omitted — so icons line up across
    /// every row regardless of that row's state.
    private func actionButton(systemImage: String, isDisabled: Bool, help: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.hoverable)
        .disabled(isDisabled)
        .help(help)
    }

    private var domainBadge: some View {
        Text(item.domain.displayName)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }

    /// Doubles as the register/unregister action — no separate button for
    /// it on the trailing side, to avoid showing the same state twice.
    private var registrationBadge: some View {
        Button(action: onToggleRegistration) {
            Label(
                item.isRegistered ? "Registered" : "Not Registered",
                systemImage: item.isRegistered ? "checkmark.circle.fill" : "circle.dashed"
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(item.isRegistered ? .green : .secondary)
        }
        .buttonStyle(HoverableButtonStyle(cornerRadius: 4, padding: 2))
        .disabled(item.label == nil)
        .help(
            item.label == nil
                ? "Unavailable for unlabeled/invalid plists"
                : item.isRegistered
                    ? "Registered with launchd — click to unregister (launchctl bootout)"
                    : "Not registered with launchd — click to register (launchctl bootstrap)"
        )
    }

    private var runningBadge: some View {
        Label(
            item.isRunning ? "Running" : "Not Running",
            systemImage: item.isRunning ? "play.circle.fill" : "pause.circle"
        )
        .labelStyle(.iconOnly)
        .foregroundStyle(item.isRunning ? .blue : .secondary)
        .help(item.isRunning ? "Running (pid \(item.pid.map(String.init) ?? "?"))" : "Not running")
    }

    /// Doubles as the view-schedule action — no separate button for it on
    /// the trailing side, to avoid showing the same state twice.
    private var scheduleBadge: some View {
        Button(action: onShowSchedule) {
            Label(item.schedule.summary, systemImage: item.schedule.systemImage)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(HoverableButtonStyle(cornerRadius: 4, padding: 2))
        .help("Schedule: \(item.schedule.summary) — click to view full details")
    }
}
