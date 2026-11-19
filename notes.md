# MKVForge notes

Dated log of decisions, PRs, test results, and open questions. Newest at the bottom.
Times in Mountain time (MT).

- Repo: <https://github.com/Arezhik/mkv-forge>
- Spec: SPEC.md
- Rules at kickoff: AGENTS.md and docs/LESSONS.md (from macos-swift-app-boilerplate)
- Cloud agent environment: id ee6550b7-e3bb-11f1-b825-9a9eda18fdae · build: draft bld-20261119-73b129aa-61f4-445f-aa2b-27335cb7e4a4 (saved by Arezhik 2026-11-18; check the saved build id in Cursor) · Swift 6.2.4 + mkvtoolnix 82.0

## 2026-11-18: Project created
- Generated with macos-swift-app-boilerplate.sh (name MKVForge, bundle ID com.arezhik.MKVForge, macOS 15.0+).
- Requirements: docs/scaffold.md. Layout: docs/design/v1-layout-contract_v2.md (approved v2).
- Starter trimmed for MKVForge: no drag and drop, Open…, Dock drops, or Open With (FileIntake and the document types removed); one placeholder `Window` scene that reports the mkvmerge check.

<!-- Template for each entry:
## YYYY-MM-DD ~H:MM PM MT: PR #N (what it does)
- Agent: bc-…, branch cursor/…
- CI: green/red (run link)
- Arezhik's test: pass/fail, with the checklist items that failed
- Decision: merged (commit) / waiting / logged as issue #N
-->
