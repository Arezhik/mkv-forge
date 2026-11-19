# Lessons built into this project

These came from building and testing earlier macOS apps with the same layout. Code comments, AGENTS.md, and docs/PR_TEST_CHECKLIST.md refer to them by number. Add new lessons at the end. Don't renumber.

| # | Lesson | What it means here |
|---|---|---|
| L1 | A package with the same name as the Xcode project, in the same folder, makes Xcode report the package products as missing. | The package is `MKVForgeKit` at the root. The project is `App/MKVForge.xcodeproj`. CI's "Resolve local package" step fails if the products don't bind. |
| L2 | Setting `ARCHS` for Debug broke Xcode's My Mac run (incompatible target). | Debug builds only the active arch. Release is universal. CI checks both. |
| L3 | Dock drops opened a second window, and folders dropped on the Dock were refused. | One queue window takes every drop and Open With. Folders are a document type at Alternate rank and are walked with their subfolders. |
| L4 | The Settings toolbar button used `showSettingsWindow:`, which macOS ignores now. | Use `SettingsLink`. Every toolbar item is also a menu item, and each one gets clicked in the Mac test. |
| L5 | Cancel only worked after the slow first step (reading and decoding) finished. | Every stage checks for cancellation, and Cancel deletes partial output. |
| L6 | Users wanted to clear finished rows without any risk to their files. | Clear Finished and the row ✕ touch only finished rows and never delete files. An empty list shows the drop screen. |
| L7 | Reveal in Finder did nothing for a moved file. | Check that the file exists first, use `activateFileViewerSelecting`, and log the call. |
| L8 | Replacing a window's delegate with a Swift object crashed on minimize, restore, and state restoration (unrecognized selector). | Observe `NSWindow` notifications. If you must veto a close, use the forwarding `SafeWindowDelegateProxy`. |
| L9 | Menus flickered during long runs because the menu bar re-evaluated on every progress tick. | Progress is throttled to about 10 a second. Menus read `CommandFlags`, which publish only when a value changes. |
| L10 | "Publishing changes from within view updates" warnings came from controls writing the model during a view update. | Controls keep local `@State` and write the model on the next run-loop turn. |
| L11 | A toolbar button stayed disabled after Stop because it read a nested `ObservableObject` through its parent. | Views that show `CommandState` observe it directly. |
| L12 | Asking once per file in the middle of a batch is annoying, and the default choice was misremembered. | Ask once per batch with "Apply to all", or follow Settings. Write the default in SPEC.md and test it. |
| L13 | The exported debug log was the main way to diagnose bugs on testers' Macs. | Help → Export Debug Log writes a redacted log with a machine-facts header. It never includes user content. |
| L14 | A sandboxed app can read a dropped file but can't write a new file next to it. | The sandbox stays off, and CI fails if the entitlement appears. Revisit this if the app ever goes to the App Store. |
| L15 | An external tool's newer release failed on an Intel Mac, and a Finder-launched app has a short `PATH`. | Fixed search order, log command, exit code, and stderr, kill on cancel, and record the tool version in the log header. |
| L16 | Walking folders on a network share was slow. | Keep folder walks and file probing off the main thread. |
| L17 | Two schemes whose names differed only by case kept showing as modified on a Mac. | No tracked paths may differ only by case. `scripts/check-project.sh` checks it. |
| L18 | The cloud agent environment had an older Swift than CI, because its install script only ran when Swift was missing. | Swift 6.2.4 is pinned in CI, `.cursor/environment.json`, and AGENTS.md. The install script checks the exact version. |
| L19 | Cloud VMs have no XcodeGen, and a regenerated project rewrote every object ID, which broke other PRs. | The checked-in pbxproj is the source of truth. Edit only the lines you need, and keep project.yml matching. `scripts/check-project.sh` compares them. |
| L20 | Two open PRs bumped to the same build number, and whichever merged second needed a re-bump. | `bump-version.sh --rebase origin/main <rule>` recomputes from `main`. CI fails a PR whose build number isn't above `main`'s. |
| L21 | A diagnostic variable left in the shared scheme made a test report look like a regression. | Don't keep diagnostic variables in the shared scheme. Print toggles in the debug log header. |
| L22 | A SwiftUI menu feature needed a newer macOS than the deployment target. | Check availability against macOS 15.0 before using an API. |
| L23 | Apple-only frameworks can't run on the Linux agents or the Linux CI job. | Put them behind a protocol in the app layer, or behind `#if canImport`, so the logic stays testable on Linux. |
| L24 | Agents on Linux couldn't run spikes that needed Apple frameworks, and some PRs didn't say what was checked where. | Each PR says what ran on Linux and what only macOS CI or a Mac test covers. |
| L25 | Large PRs that closed several issues sat open the longest and collided with other PRs. | One issue per PR when you can. Stack PRs when one depends on another. |
| L26 | One PR was merged before it was tried on a real file. | Say plainly in the PR when something wasn't tested on real input. |
| L27 | Under the C/POSIX locale (an app opened from Finder, the swift Docker image), mkvmerge cut file names at the first non-ASCII byte and still exited 0. | Every tool run gets `LC_ALL` set to a UTF-8 locale that exists: `en_US.UTF-8` on macOS, `C.UTF-8` on Linux (`ToolEnvironment`). The real-mkvmerge test runs under `LC_ALL=C` and uses a name with `é`. |
