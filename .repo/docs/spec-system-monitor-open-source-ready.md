# Spec: SwiftBar System Monitor Open Source Ready

## Assumptions
1. Primary scope is `system-monitor.5s.sh`; `pipeline-status.1m.py` stays separate unless explicitly pulled into the release.
2. Target users are macOS power users who want a fast, actionable health dashboard in SwiftBar.
3. The plugin should remain a standard finite SwiftBar script, not a long-running streamable plugin.
4. Built-in macOS tools are preferred; optional integrations such as Docker, OrbStack, `osx-cpu-temp`, and `istats` should degrade cleanly.
5. "Open source ready" means installable, documented, linted, configurable, and safe enough for public users to run without editing the script.
6. The public project should be initialized as a Git repository with a lightweight setup similar in spirit to sibling open-source repos: public docs, MIT license, changelog, contributing guide, ignore rules, and repeatable verification.

## Objective
Make the SwiftBar system monitor feel like a polished power-user utility rather than a personal script.

The plugin should answer three questions quickly:
- Is my Mac healthy right now?
- What is the most likely culprit when it is not?
- What safe action can I take without opening several apps?

Killer features:
- Smart Triage: a compact health score and top-cause summary in the menu bar/dropdown, backed by load, CPU, memory pressure, disk, battery, thermal, Spotlight, update, and container signals.
- Actions menu: contextual remediation and diagnostics, including safer process actions, Activity Monitor deep links, container actions, and a copyable diagnostic report.

Open-source readiness:
- Add public docs, install instructions, metadata, examples, license, changelog, and contribution guidance.
- Add lightweight verification commands so contributors can validate changes before submitting.
- Release only the system monitor plugin as the primary public artifact.

## Tech Stack
- Runtime: Bash script for SwiftBar/BitBar-compatible output.
- Platform: macOS with SwiftBar 2.x, compatible with SwiftBar's standard plugin execution model.
- Required commands: `/bin/bash`, `awk`, `sed`, `ps`, `df`, `vm_stat`, `pmset`, `ifconfig`, `system_profiler`, `softwareupdate`, `open`, `osascript`.
- Optional commands: `docker`, `osx-cpu-temp`, `istats`, `shellcheck`.
- No required package manager dependencies for end users.

SwiftBar constraints from current docs:
- Plugin files use `{name}.{time}.{ext}` naming, for example `system-monitor.5s.sh`.
- Header output before the first `---` controls the menu bar title; body output after `---` controls the dropdown.
- Menu actions use parameters such as `bash`, `terminal`, `refresh`, `href`, `shortcut`, `tooltip`, and `sfimage`.
- SwiftBar sets plugin-specific paths such as `SWIFTBAR_PLUGIN_CACHE_PATH` and `SWIFTBAR_PLUGIN_DATA_PATH`.

## Commands
Development checks:

```sh
bash -n system-monitor.5s.sh
shellcheck system-monitor.5s.sh
./system-monitor.5s.sh >/tmp/swiftbar-system-monitor.out
python3 -m py_compile pipeline-status.1m.py
```

Manual SwiftBar check:

```sh
chmod +x system-monitor.5s.sh
open -a SwiftBar
open -g "swiftbar://refreshplugin?plugin=system-monitor.5s.sh"
```

Optional release sanity:

```sh
find . -maxdepth 2 -type f | sort
grep -R "TODO\\|FIXME\\|YOUR_" .
```

## Project Structure
Current:

```text
system-monitor.5s.sh    Main macOS system monitor SwiftBar plugin
pipeline-status.1m.py   Separate AWS CodePipeline SwiftBar plugin
```

Target:

```text
system-monitor.5s.sh          Main plugin
pipeline-status.1m.py         Existing separate private/local plugin, excluded from public release scope
.swiftbarignore               Keeps repo support files out of SwiftBar plugin discovery
.repo/README.md                     Installation, screenshots/GIF, usage, configuration
.repo/LICENSE                       Open-source license
.repo/CHANGELOG.md                  User-visible changes
.repo/CONTRIBUTING.md               Contributor workflow and checks
.gitignore                    Ignore local/system/generated files
.repo/github/workflows/ci.yml      Optional CI for shell syntax and shellcheck
.repo/docs/
  spec-system-monitor-open-source-ready.md
  swiftbar-output-examples.md Optional examples for plugin output states
scripts/
  verify                   Runs local verification commands
```

