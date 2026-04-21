# SwiftBar System Monitor

A compact macOS health dashboard for [SwiftBar](https://github.com/swiftbar/SwiftBar). It keeps load, memory pressure, disk space, high-CPU processes, battery, devices, system alerts, and containers one click away from the menu bar.

## Features

- Compact menu bar health status with color-coded load state.
- Animated healthy-state menubar indicator with a static fallback option.
- Top CPU and memory consumers with one-click kill and force-kill actions.
- Busy app alerts for processes using too much CPU.
- Battery, thermal, fan, uptime, network, display, USB, and Bluetooth details.
- Optional Docker/OrbStack container status with stop, restart, logs, and prune actions.
- Quick actions for Activity Monitor, Console, System Settings, Spotlight reindexing, trash emptying, and memory purge.
- One-click `Update from GitHub` action in `About`, with background execution and in-menu success/failure status.
- Cached GitHub version status in `About`, so users can see when a newer version is available before updating.
- Graceful fallbacks when optional tools are missing.

## Requirements

- macOS with SwiftBar installed.
- Built-in macOS command-line tools.
- Optional: `docker`, `osx-cpu-temp`, and `istats` for richer sections.

Install SwiftBar:

```sh
brew install swiftbar
```

## Installation

You can either point SwiftBar at this folder directly or copy `system-monitor.5s.sh` into an existing SwiftBar plugin folder. This repo includes `.swiftbarignore` so SwiftBar ignores docs, CI, and helper scripts when the repo root is used as the plugin folder.

1. Put this folder somewhere stable, or copy `system-monitor.5s.sh` into your SwiftBar plugin folder.
2. Make it executable:

   ```sh
   chmod +x system-monitor.5s.sh
   ```

3. Refresh SwiftBar:

   ```sh
   open -g "swiftbar://refreshplugin?plugin=system-monitor.5s.sh"
   ```

The `5s` in the filename tells SwiftBar to refresh the plugin every five seconds.

## Updating

Use `Actions > About > Update from GitHub`.

`About` also shows:

- `GitHub: vX.Y.Z available` when the official repo has a newer version.
- `GitHub: up to date` when the installed plugin matches GitHub.
- `GitHub: update check unavailable` when the version lookup fails and no cache is available.
- `Update: Updated to vX.Y.Z from GitHub` after a recent successful update.
- `Update: ...` failure details after a recent failed update.

- If SwiftBar is pointed at an official checkout of `@oleg-koval/swiftbar-plugins`, the plugin runs `git pull --ff-only`.
- If you copied only `system-monitor.5s.sh` into another plugin folder, the plugin downloads the latest `system-monitor.5s.sh` from the GitHub repository and replaces the local file.

The update action returns immediately. The actual update runs in the background, refreshes the plugin when finished, and shows a macOS notification for success or failure.

The updater targets the official GitHub repository and the default branch.

## Configuration

Configuration supports both SwiftBar environment variables and local config files.

Config file locations:

```sh
$SWIFTBAR_PLUGIN_DATA_PATH/config
~/.config/swiftbar-system-monitor/config
```

Precedence:

1. SwiftBar environment variables.
2. Plugin data-path config file.
3. User config file.
4. Script defaults.

Example config file:

```sh
SM_LOAD_WARN=6
SM_LOAD_CRIT=8
SM_HIGH_CPU_THRESHOLD=90
SM_LOW_DISK_WARN_GB=20
SM_SHOW_DEVICES=false
SM_SHOW_SYSTEM_ALERTS=true
SM_CHECK_SOFTWARE_UPDATES=false
SM_SHOW_DOCKER=true
SM_SHOW_DOCKER_STATS=false
SM_SHOW_ENERGY=false
SM_ANIMATE_TITLE=true
SM_SLOW_CACHE_TTL_SECONDS=300
```

SwiftBar environment variables use the `VAR_` prefix:

| Variable | Default | Purpose |
|---|---:|---|
| `VAR_SM_LOAD_WARN` | `6` | Load average warning threshold |
| `VAR_SM_LOAD_CRIT` | `8` | Load average critical threshold |
| `VAR_SM_HIGH_CPU_THRESHOLD` | `90` | CPU percent treated as runaway |
| `VAR_SM_LOW_DISK_WARN_GB` | `20` | Free disk warning threshold |
| `VAR_SM_SHOW_DEVICES` | `false` | Show displays, USB, Bluetooth, and network. Uses cached `system_profiler` probes, but still adds menu work. |
| `VAR_SM_SHOW_SYSTEM_ALERTS` | `true` | Show update, iCloud, and Spotlight alerts |
| `VAR_SM_CHECK_SOFTWARE_UPDATES` | `false` | Run the slow macOS update scan |
| `VAR_SM_SHOW_DOCKER` | `true` | Show Docker/OrbStack section when available |
| `VAR_SM_SHOW_DOCKER_STATS` | `false` | Run `docker stats` for per-container CPU/memory |
| `VAR_SM_SHOW_ENERGY` | `false` | Run `top -l 2` energy impact while on battery |
| `VAR_SM_ANIMATE_TITLE` | `true` | Animate the healthy menubar indicator. Set `false` for a static `SM` title. |
| `VAR_SM_SLOW_CACHE_TTL_SECONDS` | `300` | Cache TTL for slow system profiler probes |

The default profile favors fast menu opening. Turn on devices, Docker stats, energy impact, or software update checks only if you need those slower sections.

## Safety Model

The plugin includes one-click actions. Destructive actions are visible and labeled, but they do not ask for confirmation by default.

- `Stop Process` sends `TERM` to the sampled PID.
- `Force Kill` is tucked under `Danger Zone`, sends `KILL` to the sampled PID, and opens in Terminal.
- Docker prune runs in Terminal because it is destructive and verbose.
- `Update from GitHub` runs in the background and reports the result through the menu plus a macOS notification.
- No destructive action runs automatically during refresh.

## Verification

Run:

```sh
bash .repo/scripts/verify
```

The script runs:

```sh
bash -n system-monitor.5s.sh
shellcheck system-monitor.5s.sh
./system-monitor.5s.sh >/tmp/swiftbar-system-monitor.verify.out
```

`shellcheck` is optional for users, but required before accepting code changes.

`.repo/scripts/verify` is intentionally not executable. If this repository is used directly as the SwiftBar plugin folder, helper scripts must stay non-executable so SwiftBar does not run them as plugins.

## Versioning

The plugin follows semantic versioning. The current version is declared in two places:

- SwiftBar metadata: `<xbar.version>v1.2.3</xbar.version>`
- Runtime constant: `PLUGIN_VERSION="1.2.3"`

The dropdown includes an About section with the plugin version and a clickable repository link: `@oleg-koval/swiftbar-plugins`.

Check the installed plugin version:

```sh
./system-monitor.5s.sh --version
```

## Roadmap

- Add screenshot/GIF assets for the README.
- Add more output examples for edge states.
- Publish a tagged release after Git remote setup.

See [.repo/docs/spec-system-monitor-open-source-ready.md](.repo/docs/spec-system-monitor-open-source-ready.md) and [.repo/docs/implementation-plan-system-monitor-open-source-ready.md](.repo/docs/implementation-plan-system-monitor-open-source-ready.md).

## License

MIT. See [.repo/LICENSE](.repo/LICENSE).
