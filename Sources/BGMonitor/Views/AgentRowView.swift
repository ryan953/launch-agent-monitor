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
                systemImage: item.isRegistered ? "tray.and.arrow.up.fill" : "tray.and.arrow.down.fill",
                isDisabled: item.label == nil,
                help: item.label == nil
                    ? "Unavailable for unlabeled/invalid plists"
                    : item.isRegistered
                        ? "Unregister from launchd (launchctl bootout) — stops it and removes it from launchd until reloaded"
                        : "Register with launchd (launchctl bootstrap) — loads this agent so it can run",
                action: onToggleRegistration
            )

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
                systemImage: "calendar",
                isDisabled: false,
                help: "View this agent's full schedule details",
                action: onShowSchedule
            )

            actionButton(
                systemImage: "doc.text",
                isDisabled: !hasLogPath || item.label == nil,
                help: hasLogPath ? "View log" : "No StandardOutPath/StandardErrorPath configured for this agent",
                action: {
                    if let label = item.label {
                        openWindow(id: "log-tail", value: label)
                    }
                }
            )

            actionButton(
                systemImage: "stethoscope",
                isDisabled: item.label == nil,
                help: item.label == nil ? "Unavailable for unlabeled/invalid plists" : "Show launchctl print/blame output",
                action: onShowDebugInfo
            )
        }
        .padding(.vertical, 4)
    }

    /// Every row renders the same fixed set of action buttons — only
    /// `.disabled`, never conditionally omitted — so icons line up across
    /// every row regardless of that row's state.
    private func actionButton(systemImage: String, isDisabled: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
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

    private var registrationBadge: some View {
        Label(item.isRegistered ? "Registered" : "Not Registered", systemImage: item.isRegistered ? "checkmark.circle.fill" : "circle.dashed")
            .labelStyle(.iconOnly)
            .foregroundStyle(item.isRegistered ? .green : .secondary)
            .help(item.isRegistered ? "Registered with launchd" : "Not registered with launchd")
    }

    private var runningBadge: some View {
        Label(item.isRunning ? "Running" : "Not Running", systemImage: item.isRunning ? "play.circle.fill" : "pause.circle")
            .labelStyle(.iconOnly)
            .foregroundStyle(item.isRunning ? .blue : .secondary)
            .help(item.isRunning ? "Running (pid \(item.pid.map(String.init) ?? "?"))" : "Not running")
    }

    private var scheduleBadge: some View {
        Label(item.schedule.summary, systemImage: item.schedule.systemImage)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .help("Schedule: \(item.schedule.summary)")
    }
}
