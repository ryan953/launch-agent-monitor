import Foundation

enum GroupingKey: String, CaseIterable, Identifiable, Sendable {
    case runningState
    case owner
    case registrationStatus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .runningState: return "Running State"
        case .owner: return "Owner"
        case .registrationStatus: return "Registration Status"
        }
    }

    func sectionKey(for item: LaunchAgentItem) -> String {
        switch self {
        case .runningState:
            return item.isRunning ? "Running" : "Not Running"
        case .owner:
            return item.domain.displayName
        case .registrationStatus:
            return item.isRegistered ? "Registered" : "Not Registered"
        }
    }
}
