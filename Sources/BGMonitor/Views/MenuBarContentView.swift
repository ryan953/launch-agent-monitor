import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @Bindable var viewModel: AgentListViewModel
    @State private var editingItem: LaunchAgentItem?
    @State private var debugItem: LaunchAgentItem?
    @State private var scheduleItem: LaunchAgentItem?

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
                                } onShowDebugInfo: {
                                    debugItem = item
                                } onShowSchedule: {
                                    scheduleItem = item
                                } onToggleRegistration: {
                                    Task {
                                        if item.isRegistered {
                                            await viewModel.unregister(item)
                                        } else {
                                            await viewModel.register(item)
                                        }
                                    }
                                } onToggleRunning: {
                                    Task {
                                        if item.isRunning {
                                            await viewModel.stop(item)
                                        } else {
                                            await viewModel.start(item)
                                        }
                                    }
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
        .frame(width: 480, height: 480)
        .task {
            await viewModel.refresh()
        }
        .sheet(item: $editingItem) { item in
            StatusCheckEditorView(item: item) { config in
                viewModel.setStatusCommand(config, for: item)
            }
        }
        .sheet(item: $debugItem) { item in
            DebugInfoSheetView(item: item)
        }
        .sheet(item: $scheduleItem) { item in
            ScheduleDetailView(item: item)
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: { viewModel.lastActionError != nil },
                set: { isPresented in if !isPresented { viewModel.lastActionError = nil } }
            )
        ) {
            Button("OK") { viewModel.lastActionError = nil }
        } message: {
            Text(viewModel.lastActionError ?? "")
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
