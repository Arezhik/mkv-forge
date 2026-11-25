# MKVForge — macOS App Scaffold

**Repo:** [Arezhik/mkv-forge](https://github.com/Arezhik/mkv-forge)
**Status:** In review with Arezhik, section by section. Confirmed: Overview, Naming Convention (2026-11-18).

## Overview

MKVForge is a native universal macOS app (Apple silicon + Intel) that automates two MKVToolNix workflows in batch: **splitting** full MKVs into clean `.mka` files (every audio track, plus subtitle tracks and chapters when the source has them), and **remuxing** encoded video-only MKVs with their matching `.mka` files into finished MKVs.

Two independent workflows (tabs):

**Workflow 1 — Split (to MKA)**
Scan a source folder for MKVs. For each one that has at least one audio track, write a single clean `.mka` to a user-chosen output folder containing all of its audio tracks and, when present, its subtitle tracks and chapters, with every tag and metadata field from the source MKV stripped. Missing subtitles or chapters are a warning, not a skip. A source with no audio track is skipped.

**Workflow 2 — Remux**
Match encoded `.mkv` files with the `.mka` files that share their exact base name, and remux each pair into a finished `.mkv` with that same base name. Only the video track of each `.mkv` is used.

## Naming Convention (matching key) — confirmed

- **v1:** the source file's base name (filename without extension) is the only source of truth. The app does not parse, rename or reformat names.
- Split output: `<source base name>.mka`.
- Remux: a `.mkv` and `.mka` pair only when their base names match exactly; output is `<base name>.mkv`.
- Typical names follow `Name - S##E## - title` (TV) or a movie title, but v1 does not depend on that pattern.

| Type | Extension | v1 role |
|------|-----------|---------|
| Video | `.mkv` | Encoded video input (Workflow 2); only its video track is used |
| Audio, plus subs and chapters when present | `.mka` | Output of Workflow 1, input of Workflow 2 |

**Later (not v1):**
- Detect movie vs TV series, default each to a standard naming layout, and suggest file renames.
- Split into separate `.aac`, `.srt` and chapter files, and accept them as Remux inputs, if ever needed.
- v1 Remux ignores loose `.aac`, `.srt`/`.en.srt` and `.chapters.txt` files.

## Workflow 1: Split — confirmed 2026-11-18

The action is called **Split** everywhere in the app (heading, button, menu item, logs), to pair with **Remux**.

### Source / Output
- Source folder: `.mkv` files. Split needs at least one audio track. Subtitles and chapters are copied when the source has them and are not required. v1 scans the **top level only**; child folders are a later feature if needed.
- Output folder: clean `.mka` files named `<source base name>.mka`.

### Steps
1. User picks the source folder and the output folder.
2. User clicks **Scan**, and the app lists every `.mkv` at the top level of the source folder.
3. For each file, the app identifies its audio, subtitle and chapter content (`mkvmerge -J`, the JSON identify output).
4. **Existing output:** on scan or re-scan (when the source folder syncs), any file whose `<base name>.mka` already exists in the output folder is flagged so the user can see a copy exists. Existing files are never silently overwritten.
5. User reviews the queue and can skip items.
6. User clicks **Split**.
7. The app runs `mkvmerge` to write a clean `.mka` with the audio tracks and, when the source has them, the subtitle tracks and chapters.
8. **Errors:** if a file fails, it is marked failed with its error and the rest of the batch keeps going. A summary is shown at the end.

### Track rules (v1)
- Keep **all** audio tracks. Keep **all** subtitle tracks and the chapters when the source has them.
- A file with audio but no subtitles, no chapters, or neither is still split. The queue row stays Ready and the Reason column names what was missing.
- A file with no audio track is flagged and is not split.
- Drop the video track.
- Strip **all** tags and metadata: global tags, track tags, track names, language codes, default/forced flags, and anything else.
- Picking specific audio/subtitle tracks when a file has several is **deferred** until Arezhik clarifies the selection rules.

## Workflow 2: Remux — confirmed 2026-11-18

### Source / Output
- Video folder: encoded `.mkv` files. They may be full MKVs with audio and subtitle tracks; only the video track is used (decided 2026-11-20).
- MKA folder: `.mka` files from Split (audio, subtitles, chapters).
- Output folder: finished `<base name>.mkv` files.
- v1 scans the **top level only** of each folder.

### Steps
1. User picks the video, MKA and output folders.
2. User clicks **Scan sources**. The app matches files by exact base name and marks each title **Ready** (video + MKA present) or **Issue**.
3. Issues are flagged and the user is informed:
   - missing video or MKA, or duplicate base names;
   - `<base name>.mkv` already exists in the output folder (never silently overwritten);
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
├── Validator               // completeness, existing output, video-only note
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
- **Queue columns (v1):** checkbox, base name, status, issue or error reason. Statuses (contract v2 §4): Ready, Issue, Waiting, Splitting…/Remuxing… (the current file), Done, Done · warning (mkvmerge exit 1), Failed.
- **Cancel:** finishes the file currently processing, then stops; nothing after it runs.
- **Progress and completion (copied from MP4SubRip; contract v2 §7):** per-row status and reason; bottom bar shows overall progress (e.g. `3 of 7 complete` with a files-based progress bar); when finished it shows `Finished · N done (M with warning) · N flagged · N failed`, zero counts hidden, with **Show in Finder**. The Dock badge was removed in contract v2 (Arezhik, 2026-11-18). Raw `mkvmerge` output for a failed file goes in its error text.
- **Notifications (Settings options):** macOS notification when a batch finishes, and Dock icon bounce.

### Later features (confirmed)
- **Console log area:** optional pane showing verbose messages (full `mkvmerge` output) for users who want detail.
- **Track details panel** for a selected file.

## MKVToolNix Integration — confirmed 2026-11-18

Shell out to the installed `mkvmerge` (see Architecture for lookup: Homebrew paths, any `MKVToolNix*.app` in `/Applications` since the app folder name includes a version, e.g. `MKVToolNix-103-1.app`, then the Settings override). Exact options to be verified against the manual for the installed version (MKVToolNix 103) during research before coding.

**Strip everything (both workflows):** all global and track tags, track statistics tags, attachments (fonts, cover art), track names, language codes, default/forced flags and the file title. v1 keeps **all** audio tracks and any subtitle tracks, and passes no track IDs.

**Workflow 1 (Split) — draft command:**
```bash
mkvmerge -o "<output>/<base>.mka" --title "" --no-date --disable-track-statistics-tags \
  --no-video --no-attachments --no-global-tags --no-track-tags \
  <per-track options for every audio and subtitle track ID> \
  "<source>/<base>.mkv"
```
Per-track options, built from `mkvmerge -J` (only for track IDs the file has; an unknown ID is a warning, exit 1): `--track-name TID:` `--language TID:und` and `--default-track-flag`, `--forced-display-flag`, `--commentary-flag`, `--original-flag`, `--hearing-impaired-flag`, `--visual-impaired-flag`, `--text-descriptions-flag` each set to `TID:0`. Without them mkvmerge copies the source's names, languages and flags. Matroska reads a missing language as `eng` and a missing default flag as on, so "unset" is written as `und` and every flag 0 (decided 2026-11-18, Phase 2 research). Verified with mkvmerge 82.0 and 103.0. Based on Arezhik's `extract_main_audio_sub.sh`, but keeping all tracks instead of first audio + first subtitle.

**Workflow 2 (Remux) — draft command:** video only from the `.mkv`, everything from the `.mka`, no tags or attachments in the final file:
```bash
mkvmerge -o "<output>/<base>.mkv" --title "" --no-date --disable-track-statistics-tags \
  --no-audio --no-subtitles --no-chapters --no-attachments --no-global-tags --no-track-tags \
  <the same per-track options for each video track ID> "<video>/<base>.mkv" \
  --no-video --no-attachments --no-global-tags --no-track-tags "<mka>/<base>.mka"
```
The video track's name, language and flags are cleared the same way as Split's tracks (decided 2026-11-18). The `.mka` tracks are already clean from Split, so they get no per-track options. All paths are absolute: mkvmerge has no `--`, and an argument starting with `@` is read as an option file.
Corrects Arezhik's `test-remux.sh`, where `--chapters "$mka"` consumed the `.mka` as a chapters file so its audio and subtitles were never added, and hard-coded track IDs pointed at nothing. Resulting order: video, then the `.mka`'s audio and subtitles (in Split's order), then chapters.

**Scan / sync probes:** every scan runs `mkvmerge -J` (alias for `--identification-format json --identify`; there is no `--identify-json` option) on each file to detect tracks, note audio or subtitle tracks in Remux video files (Ready, `Uses video only, ignores …`), warn on a Split source that has audio but no subtitles or no chapters (Ready, `No subtitle tracks found` / `No chapters found`), and flag existing output (`.mka` in Split, `.mkv` in Remux).

**Exit codes:** 0 = Done; 1 = finished with warnings, row gets a warning icon and short message (requirements may be refined later); 2 = Failed.

**Partial files:** write to a temporary name and rename only on success, so a failed or canceled run leaves no half-written file.
Running (Phase 3, decided 2026-11-19): the temp file is hidden, `.<base>.partial.mka` / `.mkv` in the Output folder, and is renamed with a move that never replaces a file. A failed, cancelled or killed run deletes it. Right before each file the app checks that the Output folder and inputs still exist, the output is still absent, and a fresh `mkvmerge -J` matches the scan; otherwise that file fails without running. mkvmerge reports warnings and errors on stdout (L28) and silently recreates a missing output folder (L29).

### Later features (confirmed)
- **Dry run:** show the commands without running them (may prove unnecessary given the scan probes).

## Validation / Scan Rules — confirmed 2026-11-18

Run on every scan / sync; issues are flagged and the user is informed.

- **Matching:** exact base name only in v1. Fuzzy / close matching is a later feature (mainly for Remux).
- **Hidden files:** ignore hidden files and macOS `._` AppleDouble files (common on external drives).
- **Bad files:** flag zero-length files and files `mkvmerge -J` cannot read. `-J` exits 0 even for unreadable files, so the app reads its JSON: not recognized, an `errors` entry, a container that isn't Matroska, or no tracks at all.
- **Remux pairing:** the video and MKA folders should mirror each other; flag any `.mkv` without a matching `.mka` and any `.mka` without a matching `.mkv`.
- **Split sources:** flag a source that can't be split, or that has no audio track. Subtitles and chapters are optional and are copied when present. Missing subtitles, missing chapters, or both are a Ready warning, not a blocking Issue. Missing audio is a blocking Issue. A source with no audio and no subtitles is an Issue (`No audio or subtitle tracks found`), because there is nothing to split.
- **Existing output:** flag (see Workflows 1 and 2).
- **Also flagged (decided 2026-11-18, Phase 2 research):** a Remux video file with no video track; a `.mka` with no audio and no subtitle tracks; a file that isn't Matroska inside; a Remux Output folder that is the Video folder.
- **Still changing:** flag files modified within the last minute at scan time (normally all files are in place before running). Exception: a Remux scan doesn't flag an `.mka` that this session's Split batch just wrote, when its path, size and modification date match exactly (L32).
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
- Overrides for flagged items
- Fuzzy / close base-name matching
- Console log pane (verbose `mkvmerge` output)
- Track details panel
- Dry run (show commands without running)
- Bundling MKVToolNix
- Distribution beyond Arezhik's own Macs (signing, App Store, sandboxing)

## Next Implementation Steps — confirmed 2026-11-18

One phase per PR. Core logic first (testable on Linux before any UI). Design Bot's contract before UI work.

1. **Setup** — repo from the macOS Swift app boilerplate script: hybrid layout, CI with universal macOS build, `.cursor/environment.json`, `docs/LESSONS.md`.
2. **Scanning and checks** — scanner, `mkvmerge -J` parsing, all Validation rules, Split/Remux command builders; unit tests, no real files.
3. **Running** — `mkvmerge` execution, exit codes (0/1 warning/2), temp-file rename, cancel-after-current, per-file errors and summary; tested before UI.
4. **Design** — done: Design Bot layout contract v2 (`docs/design/v1-layout-contract_v2.md`, approved 2026-11-18) plus the v2.1 addendum (`docs/design/v1-layout-contract_v2.1-addendum.md`, approved 2026-11-19) for Split/Remux modes, queue, bottom bar, Settings, quit while running, and scanning. No code.
5. **App UI** — folder pickers with persistence, sync/scan, queue, progress + finish summary, notification + Dock bounce options, Settings with MKVToolNix location.
6. **Mac test** — Arezhik tests on real files; release v1.0.0.

Tracked as a GitHub epic with one issue per phase, plus one issue per later feature (see Out of Scope).
