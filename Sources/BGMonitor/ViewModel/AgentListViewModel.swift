import Foundation
import Observation

@Observable
@MainActor
final class AgentListViewModel {
    var items: [LaunchAgentItem] = []
    var groupingKey: GroupingKey = .runningState
    var isRefreshing: Bool = false
    var lastActionError: String?

    private let configStore = ConfigStore()
    private let statusScheduler: StatusCheckScheduler
    private var directoryWatcher: DirectoryWatcher?
    private var autoRefreshTask: Task<Void, Never>?

    init() {
        statusScheduler = StatusCheckScheduler(configStore: configStore)
        autoRefreshTask = nil
        directoryWatcher = nil

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(4))
            }
        }
        directoryWatcher = DirectoryWatcher(directories: Domain.allCases.map(\.directoryURL)) { [weak self] in
            Task { @MainActor in await self?.refresh() }
        }
        statusScheduler.setOnUpdate { [weak self] label, output, failed, date in
            Task { @MainActor in
                self?.statusOutputDidUpdate(label: label, output: output, failed: failed, date: date)
            }
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

        let configs = configStore.allConfigs()
        var withConfig = refreshed
        for index in withConfig.indices {
            if let label = withConfig[index].label {
                withConfig[index].statusCommand = configs[label]
            }
        }

        items = withConfig
        statusScheduler.reconcile(with: withConfig)
    }

    func setStatusCommand(_ config: StatusCheckConfig?, for item: LaunchAgentItem) {
        guard let label = item.label else { return }
        configStore.setConfig(config, forLabel: label)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].statusCommand = config
        }
        statusScheduler.reconcile(with: items)
    }

    func statusOutputDidUpdate(label: String, output: String?, failed: Bool, date: Date) {
        guard let index = items.firstIndex(where: { $0.label == label }) else { return }
        items[index].statusCommand?.lastOutput = output
        items[index].statusCommand?.lastRunDate = date
        items[index].statusCommand?.lastRunFailed = failed
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

    private func performAction(name: String, _ action: @escaping @Sendable () -> Result<Void, LaunchctlActionError>) async {
        let result = await Task.detached(priority: .userInitiated, operation: action).value
        if case .failure(let error) = result {
            lastActionError = "\(name) failed: \(error.localizedDescription)"
        }
        await refresh()
    }
}
