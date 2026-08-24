# BG Monitor

A native macOS menubar app that lists every LaunchAgent registered under
`~/Library/LaunchAgents` (yours) and `/Library/LaunchAgents` (machine-wide),
showing whether each one is registered with launchd and currently running.
Group the list by running state, owner (User/Local), or registration status.

Each agent can also have a custom shell command attached that runs on an
interval while the agent is running — its stdout shows up as a status
message on the row (e.g. an indexer reporting "42% done").

Each row also shows its schedule at a glance (at load / every N / calendar /
on demand / manual only, derived from `RunAtLoad`, `StartInterval`,
`StartCalendarInterval`, `KeepAlive`, `WatchPaths`/`QueueDirectories`), and
has buttons — each with a tooltip — to:

- **Register/Unregister** — `launchctl bootstrap`/`bootout`, loads or unloads
  the agent from launchd
- **Start/Stop** — `launchctl kickstart`/`kill SIGTERM`, only shown once
  registered (stopped agents may restart on their own if configured with
  `KeepAlive`)
- **View schedule** — the full detail behind the schedule badge (calendar
  rules, keep-alive condition, watch paths)
- **View Log** — opens a live-tailing window over the agent's
  `StandardOutPath`/`StandardErrorPath`, shown only when configured
- **Debug** — raw `launchctl print`/`launchctl blame` output, useful for
  diagnosing an agent that's registered but won't start

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

- `Sources/BGMonitor/Models` — `LaunchAgentItem`, `Domain`, `GroupingKey`, `StatusCheckConfig`, `AgentSchedule`, `CalendarRule`
- `Sources/BGMonitor/Services` — plist scanning, launchctl state reading, directory watching, status-check scheduling/execution, config persistence, log tailing (`LogTailer`), raw launchctl debug info, mutating launchctl actions (`LaunchctlActions`)
- `Sources/BGMonitor/ViewModel` — `AgentListViewModel`, the single source of truth merging all of the above
- `Sources/BGMonitor/Views` — the menubar UI, log-tail window, debug-info sheet, and schedule-detail sheet
