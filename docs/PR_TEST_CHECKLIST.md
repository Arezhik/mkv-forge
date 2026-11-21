# PR #___ test checklist: <title>

App: MKVForge · Branch: `cursor/…` · Commit: `…` · Date: ____ · Mac: ____ · macOS: ____

Version bump: ____ (build __) to ____ (build __) (rule: patch / minor / major / none: docs or CI only). Arezhik confirms this with the merge.

Print this, or copy it into the PR. Mark each line Pass or Fail, and write notes for every Fail.
Arezhik approves the merge only after this sheet passes.

## Setup
- [ ] Pull the branch. Quit Xcode, delete DerivedData for MKVForge, open `App/MKVForge.xcodeproj`, then Run (⌘R).
- [ ] Core tests in Terminal from the repo root: `swift test --scratch-path /tmp/mkv-forge-build 2>&1 | tail -3` → 0 failures. The scratch path keeps the build out of iCloud-synced folders (L30).
- [ ] CI is green: Linux tests, macOS tests, and the universal app. The `MKVForge-universal.zip` artifact is attached.
- [ ] About MKVForge (app menu) and the debug log header show the new version and build. CHANGELOG.md has the entry.

## What this PR changes
1. [ ] Pass / Fail: <step> → <expected result>
2. [ ] Pass / Fail: …

## Regression checks (every PR)
- [ ] Dropping a file on the window or the Dock icon does nothing, and there is no Open… item. Folders come only from Choose… buttons (docs/scaffold.md).
- [ ] Every toolbar button and menu item does something, including Settings (⌘, and the toolbar button) (L4).
- [ ] Cancel finishes the current file, then stops; nothing after it runs. Quitting mid-file with Quit stops right away and leaves no temp or partial file (L5, contract v2 §6, v2.1 addendum §1).
- [ ] No source file on disk is ever deleted or overwritten (L6).
- [ ] Reveal in Finder works, and gives a clear message when the file is gone (L7).
- [ ] Minimize, restore, full screen, and close each window. It still responds afterwards (L8).
- [ ] Open a menu during a long run. No flicker (L9).
- [ ] The Xcode console shows no purple runtime warnings, such as "Publishing changes from within view updates", when you click controls with the mouse and with shortcuts (L10).
- [ ] After Cancel, a run that finishes by itself, and a stopped scan, every toolbar button and menu item returns to the right enabled state without clicking anything else (L11).
- [ ] ⌘Q and closing the window while a batch runs show the `A batch is running` sheet: Finish Current File quits after the current file (no notification), Quit stops at once and leaves no temp or partial file, Cancel changes nothing. Idle or scanning, both quit at once, and closing the window quits even with Settings open (contract v2.1 addendum §1, G1).
- [ ] During a scan, the Scan row shows a spinner and `Scanning… N of M`; the mode switch, Choose…, checkboxes and the primary action are disabled; Esc stops the scan and brings back the previous rows and caption unchanged (contract v2.1 addendum §2, G2).
- [ ] The scheme passes no leftover diagnostic environment variables (Product → Scheme → Edit Scheme → Run → Arguments), and the debug log header lists any toggles that are on (L21).
- [ ] Help → Export Debug Log saves to the Desktop, and the new feature's events are in it.
- [ ] The Dock, Finder, Get Info and About MKVForge show the MKVForge icon (orange and purple tracks in a steel clamp), not the generic app icon (L33).
- [ ] With `mkvmerge` missing, a clear message appears and nothing crashes. With it installed, the debug log shows its path and version.
- [ ] Scan in Split, switch to Remux and back (picker and ⌘1/⌘2); scan in both modes and switch again; after a scan, Choose… a different folder; re-scan after deleting a file; right-click a row; repeat after a finished batch (Show in Finder on a Done row). Nothing crashes, and the row selection clears on every mode switch (L31).
- [ ] Split into a folder, switch to Remux with that folder as Audio and scan within a minute: the new `.mka` files aren't `still changing`. An `.mka` copied in by hand just before the scan still is (L32).
- [ ] Remux with full source MKVs in the Video folder: rows are Ready with `Uses video only, ignores …`, and `mkvmerge -J` on the result shows one video track plus the `.mka`'s tracks (L32).

## Notes
________________________________________________________________
________________________________________________________________
