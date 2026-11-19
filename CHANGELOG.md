# Changelog

All notable changes to MKVForge. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [Semantic Versioning](https://semver.org/), MAJOR.MINOR.PATCH.

Every merged PR that changes the shipped app bumps the version in the same PR with `scripts/bump-version.sh patch|minor|major`, which also adds 1 to the build number and adds a stub section here. Fill it in with one line per user-visible change, under Added, Changed, Fixed, or Removed, with the PR or issue number. Docs-only and CI-only PRs don't bump.

## [Unreleased]

## [0.3.0] - 2026-11-19 (build 3)
### Added
- Running Split and Remux in the core package (#3): one file at a time with the installed mkvmerge, exit 0 = Done, 1 = Done · warning, 2 = Failed, and the batch keeps going after a failure. Output goes to a hidden temp file that is renamed only on success and never replaces an existing file. Each file is re-checked right before it runs. Cancel finishes the current file, then stops. Per-file reasons and the batch summary use the layout contract's text. Nothing in the app window changes until the App UI phase (#5).
### Changed
- AGENTS.md, README.md and docs/LESSONS.md L19: never hand-edit project.pbxproj; App/project.yml plus `xcodegen generate` is the source of truth. AGENTS.md: existing output is never overwritten. docs/LESSONS.md: L28 and L29.

## [0.2.0] - 2026-11-18 (build 2)
### Added
- Scanning and checks for Split and Remux in the core package (#2): top-level folder scan, exact base-name pairing, every validation rule from docs/scaffold.md, `mkvmerge -J` parsing, and the Split and Remux command builders. Nothing in the app window changes until the App UI phase (#5).
### Changed
- `scripts/bump-version.sh`, README.md and AGENTS.md: `major` means a major enhancement or breaking change, not a new phase.

## [0.1.0] - 2026-11-18 (build 1)
### Added
- Project created with macos-swift-app-boilerplate.sh (#1): hybrid layout, CI with the universal macOS build, one placeholder window that shows whether mkvmerge was found, Settings, and Help > Export Debug Log. No drag and drop or Open… (folders come from Choose… buttons in a later phase).
