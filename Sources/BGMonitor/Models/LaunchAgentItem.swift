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

    // Scheduling metadata, parsed from the plist by PlistScanner.
    var runAtLoad: Bool = false
    var startInterval: TimeInterval?
    var calendarRules: [CalendarRule] = []
    var keepAliveDescription: String?
    var watchPaths: [String] = []
    var queueDirectories: [String] = []
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
        } else if !calendarRules.isEmpty {
            return .calendar(count: calendarRules.count)
        } else if keepAliveDescription != nil || !watchPaths.isEmpty || !queueDirectories.isEmpty {
            return .onDemand
        } else {
            return .manual
        }
    }
}
