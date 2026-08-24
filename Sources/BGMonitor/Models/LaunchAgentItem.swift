import Foundation

struct LaunchAgentItem: Identifiable, Equatable, Sendable {
    /// The launchd Label if the plist has one, otherwise the file path.
    let id: String
    let label: String?
    let plistURL: URL
    let domain: Domain
    var parseError: String?

    var isRegistered: Bool = false
    var isRunning: Bool = false
    var pid: Int32?
    var lastExitCode: Int32?

    var statusCommand: StatusCheckConfig?

    // Scheduling metadata, parsed from the plist by PlistScanner.
    var runAtLoad: Bool = false
    var startInterval: TimeInterval?
    var calendarIntervalCount: Int = 0
    var hasKeepAlive: Bool = false
    var hasWatchPaths: Bool = false
    var standardOutPath: String?
    var standardErrorPath: String?

    var displayName: String {
        label ?? plistURL.lastPathComponent
    }

    var schedule: AgentSchedule {
        if runAtLoad {
            return .atLoad
        } else if let startInterval {
            return .interval(startInterval)
        } else if calendarIntervalCount > 0 {
            return .calendar(count: calendarIntervalCount)
        } else if hasKeepAlive || hasWatchPaths {
            return .onDemand
        } else {
            return .manual
        }
    }
}
