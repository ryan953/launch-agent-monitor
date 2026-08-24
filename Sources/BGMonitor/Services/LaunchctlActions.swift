import Foundation

struct LaunchctlActionError: Error, LocalizedError {
    let commandLine: String
    let exitCode: Int32
    let output: String

    var errorDescription: String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(commandLine) failed (exit \(exitCode))" : trimmed
    }
}

/// Mutating launchctl actions — register/unregister an agent with launchd,
/// and start/stop its process. All target the current user's GUI domain
/// (`gui/<uid>`), matching how `LaunchctlStateReader`/`LaunchctlDebugInfo`
/// read state, so none of these ever need sudo.
enum LaunchctlActions {
    static func register(plistURL: URL) -> Result<Void, LaunchctlActionError> {
        run(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func unregister(label: String) -> Result<Void, LaunchctlActionError> {
        run(["bootout", "gui/\(getuid())/\(label)"])
    }

    static func start(label: String) -> Result<Void, LaunchctlActionError> {
        run(["kickstart", "gui/\(getuid())/\(label)"])
    }

    static func stop(label: String) -> Result<Void, LaunchctlActionError> {
        run(["kill", "SIGTERM", "gui/\(getuid())/\(label)"])
    }

    private static func run(_ arguments: [String]) -> Result<Void, LaunchctlActionError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let commandLine = (["launchctl"] + arguments).joined(separator: " ")

        do {
            try process.run()
        } catch {
            return .failure(LaunchctlActionError(commandLine: commandLine, exitCode: -1, output: error.localizedDescription))
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            return .failure(LaunchctlActionError(commandLine: commandLine, exitCode: process.terminationStatus, output: stdout + stderr))
        }

        return .success(())
    }
}
