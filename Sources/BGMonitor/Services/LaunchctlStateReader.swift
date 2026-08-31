import Foundation

struct LaunchctlServiceState: Sendable {
    var isRegistered: Bool
    var isRunning: Bool
    var pid: Int32?
    var lastExitCode: Int32?
}

/// Reads live launchd state for a label via `launchctl print gui/<uid>/<label>`.
///
/// Deliberately does NOT parse the domain-wide `launchctl print gui/<uid>`
/// dump — its `services = { ... }` table is explicitly undocumented and
/// unstable (per `man launchctl`: "NOT API in any sense... do NOT rely on
/// the structure"). The per-label form returns a stable `key = value` block.
enum LaunchctlStateReader {
    static func state(forLabel label: String) -> LaunchctlServiceState {
        let uid = getuid()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "gui/\(uid)/\(label)"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()  // discard stderr, we only care about exit status + stdout

        do {
            try process.run()
        } catch {
            return LaunchctlServiceState(isRegistered: false, isRunning: false, pid: nil, lastExitCode: nil)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return LaunchctlServiceState(isRegistered: false, isRunning: false, pid: nil, lastExitCode: nil)
        }

        let output = String(data: outputData, encoding: .utf8) ?? ""
        return parse(output: output)
    }

    private static func parse(output: String) -> LaunchctlServiceState {
        var isRunning = false
        var pid: Int32?
        var lastExitCode: Int32?

        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let equalsIndex = line.firstIndex(of: "=") else { continue }

            let key = line[line.startIndex..<equalsIndex].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
            if let commentRange = value.range(of: "//") {
                value = String(value[value.startIndex..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }

            switch key {
            case "state":
                isRunning = value == "running"
            case "pid":
                pid = Int32(value)
            case "last exit code":
                lastExitCode = Int32(value)
            default:
                continue
            }
        }

        return LaunchctlServiceState(
            isRegistered: true,
            isRunning: isRunning,
            pid: pid,
            lastExitCode: lastExitCode
        )
    }
}
