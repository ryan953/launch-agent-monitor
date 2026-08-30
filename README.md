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
- **View Log** — opens a window with a tab per configured log stream
  (stdout/stderr, live-tailed) plus a Plist tab showing the agent's plist
  re-serialized as readable XML (so binary-format plists are readable too);
  brings that window to the front even if it's already open behind another
  app. Disabled only when the agent has no Label to key the window on —
  still available with no log configured, since the Plist tab always works.
- **Debug** — raw `launchctl print`/`launchctl blame` output, useful for
  diagnosing an agent that's registered but won't start

Every row always renders the same set of buttons — disabled rather than
hidden when inapplicable — so icons stay aligned down the whole list. All of
the icon-only buttons (row actions, badges, footer) use a shared hover
style (`HoverableButtonStyle`) that highlights on mouse-over, since a plain
borderless/plain SwiftUI button otherwise gives no visual cue it's
clickable until you actually click it.

Scope is intentionally limited to LaunchAgents (not LaunchDaemons, and not
Apple's `/System/Library/LaunchAgents`) so the whole app reads live state
via `launchctl print gui/<uid>/<label>` without ever needing sudo/root.

## Installing

```sh
export HOMEBREW_GITHUB_API_TOKEN=<a token that can read this repo>
brew install --cask --no-quarantine ryan953/tap/bg-monitor
```

The token is needed because this repository is private, so the plain release
download URL answers 404 and the cask fetches through the GitHub API instead.
`--no-quarantine` is needed because the app is ad-hoc signed but not notarized.
Without it, Gatekeeper refuses to open the app and you have to clear the flag by
hand with `xattr -dr com.apple.quarantine /Applications/BGMonitor.app`.

To install without Homebrew, take the `.zip` from any
[release](https://github.com/ryan953/launch-agent-monitor/releases) and unpack
`BGMonitor.app` into `/Applications`.

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

## Releasing

Releases are cut on demand, never by pushing to `main`: **Actions → Release →
Run workflow**, then give it a version such as `v0.1.0` (a bare `0.1.0` works
too — the leading `v` is normalised on either spelling).

The workflow builds one slice per architecture and `lipo`s them into a universal
binary, wraps it in an ad-hoc signed `BGMonitor.app`, and attaches two assets to
a new GitHub release: the `.app` in a `.zip`, and the bare executable. Only the
zip carries the version in its name, and that matters — the tap picks the one
asset whose name contains the version, so the bare executable has to stay
unversioned.

It then bumps the `bg-monitor` cask in
[ryan953/homebrew-tap](https://github.com/ryan953/homebrew-tap) by running that
tap's own `scripts/bump-cask.sh`, so the release and the cask cannot drift.

That last step needs a `TAP_TOKEN` repository secret, because the built-in
`GITHUB_TOKEN` only reaches this repository. It must be a PAT with **Contents:
Read and write** on `ryan953/homebrew-tap` and **Contents: Read** here (the bump
script downloads the freshly released asset to checksum it); a classic token
with `repo` covers both. Without the secret the release is still created and
only the cask bump is skipped, with a note in the run summary telling you the
command to run by hand. Untick **Bump the bg-monitor cask** to skip it
deliberately.

## Layout

- `Sources/BGMonitor/Models` — `LaunchAgentItem`, `Domain`, `GroupingKey`, `AgentSchedule`, `CalendarRule`
- `Sources/BGMonitor/Services` — plist scanning, launchctl state reading, directory watching, log tailing (`LogTailer`), raw launchctl debug info, mutating launchctl actions (`LaunchctlActions`)
- `Sources/BGMonitor/ViewModel` — `AgentListViewModel`, the single source of truth merging all of the above
- `Sources/BGMonitor/Views` — the menubar UI, log-tail window, debug-info sheet, schedule-detail sheet, and the shared `HoverableButtonStyle`
- `Demo/` — the example LaunchAgent (plist template, script, and `install.sh`)
