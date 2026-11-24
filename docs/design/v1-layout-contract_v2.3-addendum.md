# MKVForge v1 layout contract — v2.3 addendum (2026-11-24)

**Status: Approved for issue #48, Show Ready.** This addendum adds the bottom-bar Show Ready control. Every v2, v2.1 and v2.2 rule stays as approved. If this addendum and an earlier contract seem to disagree, the earlier text wins, except for the new control described here.

**Repo:** `docs/design/v1-layout-contract_v2.3-addendum.md`, next to the v2, v2.1 and v2.2 files. No new mockup PNGs. `docs/design/README.md` lists this file.

## Bottom bar · Show Ready

Show Ready sits in the bottom bar (v2 §7), on the trailing side of the bar, after the spacer and immediately before Show in Finder. It is in both Split and Remux. Show in Finder still appears only after a finished batch, in the same place. The progress column, when it shows, stays to the right of those controls.

### Defaults chosen

- **Label:** `Show Ready`.
- **Control:** a bordered toggle (`Toggle` with `.toggleStyle(.button)`), small, the same control size as Show in Finder.
- **Modes:** both Split and Remux. One control. It filters whichever queue is on screen.
- **Default:** off.
- **Persistence:** session-only. It is window state. It is not stored in AppSettings, and it is not remembered across launches.
- **What it hides:** only rows that display as Issue. That is a flagged row whose run status is `nil`, `notRun` or `canceled`.
- **What stays visible:** Ready rows, and Waiting, Working, Done, Done · warning and Failed. A finished or in-progress status replaces Issue, so those rows stay even when the scan item is flagged. Cancelled (the hard-stop status on a row that is not Issue) stays too.
- **Summary:** unchanged. The bottom-bar counts, Scan, the checkboxes and Run keep using the full queue. The toggle does not check, uncheck, remove or skip a row.
- **Empty state:** when the toggle is on and no rows remain visible, the table shows one short line, `No ready files`. The existing empty states (no folders, not scanned, scanning, no files found, can't scan yet) are unchanged, because those are an empty queue, not a filter.
- **Placement:** trailing, next to Show in Finder.

### Accessibility

- Identifier `showReadyToggle`.
- VoiceOver label `Show Ready`.
- The empty line's label is `No ready files` (identifier `noReadyFiles`).

### What it does not change

Scan, folder fields, the mode switch, the primary Split/Remux button, checkbox enablement, Select All Ready, the summary text and the batch progress all read the full queue. Turning Show Ready on does not start a run and does not open Finder.
