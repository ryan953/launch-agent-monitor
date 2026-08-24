import SwiftUI

struct AgentRowView: View {
    let item: LaunchAgentItem
    var onEditStatusCommand: () -> Void
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

                if let status = item.statusCommand, let output = status.lastOutput {
                    Text(output)
                        .font(.caption)
                        .foregroundStyle(status.lastRunFailed ? .red : .secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                onToggleRegistration()
            } label: {
                Image(systemName: item.isRegistered ? "tray.and.arrow.up.fill" : "tray.and.arrow.down.fill")
            }
            .buttonStyle(.borderless)
            .disabled(item.label == nil)
            .help(
                item.label == nil
                    ? "Unavailable for unlabeled/invalid plists"
                    : item.isRegistered
                        ? "Unregister from launchd (launchctl bootout) — stops it and removes it from launchd until reloaded"
                        : "Register with launchd (launchctl bootstrap) — loads this agent so it can run"
            )

            if item.isRegistered {
                Button {
                    onToggleRunning()
                } label: {
                    Image(systemName: item.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help(
                    item.isRunning
                        ? "Stop now (launchctl kill SIGTERM) — the agent may restart on its own if it's configured to KeepAlive"
                        : "Start now (launchctl kickstart) — runs it immediately without waiting for its schedule"
                )
            }

            Button {
                onShowSchedule()
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.borderless)
            .help("View this agent's full schedule details")

            if hasLogPath, let label = item.label {
                Button {
                    openWindow(id: "log-tail", value: label)
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(.borderless)
                .help("View log")
            }

            Button {
                onEditStatusCommand()
            } label: {
                Image(systemName: item.statusCommand == nil ? "plus.circle" : "gearshape.fill")
            }
            .buttonStyle(.borderless)
            .disabled(item.label == nil)
            .help(item.label == nil ? "Unavailable for unlabeled/invalid plists" : "Set a periodic status command")

            Button {
                onShowDebugInfo()
            } label: {
                Image(systemName: "stethoscope")
            }
            .buttonStyle(.borderless)
            .disabled(item.label == nil)
            .help(item.label == nil ? "Unavailable for unlabeled/invalid plists" : "Show launchctl print/blame output")
        }
        .padding(.vertical, 4)
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
