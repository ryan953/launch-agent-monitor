# BG Monitor

A native macOS menubar app that lists every LaunchAgent registered under
`~/Library/LaunchAgents` (yours) and `/Library/LaunchAgents` (machine-wide),
showing whether each one is registered with launchd and currently running.
Group the list by running state, owner (User/Local), or registration status.

Each agent can also have a custom shell command attached that runs on an
interval while the agent is running — its stdout shows up as a status
message on the row (e.g. an indexer reporting "42% done").

Scope is intentionally limited to LaunchAgents (not LaunchDaemons, and not
Apple's `/System/Library/LaunchAgents`) so the whole app reads live state
via `launchctl print gui/<uid>/<label>` without ever needing sudo/root.

## Running

Requires Xcode 15+ / Swift 6 toolchain on macOS 14+.

```sh
swift run
```

Or open `Package.swift` directly in Xcode and hit Run.

## Layout

- `Sources/BGMonitor/Models` — `LaunchAgentItem`, `Domain`, `GroupingKey`, `StatusCheckConfig`
- `Sources/BGMonitor/Services` — plist scanning, launchctl state reading, directory watching, status-check scheduling/execution, config persistence
- `Sources/BGMonitor/ViewModel` — `AgentListViewModel`, the single source of truth merging all of the above
- `Sources/BGMonitor/Views` — the menubar UI
