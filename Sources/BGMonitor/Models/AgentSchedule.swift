import Foundation

/// A human-readable summary of when/how an agent is triggered, derived from
/// the scheduling-related keys in its plist. An agent can declare more than
/// one trigger; the cases below are ordered by how prominently they should
/// be shown (RunAtLoad first, manual-only last).
enum AgentSchedule: Equatable {
    case atLoad
    case interval(TimeInterval)
    case calendar(count: Int)
    case onDemand
    case manual

    var summary: String {
        switch self {
        case .atLoad:
            return "At load"
        case .interval(let seconds):
            return "Every \(Self.formatted(seconds))"
        case .calendar(let count):
            return count > 1 ? "Calendar (\(count) rules)" : "Calendar schedule"
        case .onDemand:
            return "On demand"
        case .manual:
            return "Manual only"
        }
    }

    var systemImage: String {
        switch self {
        case .atLoad: return "power"
        case .interval: return "timer"
        case .calendar: return "calendar"
        case .onDemand: return "bolt.badge.a"
        case .manual: return "hand.raised"
        }
    }

    private static func formatted(_ seconds: TimeInterval) -> String {
        let seconds = Int(seconds)
        if seconds % 3600 == 0 {
            return "\(seconds / 3600)h"
        } else if seconds % 60 == 0 {
            return "\(seconds / 60)m"
        }
        return "\(seconds)s"
    }
}
