# Contributing

Thanks for improving SwiftBar System Monitor.

## Local Setup

Recommended toolchain:

- macOS with SwiftBar installed
- Node.js 22 for repo tooling
- `shellcheck`

Quick start:

```sh
npm ci
bash .repo/scripts/verify
npm run site:build
```

## Development Rules

- Keep changes scoped and reviewable.
- Preserve SwiftBar-compatible output and plugin metadata.
- Keep optional integrations optional.
- Do not add new required runtime dependencies without discussion.
- When behavior changes, update tests and public docs in the same change.

## SwiftBar-Specific Rules

- Keep the executable plugin file named `system-monitor.5s.sh` unless there is an intentional schedule change.
- If you add helper scripts or public docs, keep `.swiftbarignore` updated so the repo can still be used directly as a SwiftBar plugin folder.
- Prefer `terminal=false` for fast non-interactive actions.
- Reserve Terminal-launched actions for destructive, privileged, or verbose operations.

## Verification

Run before opening a PR:

```sh
bash .repo/scripts/verify
npm run site:build
```

If you touch release tooling, also run:

```sh
npm run release:dry-run
```

## Commit Convention

This repository uses Conventional Commits because releases are generated from commit history.

Examples:

```text
fix: harden battery parsing on MacBooks
feat: add GitHub background updater
docs: clarify SwiftBar install flow
refactor: extract shared process label formatter
feat!: rename plugin commands for a cleaner public interface
```

Release impact:

- `fix:` -> patch
- `feat:` -> minor
- `perf:` -> patch
- `!` or `BREAKING CHANGE:` -> major

Use a Conventional Commit PR title too. Maintainers can squash-merge without losing release semantics.

## Pull Requests

- Explain what changed and why.
- Include verification commands and outcomes.
- Add screenshots when menu structure or the Pages site changes.
- Keep secrets, hostnames, tokens, and local paths out of issues and examples.

## Community Standards

- [Code of Conduct](./CODE_OF_CONDUCT.md)
- [Security Policy](./SECURITY.md)
- [Release Guide](./docs/releasing.md)
- [Plugin Development Notes](./docs/plugin-development.md)
