import Foundation

/// Raw, unparsed `launchctl print`/`blame` output for a label, meant for a
/// human to read directly rather than being parsed — useful for diagnosing
/// an agent that's registered but won't start, or confirming it isn't
/// loaded at all.
enum LaunchctlDebugInfo {
    static func rawPrint(label: String) -> String {
        run(arguments: ["print", "gui/\(getuid())/\(label)"])
    }

    static func rawBlame(label: String) -> String {
        run(arguments: ["blame", "gui/\(getuid())/\(label)"])
    }

    private static func run(arguments: [String]) -> String {
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
            return "$ \(commandLine)\nFailed to launch: \(error.localizedDescription)"
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        var output = "$ \(commandLine)  (exit \(process.terminationStatus))\n"
        if !stdout.isEmpty { output += stdout }
        if !stderr.isEmpty { output += stderr }
        if stdout.isEmpty && stderr.isEmpty { output += "(no output)\n" }
        return output
    }
}
