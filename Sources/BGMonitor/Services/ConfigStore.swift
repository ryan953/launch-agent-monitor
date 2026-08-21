import Foundation

/// Persists per-agent `StatusCheckConfig` (command + interval), keyed by
/// launchd Label, to ~/Library/Application Support/BGMonitor/config.json.
final class ConfigStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.bgmonitor.configstore")

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("BGMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("config.json")
    }

    func allConfigs() -> [String: StatusCheckConfig] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return [:] }
            return (try? JSONDecoder().decode([String: StatusCheckConfig].self, from: data)) ?? [:]
        }
    }

    func setConfig(_ config: StatusCheckConfig?, forLabel label: String) {
        queue.sync {
            var all = (try? Data(contentsOf: fileURL)).flatMap {
                try? JSONDecoder().decode([String: StatusCheckConfig].self, from: $0)
            } ?? [:]

            if let config {
                all[label] = config
            } else {
                all.removeValue(forKey: label)
            }

            guard let data = try? JSONEncoder().encode(all) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
