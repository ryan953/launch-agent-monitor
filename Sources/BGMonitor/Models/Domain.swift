import Foundation

enum Domain: String, CaseIterable, Codable, Sendable {
    case user
    case local

    var displayName: String {
        switch self {
        case .user: return "User"
        case .local: return "Local"
        }
    }

    var directoryURL: URL {
        switch self {
        case .user:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents")
        case .local:
            return URL(fileURLWithPath: "/Library/LaunchAgents")
        }
    }
}
