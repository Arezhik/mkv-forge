# Changelog

All notable changes to MKVForge. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/), MAJOR.MINOR.PATCH.

Every merged PR that changes the shipped app bumps the version in the same PR with `scripts/bump-version.sh patch|minor|major`, which also adds 1 to the build number and adds a stub section here. Fill it in with one line per user-visible change, under Added, Changed, Fixed, or Removed, with the PR or issue number. Docs-only and CI-only PRs don't bump.

## [Unreleased]

## [0.2.0] - 2026-11-18 (build 2)
### Added
- Scanning and checks for Split and Remux in the core package (#2): top-level folder scan, exact base-name pairing, every validation rule from docs/scaffold.md, `mkvmerge -J` parsing, and the Split and Remux command builders. Nothing in the app window changes until the App UI phase (#5).
### Changed
- `scripts/bump-version.sh`, README.md and AGENTS.md: `major` means a major enhancement or breaking change, not a new phase.

## [0.1.0] - 2026-11-18 (build 1)
### Added
- Project created with macos-swift-app-boilerplate.sh (#1): hybrid layout, CI with the universal macOS build, one placeholder window that shows whether mkvmerge was found, Settings, and Help > Export Debug Log. No drag and drop or Open… (folders come from Choose… buttons in a later phase).
