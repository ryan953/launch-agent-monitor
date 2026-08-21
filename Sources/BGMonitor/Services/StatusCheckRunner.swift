import Foundation
import os

enum StatusCheckError: Error {
    case timedOut
    case nonZeroExit(Int32, stderr: String)
}

/// Runs a user-supplied shell command with a hard timeout, returning its
/// trimmed stdout on success.
///
/// Uses a login shell (`zsh -l -c`) since a menubar app launched from Finder
/// doesn't inherit the user's real shell PATH / rc-file setup, and
/// user-supplied commands will assume it.
enum StatusCheckRunner {
    static func run(command: String, timeout: TimeInterval) async -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set right before terminate() so we can report a clean `.timedOut`
        // even though killing the process also races the termination
        // handler below into resolving with a "killed by signal" exit status.
        let didTimeOut = OSAllocatedUnfairLock(initialState: false)

        do {
            return try await withThrowingTaskGroup(of: Result<String, Error>.self) { group in
                group.addTask {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result<String, Error>, Error>) in
                        process.terminationHandler = { finishedProcess in
                            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                            let output = String(data: stdoutData, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                            if finishedProcess.terminationStatus == 0 {
                                continuation.resume(returning: .success(output))
                            } else {
                                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                                let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
                                continuation.resume(returning: .failure(
                                    StatusCheckError.nonZeroExit(finishedProcess.terminationStatus, stderr: stderrString)
                                ))
                            }
                        }
                        do {
                            try process.run()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    if process.isRunning {
                        didTimeOut.withLock { $0 = true }
                        process.terminate()
                        try? await Task.sleep(for: .seconds(2))
                        if process.isRunning {
                            kill(process.processIdentifier, SIGKILL)
                        }
                    }
                    return .failure(StatusCheckError.timedOut)
                }

                guard let first = try await group.next() else {
                    return .failure(StatusCheckError.timedOut)
                }
                group.cancelAll()
                return didTimeOut.withLock({ $0 }) ? .failure(StatusCheckError.timedOut) : first
            }
        } catch {
            return .failure(error)
        }
    }
}
