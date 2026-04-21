# Plugin Development Notes

This plugin follows the current SwiftBar plugin conventions so it can be used directly in SwiftBar and remain publishable as a standalone open-source repository.

## File Naming

SwiftBar uses the plugin filename to determine refresh cadence.

Current filename:

```text
system-monitor.5s.sh
```

That means:

- plugin name: `system-monitor`
- refresh interval: every `5s`
- executable type: `sh`

If you change the filename, you are changing runtime behavior.

## Required Script Structure

SwiftBar expects:

- an executable script
- menu bar header output before the first `---`
- dropdown menu output after the first `---`

This repository keeps the executable entrypoint in a single file:

- [`system-monitor.5s.sh`](../system-monitor.5s.sh)

## Metadata

SwiftBar reads xbar-compatible metadata from the script header. Keep these values accurate:

- `xbar.title`
- `xbar.version`
- `xbar.author`
- `xbar.author.github`
- `xbar.desc`
- `xbar.dependencies`
- `xbar.abouturl`

The release workflow updates `xbar.version` automatically.

## Menu Actions

SwiftBar menu rows can run scripts using `bash="..."`.

Use these patterns intentionally:

- `terminal=false` for background, non-interactive actions
- `terminal=true` for destructive, verbose, or operator-visible tasks
- `refresh=true` only when a rerender should happen immediately

This repository already uses those patterns for:

- background update checks and updater execution
- local incident reporting
- process management and other disruptive actions

## Repo Safety as a Plugin Folder

SwiftBar will scan the plugin folder aggressively. To keep the whole repository safe as a plugin folder:

- helper files live outside the executable plugin
- `.swiftbarignore` excludes docs, tests, workflows, site files, and tooling
- helper scripts remain non-executable unless they are meant to run directly

If you add a new top-level file or directory, update `.swiftbarignore` in the same change.

## Submission Guidance

If you publish or submit this plugin elsewhere:

- keep metadata complete
- keep dependencies explicit
- keep the install path simple
- document any non-default macOS tools as optional, not required, unless the plugin truly depends on them
