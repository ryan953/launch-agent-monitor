import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @Bindable var viewModel: AgentListViewModel
    @State private var editingItem: LaunchAgentItem?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if viewModel.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.groupedSections, id: \.key) { section in
                        Section(section.key) {
                            ForEach(section.items) { item in
                                AgentRowView(item: item) {
                                    editingItem = item
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            footer
        }
        .frame(width: 420, height: 480)
        .task {
            await viewModel.refresh()
        }
        .sheet(item: $editingItem) { item in
            StatusCheckEditorView(item: item) { config in
                viewModel.setStatusCommand(config, for: item)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("LaunchAgents")
                .font(.headline)
            Spacer()
            Picker("Group by", selection: $viewModel.groupingKey) {
                ForEach(GroupingKey.allCases) { key in
                    Text(key.displayName).tag(key)
                }
            }
            .labelsHidden()
            .frame(width: 170)
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(viewModel.isRefreshing ? "Scanning…" : "No LaunchAgents found")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.items.count) agents")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
    }
}
