# Implementation Plan: SwiftBar System Monitor Open Source Ready

## Phase 2: Plan

### Components
- Plugin core: refactor `system-monitor.5s.sh` into small Bash functions for probing, rendering, configuration, and actions.
- SwiftBar folder compatibility: keep the plugin files at repo root and exclude support files with `.swiftbarignore`.
- Configuration: read SwiftBar environment variables first, then optional config file overrides from `SWIFTBAR_PLUGIN_DATA_PATH`, `SWIFTBAR_PLUGIN_CACHE_PATH`, or `~/.config/swiftbar-system-monitor/config`.
- Smart Triage: calculate health state and top culprit from existing system signals.
- Actions menu: preserve one-click kill for confirmed busy apps, tuck destructive tools under Advanced, and scope process actions to sampled user-owned PIDs.
- Performance and cache: avoid expensive checks every 5 seconds where possible; cache slow sections with a short TTL.
- Open-source package: initialize Git, add README, MIT license, changelog, contributing guide, `.gitignore`, verification script, and optional CI.

### Implementation Order
1. Establish repo hygiene and verification baseline.
2. Add docs and project metadata for open-source readiness.
3. Refactor plugin safely without changing intended output.
4. Add configuration loading and documented defaults.
5. Add Smart Triage.
6. Polish action labels and add diagnostic report action.
7. Reduce slow checks with guards/cache.
8. Run verification and adjust docs for final behavior.

### Risks And Mitigations
- Risk: SwiftBar parsing breaks because of quoting or generated action syntax.
  - Mitigation: keep output simple, use `printf`, run the script directly, and manually verify representative output.
- Risk: 5-second refresh becomes too slow due to `system_profiler`, `softwareupdate`, or Docker stats.
  - Mitigation: cache slow probes and make optional expensive sections configurable.
- Risk: one-click kill actions are dangerous.
  - Mitigation: keep labels explicit, color force-kill red, never run automatically, and document the safety model.
- Risk: config precedence surprises users.
  - Mitigation: document order and print current config in the dropdown.
- Risk: Shell portability issues across macOS Bash versions.
  - Mitigation: avoid Bash 4-only features; test with `/bin/bash`.

### Parallel Work
- Docs/package setup can proceed independently from plugin refactor.
- Smart Triage depends on normalized probe functions.
- Action polish can proceed after process/container rendering is isolated.
- Caching depends on configuration and probe boundaries.

### Verification Checkpoints
- Checkpoint 1: `bash -n system-monitor.5s.sh` and `shellcheck system-monitor.5s.sh` pass after refactor.
- Checkpoint 2: direct execution prints a compact header and all expected sections.
- Checkpoint 3: optional dependencies missing or unavailable do not fail the script.
- Checkpoint 4: docs match actual commands, config names, and actions.
- Checkpoint 5: local Git repository contains only intended public files unless private/local files are explicitly kept untracked.

## Phase 3: Tasks

- [x] Task: Initialize open-source repo hygiene
  - Acceptance: `.git` exists, `.gitignore` excludes macOS noise and local/private files, `.swiftbarignore` lets SwiftBar consume the repo root, public file set is clear.
  - Verify: `git status --short --branch`
  - Files: `.gitignore`

- [x] Task: Add contributor verification script
  - Acceptance: `.repo/scripts/verify` runs Bash syntax check, ShellCheck when available, and direct plugin execution smoke test; it remains non-executable so SwiftBar does not treat it as a plugin.
  - Verify: `bash .repo/scripts/verify`
  - Files: `.repo/scripts/verify`

- [x] Task: Add public docs and metadata
  - Acceptance: README explains install, config, features, optional dependencies, safety model, and verification; license/changelog/contributing exist.
  - Verify: read through docs and run documented commands.
  - Files: `.repo/README.md`, `.repo/LICENSE`, `.repo/CHANGELOG.md`, `.repo/CONTRIBUTING.md`

- [x] Task: Refactor plugin into helper functions
  - Acceptance: output remains SwiftBar-compatible and behavior is preserved before new features.
  - Verify: `bash -n system-monitor.5s.sh`, `shellcheck system-monitor.5s.sh`, direct output smoke test.
  - Files: `system-monitor.5s.sh`

- [x] Task: Add configuration support
  - Acceptance: documented SwiftBar env vars and config file values control expensive sections, thresholds, and action visibility.
  - Verify: run with env overrides and with a sample config file.
  - Files: `system-monitor.5s.sh`, `.repo/README.md`

- [x] Task: Add Smart Triage
  - Acceptance: header and dropdown report healthy/warning/critical state and the top culprit.
  - Verify: direct output with normal state and simulated threshold overrides.
  - Files: `system-monitor.5s.sh`, `.repo/docs/swiftbar-output-examples.md`

- [x] Task: Add Actions menu and diagnostic report
  - Acceptance: one-click actions are grouped, destructive actions are clearly labeled, and a diagnostic report can be copied or opened.
  - Verify: inspect generated action lines and manually run non-destructive actions.
  - Files: `system-monitor.5s.sh`, `.repo/README.md`

- [x] Task: Cache or gate slow probes
  - Acceptance: expensive checks do not run every 5 seconds unless enabled; stale cache has clear fallback behavior.
  - Verify: run with default config and inspect output; run with expensive checks enabled.
  - Files: `system-monitor.5s.sh`, `.repo/README.md`

- [x] Task: Final validation
  - Acceptance: verification script passes; docs reflect actual behavior; Git status shows intended changes only.
  - Verify: `bash .repo/scripts/verify`, `git status --short`
  - Files: all touched files
