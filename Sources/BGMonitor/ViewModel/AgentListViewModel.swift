import Foundation
import Observation

@Observable
@MainActor
final class AgentListViewModel {
    var items: [LaunchAgentItem] = []
    var groupingKey: GroupingKey = .runningState
    var isRefreshing: Bool = false
    var lastActionError: String?

    private var directoryWatcher: DirectoryWatcher?
    private var autoRefreshTask: Task<Void, Never>?

    init() {
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(4))
            }
        }
        directoryWatcher = DirectoryWatcher(directories: Domain.allCases.map(\.directoryURL)) { [weak self] in
            Task { @MainActor in await self?.refresh() }
        }
    }

    var groupedSections: [(key: String, items: [LaunchAgentItem])] {
        let grouped = Dictionary(grouping: items) { groupingKey.sectionKey(for: $0) }
        return grouped.keys.sorted().map { key in
            (key, grouped[key]!.sorted { $0.displayName < $1.displayName })
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let refreshed = await Task.detached(priority: .userInitiated) {
            var scanned = PlistScanner.scan()
            for index in scanned.indices {
                guard let label = scanned[index].label else { continue }
                let state = LaunchctlStateReader.state(forLabel: label)
                scanned[index].isRegistered = state.isRegistered
                scanned[index].isRunning = state.isRunning
                scanned[index].pid = state.pid
                scanned[index].lastExitCode = state.lastExitCode
            }
            return scanned
        }.value

        items = refreshed
    }

    func register(_ item: LaunchAgentItem) async {
        let plistURL = item.plistURL
        await performAction(name: "Register") { LaunchctlActions.register(plistURL: plistURL) }
    }

    func unregister(_ item: LaunchAgentItem) async {
        guard let label = item.label else { return }
        await performAction(name: "Unregister") { LaunchctlActions.unregister(label: label) }
    }

    func start(_ item: LaunchAgentItem) async {
        guard let label = item.label else { return }
        await performAction(name: "Start") { LaunchctlActions.start(label: label) }
    }

    func stop(_ item: LaunchAgentItem) async {
        guard let label = item.label else { return }
        await performAction(name: "Stop") { LaunchctlActions.stop(label: label) }
    }

    private func performAction(name: String, _ action: @escaping @Sendable () -> Result<Void, LaunchctlActionError>)
        async
    {
        let result = await Task.detached(priority: .userInitiated, operation: action).value
        if case .failure(let error) = result {
            lastActionError = "\(name) failed: \(error.localizedDescription)"
        }
        await refresh()
    }
}
