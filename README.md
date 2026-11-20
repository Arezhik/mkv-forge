# MKVForge

A native macOS app (SwiftUI, macOS 15.0 or later, universal for Apple silicon and Intel).
It splits `.mkv` files into `.mka` (audio, subtitles, chapters) and remuxes video-only `.mkv` files with a matching `.mka`, in folder batches, using `mkvmerge`. Requirements: docs/scaffold.md. Layout: docs/design/v1-layout-contract_v2.md.

## Use the window
- Phase 1 (setup): the window is a placeholder that shows whether `mkvmerge` was found. Split and Remux come in later phases.
- Folders are chosen with **Choose…** buttons. There is no drag and drop or Open….
- **Settings** (⌘,) shows where `mkvmerge` was found.
- **Help → Export Debug Log…** saves a log to the Desktop to send with a bug report.

## Needs mkvmerge
MKVForge runs `mkvmerge`, which isn't part of macOS. Install it with Homebrew (`brew install mkvtoolnix`) or from https://mkvtoolnix.download/. The app looks in `/opt/homebrew/bin`, `/usr/local/bin`, `/Applications/MKVToolNix*.app/Contents/MacOS`, then `PATH`. Record the version you tested in TESTERS.md, and test an Intel Mac early (a tool's newer release has failed on Intel while the older one worked; docs/LESSONS.md L15).

## Open it in Xcode and press Run
1. Quit Xcode. In the repository folder, delete `.build` if you see one, then run `rm -rf ~/Library/Developer/Xcode/DerivedData/MKVForge-*`.
2. Double-click **`App/MKVForge.xcodeproj`**. Don't open `Package.swift`; that's the core library.
3. If Xcode asks whether to trust the project, choose Trust, and wait for the package to load.
4. Check that the scheme says **MKVForge** and the destination says **My Mac**, then press ⌘R.

The project is set to **Sign to Run Locally**, so no Apple Developer team is needed. If Xcode asks for one, select the MKVForge target, open Signing & Capabilities, and choose **Sign to Run Locally**.

### Why the project is set up this way
- The core logic is a Swift package named **MKVForgeKit** at the repository root, with no AppKit or SwiftUI, so `swift test` runs on Linux and in cloud agents.
- The Xcode project is in `App/`, one folder down, and has a different name from the package. Xcode's window reports the package products as missing when the two share a name and a folder.
- Debug builds only the chip in your Mac. Release builds both arm64 and x86_64.
- The app isn't sandboxed, so it can write output next to the input file.
- `App/project.yml` and [XcodeGen](https://github.com/yonaskolb/XcodeGen) are the source of truth for the Xcode project. Never hand-edit `project.pbxproj`: change `App/project.yml`, run `xcodegen generate` in `App/` on a Mac, and commit both. The only exception is `scripts/bump-version.sh`, which edits the version lines. Open the checked-in `App/MKVForge.xcodeproj` to build.

## Download the app that GitHub built
1. On GitHub, open **Actions** and choose the latest green **CI** run.
2. Under **Artifacts**, download **MKVForge-universal.zip** and unzip it.
3. The app isn't signed or notarized. Right-click it and choose **Open**, or go to **System Settings → Privacy & Security** and click **Open Anyway**. If macOS says the app is damaged, run `xattr -dr com.apple.quarantine /path/to/MKVForge.app`.

## Versioning
The version is MAJOR.MINOR.PATCH (shown in About MKVForge), plus a build number that goes up by 1 on every merged PR. Bump it in the same PR as the change with `scripts/bump-version.sh patch|minor|major`: patch for a bug fix or small tweak, minor for a new feature, and major for a major enhancement or breaking change (a new phase is usually minor). Docs-only and CI-only PRs don't bump. Each version gets an entry in CHANGELOG.md.

## For developers
```bash
swift test      # the core package, on macOS or Linux
swift build
```
- On a Mac whose clone is in an iCloud Drive folder (such as `~/Documents` or `~/Desktop`), run `swift test --scratch-path /tmp/mkv-forge-build`, or keep the clone in a folder iCloud doesn't sync, such as `~/Developer`. Otherwise codesign rejects the test bundle (docs/LESSONS.md L30).
- `SPEC.md` has the scope and the definition of done for the current phase.
- `AGENTS.md` has the rules for coding agents. Read it before the first change.
- `scripts/bump-version.sh --check` confirms the version agrees everywhere (CI runs it).
- `docs/PR_TEST_CHECKLIST.md` is the template for each PR's printable test sheet.
- `TESTERS.md` is the guide for friends who test builds.
