# Rules for this repo (macOS Swift app)
Read this before the first change. The reasons behind each rule are in docs/LESSONS.md (L-numbers below).

## Where code goes
- Native Swift/SwiftUI macOS app, universal (arm64 + x86_64), unsigned, not sandboxed (L14). Minimum macOS 15.0.
- Hybrid layout: the Swift package `MKVForgeKit` at the repo root holds the logic (module `MKVForgeCore`). The thin SwiftUI app is `App/MKVForge.xcodeproj`. Don't rename the package to the app's name, and don't move the `.xcodeproj` out of `App/` (L1).
- `MKVForgeCore` imports no AppKit, SwiftUI, Vision, or AVFoundation, so `swift test` runs on Linux. If core code needs an Apple-only framework, put it behind a protocol and implement it in the app layer, or wrap it in `#if canImport(...)` and keep a Linux-testable path (L23).
- App layer only: AppDelegate, window notifications, views, panels, NSWorkspace. Keep it thin and move anything testable into the package.
- Use only APIs that exist on macOS 15.0. Gate anything newer with `if #available` and keep a fallback (L22).

## Where you run
- You run on Linux (Ubuntu 24.04) with Swift 6.2.4 preinstalled in the saved Cursor environment. Run `swift --version` first and confirm it says 6.2.4. Don't install or upgrade Swift. If it's wrong, stop and report it (L18).
- You can't run Xcode, `xcodebuild`, the app, or Apple-only frameworks. The macOS CI jobs are the real app build. Say in the PR which checks ran on Linux and which only CI or a Mac can cover (L24).
- The Linux gate is CI's Linux job: `bash scripts/bump-version.sh --check`, `bash scripts/check-project.sh`, then `swift test` and `swift build`, both with `-Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`. Run all of them before you open the PR.

### Local Linux VM (no Swift installed)
- Apply these rules only when `command -v swift` finds nothing (or when `xcodegen` exists at `/workspace/macos-dev-test/projects/mkv-forge/icon/tools/XcodeGen-2.48.0/.build/x86_64-unknown-linux-gnu/release/xcodegen`). Everywhere else, the rules above apply unchanged.
- Edit source files directly in the working tree. Don't generate `apply_changes.py` or `verify.diff`.
- Run `./scripts/verify-linux.sh` from a clone folder named `mkv-forge` (per L33). It regenerates the Xcode project with XcodeGen when Swift is absent and `App/project.yml` exists, then runs `scripts/check-project.sh` and `scripts/bump-version.sh --check`. Inspect `git diff` so only intended changes are staged. Don't run `swift test`, `swift build`, or `xcodebuild` here; they run in GitHub's macOS and Linux CI after push.
- To add a new Core type and its test, run `./scripts/scaffold-swift.sh <Name> [Subfolder]` first instead of creating the files by hand.
- Push to a feature branch `grok/<slug>`. Run `gh run list` only if `gh auth status` succeeds; otherwise note that CI should be checked on GitHub.

## Project files
- Never hand-edit `App/MKVForge.xcodeproj/project.pbxproj`. To add, rename, or remove an app `.swift` file, or change any other project setting, update `App/project.yml` and run `xcodegen generate` in `App/`, then commit both files. The Linux VMs have no XcodeGen, so a change that needs it is made on a Mac; on Linux, stop and say so in the PR instead of editing the pbxproj. The only exception is `scripts/bump-version.sh`, which changes the version lines. `scripts/check-project.sh` fails if the two files drift (L19).
- Since the app icon PR (0.4.1), the committed project.pbxproj is XcodeGen 2.48.0 output. Regenerate from a clone folder named `mkv-forge` (the local package's folder reference takes the folder's name). A second `xcodegen generate` must change nothing, and the project must have no `TEMP_` object IDs (L33).
- No two tracked paths may differ only by letter case (Macs use a case-insensitive disk). Name extra schemes and targets so they differ by more than case (L17).
- Diagnostic environment variables don't go in the shared scheme. Read them from the environment, and print their state in the debug log header (L21).

## Swift and SwiftUI rules
- Build with `-strict-concurrency=complete -warnings-as-errors`. Keep the core Sendable-clean.
- Every long loop checks `Task.checkCancellation()`, including reading, decoding, and external tools. Cancel deletes partial output and temp files (L5).
- Never write `@Published` or observed state during a view update. Controls keep local `@State` and write the model on the next run-loop turn (`DispatchQueue.main.async` or `Task { @MainActor in }`) (L10).
- Throttle progress to about 10 updates a second (`AppModel.report`). Menu commands and toolbar enablement read only `CommandFlags`, which publish only when they change (L9).
- A view that shows `CommandState` (or any other nested `ObservableObject`) must observe it directly with `@ObservedObject`. Reading it through the parent model doesn't redraw when only the child changes (L11).
- Don't replace a window's delegate. Observe `NSWindow` notifications (`WindowEvents`). If you must veto a close, use `SafeWindowDelegateProxy` and list every method you implement (L8).
- Don't set window properties from `layout()`.
- Every toolbar item is also in the menu bar. Settings opens with `SettingsLink` or `openSettings` (L4).
- No drag and drop, no Open…, no Dock drops or Open With. Folders come only from Choose… buttons, and a scan reads only the top level of each folder (docs/scaffold.md). Slow folder scans stay off the main thread (L16).
- Never delete source files on disk. Queue behavior (checkboxes, flagged rows, the finish summary) follows docs/design/v1-layout-contract_v2.md (L6).
- Existing output is flagged at scan and never overwritten (docs/scaffold.md). If an output appears while its file is running, that file fails and the new copy is deleted. v1 has no overwrite prompt.
- Reveal in Finder checks the file exists first, uses `activateFileViewerSelecting`, and logs the call (L7).
- External tool (`mkvmerge`): search `/opt/homebrew/bin`, `/usr/local/bin`, `/Applications/MKVToolNix*.app/Contents/MacOS`, then `PATH`. Log the command, exit code, and stderr (cut at 2,000 characters). Show a clear message when it's missing. Cancel kills a running process. If Settings let the user choose a copy, a chosen copy that's missing is an error, not a silent fallback (L15).
- Running mkvmerge (`BatchRunner`): one file at a time. Right before each file, check that the Output folder and inputs still exist, the output is still absent, and a fresh `mkvmerge -J` matches the scan; mkvmerge silently recreates a missing output folder (L29). mkvmerge writes a hidden temp `.<base>.partial.<ext>` in the Output folder, renamed with `FileManager.moveItem` (never replaces a file) only on exit 0 or 1. Its warnings and errors are on stdout, not stderr (L28). Cancel finishes the current file, then stops; a hard stop kills mkvmerge and deletes the temp.
- Log through `DebugLog.shared.record(...)`: launch, settings, each file's start, finish, and error, window events, saves, and Reveal. No user content. Home becomes `~` (L13).

