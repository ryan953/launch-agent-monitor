import SwiftUI

struct StatusCheckEditorView: View {
    let item: LaunchAgentItem
    var onSave: (StatusCheckConfig?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var command: String
    @State private var intervalSeconds: Double

    init(item: LaunchAgentItem, onSave: @escaping (StatusCheckConfig?) -> Void) {
        self.item = item
        self.onSave = onSave
        _command = State(initialValue: item.statusCommand?.command ?? "")
        _intervalSeconds = State(initialValue: item.statusCommand?.intervalSeconds ?? 30)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status Command")
                .font(.headline)
            Text(item.displayName)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Runs while this agent is running. Its stdout is shown as a status message on the row.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. cat /tmp/progress.txt", text: $command, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3)

            HStack {
                Text("Every")
                Stepper(value: $intervalSeconds, in: 5...3600, step: 5) {
                    Text("\(Int(intervalSeconds))s")
                        .monospacedDigit()
                }
            }

            HStack {
                if item.statusCommand != nil {
                    Button("Remove", role: .destructive) {
                        onSave(nil)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(StatusCheckConfig(command: trimmed, intervalSeconds: intervalSeconds))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