## Code Style
Use explicit, portable Bash with small helper functions and defensive command checks.

```sh
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_action() {
    local title="$1"
    local command="$2"
    local color="${3:-}"

    if [ -n "$color" ]; then
        printf -- "--%s | bash=%q terminal=false refresh=true color=%s\n" "$title" "$command" "$color"
    else
        printf -- "--%s | bash=%q terminal=false refresh=true\n" "$title" "$command"
    fi
}
```

Conventions:
- Quote variable expansions unless numeric comparison requires validated numeric input.
- Prefer helper functions for repeated SwiftBar output formatting.
- Keep expensive probes behind guards and cache where SwiftBar data/cache paths are available.
- Avoid destructive actions unless the label is explicit and the command is visible.
- Use `printf` for generated menu lines where escaping matters.

## Testing Strategy
Static checks:
- `bash -n system-monitor.5s.sh` must pass.
- `shellcheck system-monitor.5s.sh` must pass or have documented, narrow suppressions.

Runtime checks:
- Running `./system-monitor.5s.sh` should exit 0 and print non-empty SwiftBar-compatible output.
- Missing optional tools should produce "Not available" or omit the section, not fail the plugin.
- Docker/OrbStack sections should appear only when available.
- Process action lines must include a PID from the current sample and must refresh after action.

Manual SwiftBar checks:
- Menu bar header remains compact.
- Dropdown opens without visible lag on a normal Mac.
- Actions run in the intended mode: background for safe actions, terminal for destructive or verbose actions.
- Dark/light appearance stays readable.

## Boundaries
- Always:
  - Preserve SwiftBar-compatible output.
  - Keep the header compact enough for a menu bar.
  - Degrade gracefully when optional commands are missing.
  - Run syntax and shellcheck verification before considering implementation done.
  - Put user-facing configuration in both documented SwiftBar environment metadata and a local config file override.
- Ask first:
  - Adding required runtime dependencies.
  - Turning the script into Python, Swift, or another language.
  - Making actions more destructive than current one-click behavior.
  - Publishing to a remote repository.
  - Changing or removing `pipeline-status.1m.py`.
- Never:
  - Commit secrets, hostnames, access tokens, or local machine-specific paths.
  - Require sudo for normal display.
  - Run destructive actions automatically.
  - Hide failures by redirecting all errors without a user-visible fallback.

## Success Criteria
- Header shows one compact health summary with color: healthy, warning, or critical.
- Dropdown includes a Smart Triage section that names the top culprit when the system is unhealthy.
- Dropdown includes an Actions menu with at least:
  - Open Activity Monitor.
  - Copy diagnostic report.
  - Kill and force-kill actions marked clearly and scoped to sampled PIDs.
  - Docker/OrbStack stop, restart, logs, and prune actions only when Docker is available.
- Expensive checks are reduced, cached, or made conditional so a 5-second refresh remains practical.
- Optional dependencies are documented and never required for basic operation.
- `shellcheck system-monitor.5s.sh` passes.
- `bash -n system-monitor.5s.sh` passes.
- Running the script directly exits 0 and prints usable SwiftBar output.
- README explains installation, configuration, optional dependencies, safety model, and screenshots/example output.
- Repository includes `.repo/LICENSE`, `.repo/CHANGELOG.md`, and `.repo/CONTRIBUTING.md`.
- Folder is initialized as a Git repository with an appropriate `.gitignore`.
- Repo root can still be used directly as a SwiftBar plugin folder via `.swiftbarignore`.
- Plugin version is visible in SwiftBar metadata, dropdown actions, diagnostic report, and `--version` output.

## Open Questions
Resolved:
- License: MIT.
- Public release scope: system monitor only.
- Process actions: keep one-click actions, clearly labeled.
- Configuration: support both SwiftBar environment metadata and a config file.
- Git: initialize this directory as a repository during setup.

Still open:
- Repository name and remote URL are not defined yet; local Git setup can proceed without publishing.

## Sources
- SwiftBar README: https://github.com/swiftbar/SwiftBar
- SwiftBar release metadata observed on GitHub: latest listed release `2.0.1` from 2025-02-27.