## Scope, tests, and review
- Fix only the issue you were given, one issue per PR where you can. Note other problems in the PR description instead of fixing them. Keep later-phase work out (L25).
- Add a test with every bug fix, and show that it fails without the fix. Use small generated fixtures. Real media stays out of git (`Tests/MKVForgeCoreTests/Fixtures/private/` is ignored).
- Fill in `.github/pull_request_template.md`. List the Mac test steps from `docs/PR_TEST_CHECKLIST.md`. Arezhik tests on a Mac and approves every merge. CI alone is not approval.
- Say plainly when something wasn't tested on real input (L26).
- Mac test steps that run SwiftPM use `swift test --scratch-path /tmp/mkv-forge-build`, because Arezhik's clone is in iCloud-synced `~/Documents`, where codesign rejects the test bundle. Xcode ⌘R is not affected (L30).

## Versioning
- SemVer. In the same PR, run `scripts/bump-version.sh patch` for a bug fix or small tweak, `minor` for a new feature, or `major` for a major enhancement or breaking change. A new phase is usually `minor`; 1.0.0 is the v1 release. Docs-only and CI-only PRs don't bump.
- The build number goes up by 1 with every bump and is never reused. Don't edit the version by hand; the script keeps project.pbxproj, project.yml, and CHANGELOG.md in sync.
- If `main` moved after your bump (another PR merged with a bump), run `scripts/bump-version.sh --rebase origin/main patch|minor|major` to recompute from `main`'s version, then fix the CHANGELOG heading it reports. CI fails a PR whose build number isn't above `main`'s (L20).
- Fill in the CHANGELOG.md entry. Put `Version bump: old to new (rule)` in the PR description. Arezhik confirms it at merge.

## This project
- Repo `Arezhik/mkv-forge`. App MKVForge, bundle ID `com.arezhik.MKVForge`, macOS 15.0+, Swift 6.2.4.
- Package `MKVForgeKit` (module `MKVForgeCore`, tests `MKVForgeCoreTests`). Xcode project `App/MKVForge.xcodeproj`, scheme `MKVForge`.
- Version: `scripts/bump-version.sh --current` (started at 0.1.0, build 1). History: CHANGELOG.md. Decision log: notes.md.
- Cloud agents: the saved Cursor environment for this repo comes from `.cursor/environment.json` (Swift 6.2.4, plus mkvtoolnix). Its id is in notes.md.
- Requirements: docs/scaffold.md (confirmed with Arezhik 2026-11-18). UI layout: docs/design/v1-layout-contract_v2.md (Design Bot, approved v2) plus docs/design/v1-layout-contract_v2.1-addendum.md (approved 2026-11-19: quit or close while a batch runs, and scanning); their mockup PNGs and PDF stay with Design Bot and are not in the repo (docs/design/README.md). Any UI change follows the contract; a layout it doesn't cover needs a contract update first.
- Phases (one per PR): 1 Setup, 2 Scanning and checks, 3 Running, 4 Design (done), 5 App UI, 6 Mac test (docs/scaffold.md, Next Implementation Steps).
- Scope: SPEC.md. Test sheet template: docs/PR_TEST_CHECKLIST.md. Tester guide: TESTERS.md. Lessons: docs/LESSONS.md. CI artifact: `MKVForge-universal.zip`.

## GitHub Issue & Comment Format (Token-Efficient Spec)
When creating, rewriting, or commenting on GitHub issues (including triage, design notes, or research), **never post conversational prose**. Preserve the original human description at the top if editing an existing issue, and append or post strictly in this compact schema:

### For Issue Rewrites / Specs (`## Agent Spec`)
```markdown
## Agent Spec
### Goal
<1–2 sentences: exact behavioral change>

### Rules & Logic
- <Deterministic rule or edge-case behavior>

### UI / UX
- <Control type, exact label, default state, placement — or "None">

### Test Cases (Input -> Expected)
- `<Input>` -> `<Expected result / output>`

### Constraints
- <What must NOT change>
```

### For Research / Triage / Design Comments
Keep comments under 15 lines using only:
- **Relevant Files:** `<path/to/File.swift>` (`SymbolName`)
- **Findings / Edge Cases:** <1–3 terse bullets>
- **Proposed Approach:** <2–4 terse bullets>
- **Open Questions:** <Bullet list, or "None">
