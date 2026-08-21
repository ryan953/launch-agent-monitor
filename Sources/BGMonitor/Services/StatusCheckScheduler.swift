import Foundation

/// Keeps one long-lived loop per agent that has a `StatusCheckConfig` and is
/// currently running, executing its command on the configured interval.
/// Loops are started/stopped by comparing against the latest item list each
/// time `reconcile(with:)` is called (on every refresh).
final class StatusCheckScheduler: Sendable {
    private let box: TaskBox

    init(configStore: ConfigStore) {
        box = TaskBox(configStore: configStore)
    }

    func setOnUpdate(_ handler: @escaping @Sendable (String, String?, Bool, Date) -> Void) {
        Task { await box.setOnUpdate(handler) }
    }

    func reconcile(with items: [LaunchAgentItem]) {
        Task { await box.reconcile(items: items) }
    }
}

private actor TaskBox {
    private let configStore: ConfigStore
    private var onUpdate: (@Sendable (String, String?, Bool, Date) -> Void)?
    private var tasks: [String: Task<Void, Never>] = [:]

    func setOnUpdate(_ handler: @escaping @Sendable (String, String?, Bool, Date) -> Void) {
        onUpdate = handler
    }

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func reconcile(items: [LaunchAgentItem]) {
        var desiredLabels: Set<String> = []

        for item in items {
            guard let label = item.label, item.statusCommand != nil, item.isRunning else { continue }
            desiredLabels.insert(label)
            if tasks[label] == nil {
                tasks[label] = makeTask(label: label)
            }
        }

        for (label, task) in tasks where !desiredLabels.contains(label) {
            task.cancel()
            tasks.removeValue(forKey: label)
        }
    }

    private func makeTask(label: String) -> Task<Void, Never> {
        Task { [configStore] in
            while !Task.isCancelled {
                guard let config = configStore.allConfigs()[label] else { break }

                let result = await StatusCheckRunner.run(command: config.command, timeout: 15)
                if Task.isCancelled { break }

                let date = Date()
                switch result {
                case .success(let output):
                    self.publish(label: label, output: output, failed: false, date: date)
                case .failure:
                    self.publish(label: label, output: nil, failed: true, date: date)
                }

                try? await Task.sleep(for: .seconds(max(config.intervalSeconds, 5)))
            }
        }
    }

    private func publish(label: String, output: String?, failed: Bool, date: Date) {
        onUpdate?(label, output, failed, date)
    }
}
