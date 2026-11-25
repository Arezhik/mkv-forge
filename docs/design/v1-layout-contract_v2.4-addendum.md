# MKVForge v1 layout contract — v2.4 addendum (2026-11-24)

**Status: Approved for issue #23, time remaining.** This addendum fills the caption reserved under the progress bar in v2 §7. Every v2, v2.1, v2.2 and v2.3 rule stays as approved. If this addendum and an earlier contract seem to disagree, the earlier text wins, except for the caption described here.

**Repo:** `docs/design/v1-layout-contract_v2.4-addendum.md`, next to the v2, v2.1, v2.2 and v2.3 files. No new mockup PNGs. `docs/design/README.md` lists this file.

## Progress column · time remaining

The progress column stays 152 pt. The bar stays files completed ÷ files in the run. It still steps once per finished file (Done, Done · warning or Failed). There is no partial fill for the current file. §4 does not change: the row stays an indeterminate spinner plus `Splitting…` or `Remuxing…`, with no per-file percent. Only the reserved caption line under the bar is filled while a batch runs.

### Defaults chosen

- **Sentence:** `About 12 seconds left`, `About 2 minutes left`, `About 1 hour 30 minutes left`.
- **Rounding:** nearest second, halves away from zero. Under 60 seconds, say seconds. A result of 0 seconds is shown as `About 1 second left`. From 60 seconds, round to the nearest minute. Under 60 minutes, say minutes only. From 60 minutes, say whole hours, and the leftover minutes when that leftover is at least 1.
- **Singular:** `1 second`, `1 minute`, `1 hour`. Every other count is plural.
- **Hide:** at 0%, below 5%, at 100% and above, when no time has passed on the current file, and after Cancel. 5% is the first percent large enough to extrapolate (`RunETA.stablePercent`). At 100% the caption hides: mkvmerge then writes the cue index and sends no further percent, so the line does not sit on a finished estimate while that work continues. Cancel clears the caption even if the current file is still finishing.
- **Blend:** the current file's remaining time is `elapsed × (100 − percent) / percent`. Each file still queued after it adds the average duration of files whose mux already finished in this run. When none have finished, that average is this file's own projected duration (`elapsed × 100 / percent`). The current file always uses its own percent and elapsed time. The average is only for the files still waiting.
- **Rate:** the caption updates about 10 times a second.

### Accessibility

- Identifier `batchProgressCaption`.
- VoiceOver label is the caption sentence, such as `About 2 minutes left`.
- When the caption is empty, that element is hidden from VoiceOver. The bar's value stays `2 of 4 complete` (identifier `batchProgress`).

### What it does not change

The 152 pt column, the file-based bar, the row spinner and `Splitting…` / `Remuxing…`, the summary, and the finished caption `3 .mka saved` / `3 .mkv saved`. Show in Finder and Show Ready stay where they are. Cancel still finishes the current file, then stops.
