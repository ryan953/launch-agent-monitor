# BG Monitor

A native macOS menubar app that lists every LaunchAgent registered under
`~/Library/LaunchAgents` (yours) and `/Library/LaunchAgents` (machine-wide),
showing whether each one is registered with launchd and currently running.
Group the list by running state, owner (User/System), or registration status.
The panel grows taller to fit the current list (capped to the screen's
visible height) instead of staying a fixed size.

Each row shows, left to right: owner (User/System), a registration badge
that's also the register/unregister button (`launchctl bootstrap`/`bootout`
— green when registered, click to toggle), a running indicator, and a
schedule badge that's also the view-schedule button (click for full detail:
calendar rules, keep-alive condition, watch paths). On the right, tooltipped
action buttons:

- **Start/Stop** — `launchctl kickstart`/`kill SIGTERM`, disabled until the
  agent is registered (stopped agents may restart on their own if configured
  with `KeepAlive`)
- **View Log** — opens a live-tailing window over the agent's
  `StandardOutPath`/`StandardErrorPath`, disabled when neither is configured
- **Debug** — raw `launchctl print`/`launchctl blame` output, useful for
  diagnosing an agent that's registered but won't start

Every row always renders the same set of buttons — disabled rather than
hidden when inapplicable — so icons stay aligned down the whole list.

Scope is intentionally limited to LaunchAgents (not LaunchDaemons, and not
Apple's `/System/Library/LaunchAgents`) so the whole app reads live state
via `launchctl print gui/<uid>/<label>` without ever needing sudo/root.

## Running

Requires Xcode 15+ / Swift 6 toolchain on macOS 14+.

```sh
swift run
```

Or open `Package.swift` directly in Xcode and hit Run.

## Demo LaunchAgent

`Demo/` has a fully wired-up example LaunchAgent (`com.ryan953.bemonitor.demo.hello`)
for exercising the app's UI — a real login-item + interval schedule, captured
stdout/stderr, an argument and an environment variable passed into its
script, and the other common tuning fields a real agent carries. Install it
(copies the script and a templated plist into the real
`~/Library/LaunchAgents`/`~/Library/Logs` locations):

```sh
Demo/install.sh
```

It's left **unregistered** on purpose — installing just makes the file exist
on disk so BGMonitor lists it; use the app's own Register button to load it.

## Layout

- `Sources/BGMonitor/Models` — `LaunchAgentItem`, `Domain`, `GroupingKey`, `AgentSchedule`, `CalendarRule`
- `Sources/BGMonitor/Services` — plist scanning, launchctl state reading, directory watching, log tailing (`LogTailer`), raw launchctl debug info, mutating launchctl actions (`LaunchctlActions`)
- `Sources/BGMonitor/ViewModel` — `AgentListViewModel`, the single source of truth merging all of the above
- `Sources/BGMonitor/Views` — the menubar UI, log-tail window, debug-info sheet, and schedule-detail sheet
- `Demo/` — the example LaunchAgent (plist template, script, and `install.sh`)
