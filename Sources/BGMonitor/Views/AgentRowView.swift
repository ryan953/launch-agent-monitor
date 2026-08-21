import SwiftUI

struct AgentRowView: View {
    let item: LaunchAgentItem
    var onEditStatusCommand: () -> Void

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
                onEditStatusCommand()
            } label: {
                Image(systemName: item.statusCommand == nil ? "plus.circle" : "gearshape.fill")
            }
            .buttonStyle(.borderless)
            .disabled(item.label == nil)
            .help(item.label == nil ? "Unavailable for unlabeled/invalid plists" : "Set a periodic status command")
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
}
