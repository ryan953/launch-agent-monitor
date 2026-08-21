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

            return LaunchAgentItem(
                id: label,
                label: label,
                plistURL: plistURL,
                domain: domain,
                parseError: nil
            )
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
}
