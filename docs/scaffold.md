# MKVForge — macOS App Scaffold

**Repo:** [Arezhik/mkv-forge](https://github.com/Arezhik/mkv-forge)
**Status:** In review with Arezhik, section by section. Confirmed: Overview, Naming Convention (2026-11-18).

## Overview

MKVForge is a native universal macOS app (Apple silicon + Intel) that automates two MKVToolNix workflows in batch: **splitting** full MKVs into clean audio/subtitle/chapter `.mka` files, and **remuxing** encoded video-only MKVs with their matching `.mka` files into finished MKVs.

Two independent workflows (tabs):

**Workflow 1 — Split (to MKA)**
Scan a source folder for MKVs. For each one, write a single clean `.mka` to a user-chosen output folder containing all audio tracks, all subtitle tracks and the chapters, with every tag and metadata field from the source MKV stripped.

**Workflow 2 — Remux**
Match encoded video-only `.mkv` files with the `.mka` files that share their exact base name, and remux each pair into a finished `.mkv` with that same base name.

## Naming Convention (matching key) — confirmed

- **v1:** the source file's base name (filename without extension) is the only source of truth. The app does not parse, rename or reformat names.
- Split output: `<source base name>.mka`.
- Remux: a `.mkv` and `.mka` pair only when their base names match exactly; output is `<base name>.mkv`.
- Typical names follow `Name - S##E## - title` (TV) or a movie title, but v1 does not depend on that pattern.

| Type | Extension | v1 role |
|------|-----------|---------|
| Video | `.mkv` | Encoded video-only input (Workflow 2) |
| Audio + subs + chapters | `.mka` | Output of Workflow 1, input of Workflow 2 |

**Later (not v1):**
- Detect movie vs TV series, default each to a standard naming layout, and suggest file renames.
- Split into separate `.aac`, `.srt` and chapter files, and accept them as Remux inputs, if ever needed.
- v1 Remux ignores loose `.aac`, `.srt`/`.en.srt` and `.chapters.txt` files.

## Workflow 1: Split — confirmed 2026-11-18

The action is called **Split** everywhere in the app (heading, button, menu item, logs), to pair with **Remux**.

### Source / Output
- Source folder: full MKVs containing video, audio, subtitles and chapters. v1 scans the **top level only**; child folders are a later feature if needed.
- Output folder: clean `.mka` files named `<source base name>.mka`.

### Steps
1. User picks the source folder and the output folder.
2. User clicks **Scan**, and the app lists every `.mkv` at the top level of the source folder.
3. For each file, the app identifies its audio, subtitle and chapter content (`mkvmerge --identify-json`).
4. **Existing output:** on scan or re-scan (when the source folder syncs), any file whose `<base name>.mka` already exists in the output folder is flagged so the user can see a copy exists. Existing files are never silently overwritten.
5. User reviews the queue and can skip items.
6. User clicks **Split**.
7. The app runs `mkvmerge` to write a clean `.mka` with only the audio, subtitles and chapters.
8. **Errors:** if a file fails, it is marked failed with its error and the rest of the batch keeps going. A summary is shown at the end.

### Track rules (v1)
- Keep **all** audio tracks and **all** subtitle tracks, plus chapters.
- Drop the video track.
- Strip **all** tags and metadata: global tags, track tags, track names, language codes, default/forced flags, and anything else.
- Picking specific audio/subtitle tracks when a file has several is **deferred** until Arezhik clarifies the selection rules.

## Workflow 2: Remux — confirmed 2026-11-18

### Source / Output
- Video folder: encoded video-only `.mkv` files.
- MKA folder: `.mka` files from Split (audio, subtitles, chapters).
- Output folder: finished `<base name>.mkv` files.
- v1 scans the **top level only** of each folder.

### Steps
1. User picks the video, MKA and output folders.
2. User clicks **Scan sources**. The app matches files by exact base name and marks each title **Ready** (video + MKA present) or **Issue**.
3. Issues are flagged and the user is informed:
   - missing video or MKA, or duplicate base names;
   - `<base name>.mkv` already exists in the output folder (never silently overwritten);
   - the video `.mkv` contains audio or subtitle tracks (not video-only).
4. User reviews the queue and can deselect items.
5. User clicks **Remux**.
6. The app runs `mkvmerge` for each Ready title.
7. **Errors:** if a file fails, it is marked failed with its error and the rest of the batch keeps going. A summary is shown at the end.

### Track handling rules (v1)
- Video track from the `.mkv`; all audio, all subtitles and chapters from the `.mka`.
- Track order: video, then audio, then subtitles, then chapters.
- The finished `.mkv` has **no tags** (global, track or any other).
- Language codes and default/forced flags are **left unset** in v1.

### Later features (confirmed)
- Override a "video file has extra tracks" flag and remux anyway, taking only the video track from that file plus the `.mka`.
- Set language codes and default/forced flags once Arezhik clarifies the rules.

## High-Level Architecture — confirmed 2026-11-18

### Technology
- SwiftUI, **macOS 15+**, universal binary (arm64 + x86_64).
- Same layout as PGS2SRT and MP4SubRip: all logic (scanning, matching, flagging, `mkvmerge` command building) in a root SPM core package with no AppKit/SwiftUI, testable on Linux; thin SwiftUI App layer on top.
- Uses the **installed** MKVToolNix CLI, `mkvmerge` only (`mkvextract` not needed). Lookup order: `/opt/homebrew/bin`, `/usr/local/bin`, then the MKVToolNix GUI app in `/Applications`. If not found, the app says so, and **Settings lets the user pick the MKVToolNix location** manually. Bundling may come later.
- Personal use on Arezhik's own Macs, outside the App Store; no App Sandbox for now.

### Main Modules

```
Core (SPM, no UI)
├── Models
│   ├── TitleGroup          // matched set or single source file
│   ├── SourceFolders
│   └── Job / QueueItem
├── FileScanner             // top-level folder scan, matches by base name
├── Validator               // completeness, existing output, extra tracks
├── MKVToolNixLocator       // default paths + user-chosen override
├── MKVMergeRunner          // builds and executes mkvmerge commands
└── QueueManager            // progress, cancellation, per-file errors, summary
App (SwiftUI)
├── TabView
│   ├── SplitTab            // Workflow 1
│   └── RemuxTab            // Workflow 2
├── SourceSetupView / QueueView / DetailView / ProgressView
├── SettingsView            // MKVToolNix location, other settings
└── Persistence             // UserDefaults: settings and selected folders, remembered between launches
```

### Data Model Sketch

```swift
struct TitleGroup: Identifiable {
    let id: UUID
    let baseName: String
    var sourceURL: URL?       // full MKV (Workflow 1) or video MKV (Workflow 2)
    var mkaURL: URL?          // output MKA (Workflow 1) or input MKA (Workflow 2)
    var status: Status
    var issues: [String]
    var selected: Bool
}
```

### Deferred
- Split/Remux **profiles** dropped from v1. File as a later GitHub issue when the app's phases are created (pairs with track selection).

## UI Outline — confirmed 2026-11-18

Functional requirements only; Design Bot sets the layout and visual contract before any UI work starts.

- **Two modes, Split and Remux**, each with its own folder pickers (Choose buttons), sync/scan button, queue and action button (**Split** / **Remux**).
- **No drag and drop** (unlike PGS2SRT and MP4SubRip); the sync button loads the queue from the chosen folders.
- **Queue columns (v1):** checkbox, base name, status (Ready / Issue / Done / Failed), issue or error reason.
- **Cancel:** finishes the file currently processing, then stops; nothing after it runs.
- **Progress and completion (copied from MP4SubRip):** per-row status and reason; bottom bar shows overall progress (e.g. `3 of 7 complete` with a progress bar) and a Dock badge with the number remaining; when finished it shows `Finished · N done · N flagged · N failed` with **Show in Finder**. Raw `mkvmerge` output for a failed file goes in its error text.
- **Notifications (Settings options):** macOS notification when a batch finishes, and Dock icon bounce.

### Later features (confirmed)
- **Console log area:** optional pane showing verbose messages (full `mkvmerge` output) for users who want detail.
- **Track details panel** for a selected file.

## MKVToolNix Integration — confirmed 2026-11-18

Shell out to the installed `mkvmerge` (see Architecture for lookup: Homebrew paths, any `MKVToolNix*.app` in `/Applications` since the app folder name includes a version, e.g. `MKVToolNix-103-1.app`, then the Settings override). Exact options to be verified against the manual for the installed version (MKVToolNix 103) during research before coding.

**Strip everything (both workflows):** all global and track tags, track statistics tags, attachments (fonts, cover art), track names, language codes, default/forced flags and the file title. v1 keeps **all** audio and subtitle tracks and passes no track IDs.

**Workflow 1 (Split) — draft command:**
```bash
mkvmerge -o "<output>/<base>.mka" --title "" --disable-track-statistics-tags \
  --no-video --no-attachments --no-global-tags --no-track-tags \
  "<source>/<base>.mkv"
```
(plus per-track options to clear names, languages and default/forced flags, built from `--identify-json`). Based on Arezhik's `extract_main_audio_sub.sh`, but keeping all tracks instead of first audio + first subtitle.

**Workflow 2 (Remux) — draft command:** video only from the `.mkv`, everything from the `.mka`, no tags or attachments in the final file:
```bash
mkvmerge -o "<output>/<base>.mkv" --title "" --disable-track-statistics-tags \
  --no-audio --no-subtitles --no-chapters --no-attachments --no-global-tags --no-track-tags "<video>/<base>.mkv" \
  --no-video --no-attachments --no-global-tags --no-track-tags "<mka>/<base>.mka"
```
Corrects Arezhik's `test-remux.sh`, where `--chapters "$mka"` consumed the `.mka` as a chapters file so its audio and subtitles were never added, and hard-coded track IDs pointed at nothing. Resulting order: video, then the `.mka`'s audio and subtitles (in Split's order), then chapters.

**Scan / sync probes:** every scan runs `mkvmerge --identify-json` on each file to detect tracks, flag extra tracks in Remux video files, and flag existing output (`.mka` in Split, `.mkv` in Remux).

**Exit codes:** 0 = Done; 1 = finished with warnings, row gets a warning icon and short message (requirements may be refined later); 2 = Failed.

**Partial files:** write to a temporary name and rename only on success, so a failed or canceled run leaves no half-written file.

### Later features (confirmed)
- **Dry run:** show the commands without running them (may prove unnecessary given the scan probes).

## Validation / Scan Rules — confirmed 2026-11-18

Run on every scan / sync; issues are flagged and the user is informed.

- **Matching:** exact base name only in v1. Fuzzy / close matching is a later feature (mainly for Remux).
- **Hidden files:** ignore hidden files and macOS `._` AppleDouble files (common on external drives).
- **Bad files:** flag zero-length files and files `mkvmerge --identify-json` cannot read.
- **Remux pairing:** the video and MKA folders should mirror each other; flag any `.mkv` without a matching `.mka` and any `.mka` without a matching `.mkv`.
- **Split sources:** flag a source that can't be split, or that has no audio track or no subtitle track (missing either one). Chapters are optional.
- **Existing output:** flag (see Workflows 1 and 2).
- **Still changing:** flag files modified within the last minute at scan time (normally all files are in place before running).
- **Flagged items** are unchecked and cannot be processed in v1; overrides are later features.

## Out of Scope — confirmed 2026-11-18

### Not needed
- Full track editor (use MKVToolNix itself for per-track editing)
- HandBrake integration

### Later features (not in v1)
- Network / NAS drive handling, only if issues come up (mounted shares under `/Volumes` work as normal folders in v1)
- Automatic language detection
- Profiles and a batch profile editor, once requirements are gathered (file a GitHub issue when phases are created)
- Filename parsing, movie/TV detection and rename suggestions
- Separate `.aac` / `.srt` / chapter file outputs and inputs
- Child folder scanning
- Choosing specific audio/subtitle tracks (rules pending from Arezhik)
- Setting language codes and default/forced flags
- Overrides for flagged items (e.g. remux a video file with extra tracks, video only)
- Fuzzy / close base-name matching
- Console log pane (verbose `mkvmerge` output)
- Track details panel
- Dry run (show commands without running)
- Bundling MKVToolNix
- Distribution beyond Arezhik's own Macs (signing, App Store, sandboxing)

## Next Implementation Steps — confirmed 2026-11-18

One phase per PR. Core logic first (testable on Linux before any UI). Design Bot's contract before UI work.

1. **Setup** — repo from the macOS Swift app boilerplate script: hybrid layout, CI with universal macOS build, `.cursor/environment.json`, `docs/LESSONS.md`.
2. **Scanning and checks** — scanner, `--identify-json` parsing, all Validation rules, Split/Remux command builders; unit tests, no real files.
3. **Running** — `mkvmerge` execution, exit codes (0/1 warning/2), temp-file rename, cancel-after-current, per-file errors and summary; tested before UI.
4. **Design** — Design Bot layout contract for Split/Remux modes, queue, bottom bar, Settings. No code.
5. **App UI** — folder pickers with persistence, sync/scan, queue, progress + finish summary, Dock badge, notification + Dock bounce options, Settings with MKVToolNix location.
6. **Mac test** — Arezhik tests on real files; release v1.0.0.

Tracked as a GitHub epic with one issue per phase, plus one issue per later feature (see Out of Scope).
