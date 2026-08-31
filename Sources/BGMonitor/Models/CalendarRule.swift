import Foundation

/// One entry of a launchd `StartCalendarInterval` — an omitted field means
/// "every" value for that field (matches cron semantics). `weekday` is
/// 0–7 (0 and 7 both mean Sunday).
struct CalendarRule: Equatable, Sendable {
    var minute: Int?
    var hour: Int?
    var day: Int?
    var weekday: Int?
    var month: Int?

    private static let weekdayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    ]
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    var summary: String {
        var parts: [String] = []
        if let month, month >= 1, month <= 12 {
            parts.append(Self.monthNames[month - 1])
        }
        if let day {
            parts.append("day \(day)")
        }
        if let weekday, weekday >= 0, weekday <= 7 {
            parts.append(Self.weekdayNames[weekday])
        }
        if let hour, let minute {
            parts.append(String(format: "%02d:%02d", hour, minute))
        } else if let hour {
            parts.append(String(format: "hour %02d", hour))
        } else if let minute {
            parts.append(String(format: "minute %02d", minute))
        }
        return parts.isEmpty ? "Every minute" : parts.joined(separator: ", ")
    }
}
