## Summary
<!-- What changed and why, in a few lines. Closes #N. One issue per PR when you can. -->

## Version
Version bump: X.Y.Z (build N) to X.Y.Z (build N) (rule: patch / minor / major / none: docs or CI only)
<!-- If another PR merged a bump first: scripts/bump-version.sh --rebase origin/main <rule> -->

## Checked where
- Linux (cloud agent): `bash scripts/bump-version.sh --check`, `bash scripts/check-project.sh`, `swift test` and `swift build` with `-strict-concurrency=complete -warnings-as-errors`: pass / fail
- macOS CI only: app build, universal binary, anything that needs AppKit, SwiftUI, or other Apple-only frameworks
- Not tested on real input: <!-- say so plainly, or write "none" -->

## Mac test steps (Arezhik)
<!-- Copy the setup and regression lines from docs/PR_TEST_CHECKLIST.md, then add numbered steps for this change. -->
1. Pull the branch. Quit Xcode, delete DerivedData for MKVForge, open `App/MKVForge.xcodeproj`, then Run (⌘R).
2. About MKVForge shows the new version and build.
3. …

Arezhik tests on a Mac and approves the merge. CI alone is not approval.
