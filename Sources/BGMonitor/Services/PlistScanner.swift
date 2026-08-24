import Foundation

/// Scans the LaunchAgents directories on disk and parses each plist into a
/// `LaunchAgentItem`. Files that fail to parse or lack a Label are still
/// returned (flagged via `parseError`) rather than silently skipped.
enum PlistScanner {
    static func scan() -> [LaunchAgentItem] {
        Domain.allCases.flatMap { scan(domain: $0) }
    }

    private static func scan(domain: Domain) -> [LaunchAgentItem] {
        let directoryURL = domain.directoryURL
        let fileManager = FileManager.default

        guard let entries = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .filter { $0.pathExtension.lowercased() == "plist" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { parse(plistURL: $0, domain: domain) }
    }

    private static func parse(plistURL: URL, domain: Domain) -> LaunchAgentItem {
        guard let data = try? Data(contentsOf: plistURL) else {
            return LaunchAgentItem(
                id: plistURL.path,
                label: nil,
                plistURL: plistURL,
                domain: domain,
                parseError: "Could not read file"
            )
        }

        do {
            let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = object as? [String: Any] else {
                return LaunchAgentItem(
                    id: plistURL.path,
                    label: nil,
                    plistURL: plistURL,
                    domain: domain,
                    parseError: "Plist root is not a dictionary"
                )
            }

            guard let label = dict["Label"] as? String, !label.isEmpty else {
                return LaunchAgentItem(
                    id: plistURL.path,
                    label: nil,
                    plistURL: plistURL,
                    domain: domain,
                    parseError: "Missing Label key"
                )
            }

            var item = LaunchAgentItem(
                id: label,
                label: label,
                plistURL: plistURL,
                domain: domain,
                parseError: nil
            )
            applyScheduleMetadata(from: dict, to: &item)
            return item
        } catch {
            return LaunchAgentItem(
                id: plistURL.path,
                label: nil,
                plistURL: plistURL,
                domain: domain,
                parseError: "Invalid plist: \(error.localizedDescription)"
            )
        }
    }

    /// Reads the scheduling/logging keys defined by launchd.plist(5).
    /// All casts are defensive — a malformed or unexpected value for any
    /// key just leaves that field unset rather than failing the whole parse.
    private static func applyScheduleMetadata(from dict: [String: Any], to item: inout LaunchAgentItem) {
        item.runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false

        if let seconds = dict["StartInterval"] as? Int {
            item.startInterval = TimeInterval(seconds)
        }

        // StartCalendarInterval may be a single dict or an array of dicts.
        // Try the array form first: a single dict won't cast as
        // [[String: Any]], and an array won't cast as [String: Any], so
        // trying either order is safe.
        if let entries = dict["StartCalendarInterval"] as? [[String: Any]] {
            item.calendarIntervalCount = entries.count
        } else if dict["StartCalendarInterval"] as? [String: Any] != nil {
            item.calendarIntervalCount = 1
        }

        item.hasKeepAlive = dict["KeepAlive"] != nil

        let watchPaths = dict["WatchPaths"] as? [Any]
        let queueDirectories = dict["QueueDirectories"] as? [Any]
        item.hasWatchPaths = !(watchPaths?.isEmpty ?? true) || !(queueDirectories?.isEmpty ?? true)

        item.standardOutPath = dict["StandardOutPath"] as? String
        item.standardErrorPath = dict["StandardErrorPath"] as? String
    }
}
