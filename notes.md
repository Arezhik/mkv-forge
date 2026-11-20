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

## 2026-11-18 ~9:30 PM MT: PR #25 (Phase 1: Setup)
- CI: green (Linux tests, macOS tests, macOS universal app). Arezhik's Mac test: 5 of 5 passed, including Homebrew and app-bundle lookup.
- Decision: squash-merged as d3aae33, 0.1.0 (build 1). Closes #1.

## 2026-11-18 ~11:20 PM MT: Phase 2 (Scanning and checks, #2)
- Research findings Arezhik approved (Q1–Q9): the identify call is `mkvmerge -J` (`--identify-json` doesn't exist); `-J` exits 0 for unreadable files, so the scan reads its JSON; stripping writes `und` and every flag 0 (Matroska reads missing values as `eng` and default on); Remux clears the video track the same way; `--no-date` on both commands; four extra flags (no video track, .mka with no audio or subtitles, not Matroska inside, Output folder = Video folder); exact case-sensitive base names; 0.2.0 (build 2).
- Core only: no app file changes, so nothing new shows in the window until #5.
- A Settings choice of mkvmerge that can't be found is "not found", with no fallback (AGENTS.md L15).
- Real-mkvmerge test: a small file generated at test time; runs on Linux CI (mkvtoolnix 82.0), skips on macOS CI. Also passed on the box with 103.0.
- `bump-version.sh`, README.md and AGENTS.md: `major` no longer says "or a new phase".

## 2026-11-19 ~9:00 AM MT: Phase 3 (Running, #3)
- Research findings Arezhik approved (Q1–Q11, plus the pbxproj rule): mkvmerge prints warnings and errors on stdout (L28) and recreates a missing output folder with exit 0 (L29); a killed run leaves a file that reads as Matroska, so output goes to a hidden temp `.<base>.partial.<ext>` renamed with `FileManager.moveItem`, which never replaces a file.
- Each file is re-checked right before it runs (Output folder, inputs, output absent, fresh `mkvmerge -J` equals the scan). Exit 0 = Done, 1 = Done · warning, 2 or anything else = Failed; the batch keeps going. Cancel finishes the current file; a hard stop kills mkvmerge and deletes the temp.
- `JobStatus` reshaped to the layout contract's statuses; summary and status text live in the core.
- No mkvtoolnix on the macOS CI test job (Q8 = no); real runs are tested on Linux CI and in the Mac `swift test` step. No window changes until #5.
- AGENTS.md, README.md and LESSONS L19: never hand-edit project.pbxproj; App/project.yml plus `xcodegen generate` is the source of truth (bump-version.sh's version lines are the only exception; Linux agents stop and say so in the PR). Existing output is never overwritten (no Apply-to-all prompt).
- Pending follow-up PR: App/project.yml's header comment still calls it a "backup recipe".
- 0.3.0 (build 3).

<!-- Template for each entry:
## YYYY-MM-DD ~H:MM PM MT: PR #N (what it does)
- Agent: bc-…, branch cursor/…
- CI: green/red (run link)
- Arezhik's test: pass/fail, with the checklist items that failed
- Decision: merged (commit) / waiting / logged as issue #N
-->
