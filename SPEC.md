# MKVForge: spec

Created 2026-11-18. Keep this short. Coding agents work from it, so update it when a decision changes.

## Goal
For Arezhik, on his own Macs: split full `.mkv` files into `.mka` (audio, subtitles, chapters) and remux a video-only `.mkv` with a matching `.mka`, in folder batches, using the installed `mkvmerge`.

## Sources
- Requirements: [docs/scaffold.md](docs/scaffold.md) (all sections confirmed 2026-11-18).
- Layout and visual contract: [docs/design/v1-layout-contract_v2.md](docs/design/v1-layout-contract_v2.md) (Design Bot, approved v2).

## Decisions
- Platform: macOS 15.0+, universal (arm64 + x86_64), SwiftUI, unsigned CI build, no App Sandbox, personal use.
- Bundle ID: `com.arezhik.MKVForge` (don't change it after it's installed).
- Input: folders chosen with Choose… buttons only. No drag and drop, Open…, Dock drops, or Open With. Top-level files only.
- Existing output: flagged on scan and never overwritten.
- External tool: `mkvmerge` from MKVToolNix (Homebrew paths, then `/Applications/MKVToolNix*.app`, then a Settings override in the app UI phase).

## Architecture
- `MKVForgeKit` package (`Sources/MKVForgeCore`): all logic that doesn't need AppKit, testable on Linux.
- `App/`: thin SwiftUI app. It feeds the core and shows progress.
- Engine rules: check `Task.checkCancellation()` in every long loop, write to a temporary name and rename only on success, and throttle progress to about 10 updates a second.

## Phases (one PR each)
1. **Setup** (this PR, issue #1): repo from the boilerplate, hybrid layout, CI with the universal macOS build, `.cursor/environment.json`, `docs/LESSONS.md`. The app opens one placeholder window that reports whether `mkvmerge` was found. Settings shows the same. Help > Export Debug Log works.
2. **Scanning and checks**: scanner, `--identify-json` parsing, validation rules, Split/Remux command builders; unit tests.
3. **Running**: `mkvmerge` execution, exit codes, temp-file rename, cancel after current, per-file errors and summary.
4. **Design**: done (docs/design/v1-layout-contract_v2.md).
5. **App UI**: the layout contract, Settings with the MKVToolNix location.
6. **Mac test**: Arezhik tests on real files; release 1.0.0.

### Definition of done for Phase 1
- [ ] `swift test` and `swift build` (strict) pass on Linux and macOS CI.
- [ ] The universal app builds in CI and the zip artifact launches.
- [ ] The window shows whether `mkvmerge` was found, and Help → Export Debug Log shows the launch and the tool path and version.

## Later phases
Nice-to-haves go here, or become low-priority `enhancement` issues. They don't go into the current PR.

## Out of scope
- …
