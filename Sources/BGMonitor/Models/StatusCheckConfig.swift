import Foundation

struct StatusCheckConfig: Codable, Equatable, Sendable {
    var command: String
    var intervalSeconds: TimeInterval
    var lastOutput: String?
    var lastRunDate: Date?
    var lastRunFailed: Bool = false
}
