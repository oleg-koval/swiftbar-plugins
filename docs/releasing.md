# Releasing and Commit Rules

This repository uses `semantic-release` on `main`.

## What Triggers a Release

Release types are derived from Conventional Commits:

| Commit | Release |
| --- | --- |
| `fix:` | patch |
| `feat:` | minor |
| `perf:` | patch |
| `type!:` or `BREAKING CHANGE:` | major |

Examples:

```text
fix: correct free-space parsing on APFS volumes
feat: add GitHub Pages landing site
perf: cache hardware model lookup
feat!: drop legacy output sections
```

These commit types do not create a release on their own:

- `docs:`
- `test:`
- `ci:`
- `chore:`
- `refactor:`
- `style:`

## Release Workflow

On every push to `main`, the release workflow:

1. runs plugin verification on macOS
2. runs `semantic-release`
3. updates `CHANGELOG.md`
4. updates the plugin version in:
   - `# <xbar.version>...`
   - `PLUGIN_VERSION="..."`
5. creates a Git tag and GitHub release
6. uploads `system-monitor.5s.sh` as a release asset

## PR and Merge Discipline

To keep release automation predictable:

- use Conventional Commit subjects for commits
- use a Conventional Commit PR title
- prefer squash merges so the release signal stays clean on `main`

The repo enforces:

- commit message linting on pull requests
- semantic PR title checks

## Dry Run

Before changing release tooling:

```sh
npm ci
npm run release:dry-run
```
