## [1.2.5](https://github.com/oleg-koval/swiftbar-plugins/compare/v1.2.4...v1.2.5) (2026-04-22)

### Bug Fixes

* **install:** ship standalone SwiftBar entrypoint ([61f5caa](https://github.com/oleg-koval/swiftbar-plugins/commit/61f5caaa6972da9d45a0af792e397fce9869c13a))

## [1.2.4](https://github.com/oleg-koval/swiftbar-plugins/compare/v1.2.3...v1.2.4) (2026-04-21)

### Bug Fixes

* **install:** add dedicated SwiftBar folder ([78351c5](https://github.com/oleg-koval/swiftbar-plugins/commit/78351c5e7ee77233b39fe60b849946bede75f91c))

# Changelog

All notable changes to this project will be documented in this file.

The format follows Keep a Changelog, and versions follow Semantic Versioning.

## Unreleased

- Added a public OSS repository surface with root docs, community files, and contribution templates.
- Added GitHub Actions workflows for CI, release automation, commit discipline, and Pages deployment.
- Added semantic-release tooling to manage changelog updates, version sync, GitHub releases, and release assets.
- Added a GitHub Pages site for install, release, and contributor documentation.

## 1.2.3

- Added dark-mode-aware secondary text color handling.
- Kept the native macOS menu background and adjusted only plugin-rendered secondary labels.

## 1.2.2

- Added VPN summary details to the Network section.
- Show active VPN services when connected and list configured VPN clients when not connected.

## 1.2.1

- Fixed battery parsing on MacBooks by reading the internal battery row from `pmset`.
- Added remaining battery time to the overview and health sections.

## 1.2.0

- Added a Mac Health dashboard flow inspired by native cleanup utilities while staying within SwiftBar menu limits.
- Added a Today's Recommendation section with one prioritized next action.
- Added compact CPU, memory, disk, battery, network, and device overview sections.
- Added memory pressure and network throughput signals.

## 1.1.0

- Added Smart Triage with compact menubar status.
- Reworked dropdown flow around busy apps, health, signals, details, and actions.
- Routed complex actions through plugin subcommands for reliable SwiftBar execution.
- Made slow probes opt-in and reduced menu-open latency.
- Added visible plugin versioning.
