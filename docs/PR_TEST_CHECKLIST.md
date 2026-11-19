# PR #___ test checklist: <title>

App: MKVForge · Branch: `cursor/…` · Commit: `…` · Date: ____ · Mac: ____ · macOS: ____

Version bump: ____ (build __) to ____ (build __) (rule: patch / minor / major / none: docs or CI only). Arezhik confirms this with the merge.

Print this, or copy it into the PR. Mark each line Pass or Fail, and write notes for every Fail.
Arezhik approves the merge only after this sheet passes.

## Setup
- [ ] Pull the branch. Quit Xcode, delete DerivedData for MKVForge, open `App/MKVForge.xcodeproj`, then Run (⌘R).
- [ ] CI is green: Linux tests, macOS tests, and the universal app. The `MKVForge-universal.zip` artifact is attached.
- [ ] About MKVForge (app menu) and the debug log header show the new version and build. CHANGELOG.md has the entry.

## What this PR changes
1. [ ] Pass / Fail: <step> → <expected result>
2. [ ] Pass / Fail: …

## Regression checks (every PR)
- [ ] Dropping a file on the window or the Dock icon does nothing, and there is no Open… item. Folders come only from Choose… buttons (docs/scaffold.md).
- [ ] Every toolbar button and menu item does something, including Settings (⌘, and the toolbar button) (L4).
- [ ] Cancel and Cancel All stop right away, at every stage, and leave no partial output (L5).
- [ ] No source file on disk is ever deleted or overwritten (L6).
- [ ] Reveal in Finder works, and gives a clear message when the file is gone (L7).
- [ ] Minimize, restore, full screen, and close each window. It still responds afterwards (L8).
- [ ] Open a menu during a long run. No flicker (L9).
- [ ] The Xcode console shows no purple runtime warnings, such as "Publishing changes from within view updates", when you click controls with the mouse and with shortcuts (L10).
- [ ] After Cancel, Cancel All, and a run that finishes by itself, every toolbar button and menu item returns to the right enabled state without clicking anything else (L11).
- [ ] The scheme passes no leftover diagnostic environment variables (Product → Scheme → Edit Scheme → Run → Arguments), and the debug log header lists any toggles that are on (L21).
- [ ] Help → Export Debug Log saves to the Desktop, and the new feature's events are in it.
- [ ] With `mkvmerge` missing, a clear message appears and nothing crashes. With it installed, the debug log shows its path and version.

## Notes
________________________________________________________________
________________________________________________________________
