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

    var displayName: String {
        label ?? plistURL.lastPathComponent
    }
}
