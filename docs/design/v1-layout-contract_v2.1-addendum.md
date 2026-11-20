# MKVForge v1 layout contract — v2.1 addendum (Design Bot, 2026-11-19)

**Status: Approved by Arezhik 2026-11-19** (relayed by macOS Dev (test), with Q1 confirmed: closing the main window quits MKVForge, as in §1.6). Addendum to the approved v2 contract (approved by Arezhik 2026-11-18). It covers only two states Arezhik approved as functional rules on 2026-11-19: **G1** (quit or close while a batch runs) and **G2** (scanning). Every v2 rule stays as approved. Where this addendum and v2 seem to disagree, v2 wins, and §3 lists every point I checked.

**Repo:** commit as docs/design/v1-layout-contract_v2.1-addendum.md in Arezhik/mkv-forge, next to docs/design/v1-layout-contract_v2.md. The four mockup PNGs stay with Design Bot and are not checked into git (see docs/design/README.md), so the `mockups-v2.1/` links below don't resolve inside the repo.

**What I worked from:** the macOS Dev (test) brief of 2026-11-19, the approved v2 contract, and my own Apple HIG cache. **I did not read the repo or any app or PR code**, including the BatchRunner and FolderScanner files the brief mentions. Their behavior is taken from the brief's summary.

## Confirm with Arezhik (one question, not blocking)

**Q1. Does closing the main window quit MKVForge?** v2 doesn't say. My default (§1.6) is **yes, closing the only main window quits the app**, as single-window utilities do, and while a batch runs it shows the same G1 alert. Phase 5 can build this default. If Arezhik prefers "close hides the window and keeps MKVForge running", only §1.6 changes.

**Answered by Arezhik 2026-11-19: yes.** Closing the main window quits MKVForge (§1.6 as written).

Other choices I made are labeled **Default** below. None of them needs an answer to start.

## Mockups (2× PNG, 1080×760 pt canvas, same 980×640 window as v2)

| State | Light | Dark |
|---|---|---|
| G1 · quit/close alert sheet over Split running | [png](mockups-v2.1/2026-11-19_mkvforge_g1-quit-alert_light.png) | [png](mockups-v2.1/2026-11-19_mkvforge_g1-quit-alert_dark.png) |
| G2 · first scan in progress (Split) | [png](mockups-v2.1/2026-11-19_mkvforge_g2-scanning_light.png) | [png](mockups-v2.1/2026-11-19_mkvforge_g2-scanning_dark.png) |

Magenta labels are annotations, not UI. File names and counts are illustrative.

---

## 1. G1 · Quitting or closing the window while a batch runs

### 1.1 When the alert appears

| App state (v2) | ⌘Q / Quit MKVForge | Close the main window (red button, ⌘W, File › Close) |
|---|---|---|
| Idle, scanned, scanning, stopped, finished | Quits immediately, **no alert** | Quits immediately, **no alert** (Q1 default) |
| **Running** | **G1 alert** | **G1 alert** |
| **Cancelling** (v2 §6) | **G1 alert**, Cancelling wording (§1.2) | **G1 alert**, Cancelling wording |
| Already quitting after Finish Current File (§1.5) | Shows the alert again, Cancelling wording | Shows the alert again, Cancelling wording |

A scan isn't a batch. Quitting during a scan stops the scan silently, and nothing is written (G2).

### 1.2 Exact text

- **Title:** `A batch is running`
- **Informative text, while running** (Split; Remux replaces the verb with `remuxing`):
  `MKVForge is splitting “The.Expanse.S01E03”. Choose Finish Current File to quit when it’s done, or Quit to stop now and delete its unfinished file. Files that are already finished are kept.`
- **Informative text, while cancelling or already quitting:**
  `MKVForge is finishing “The.Expanse.S01E03”, then stopping. Choose Finish Current File to quit when it’s done, or Quit to stop now and delete its unfinished file. Files that are already finished are kept.`
- **Buttons (approved labels):** `Finish Current File`, `Quit`, `Cancel`.
- The file name is the current file's base name in curly quotes, as in v2's Reason and summary strings. Long names are middle-truncated to about 40 characters. NSAlert wraps the text and doesn't truncate it, so the app has to shorten the name.
- Why I explain the buttons: the HIG says to avoid it, but it allows it "in rare cases" if you use *choose* and the exact button titles without quotes. Here the two ways to quit differ in what happens to a file, so the text has to say so.

### 1.3 Button order, default, cancel, destructive

On macOS 15, an NSAlert with three buttons stacks them **vertically, full width**. From top to bottom:

| Position | Button | Role | Key | Style |
|---|---|---|---|---|
| Top | `Finish Current File` | **Default** | Return (↩) | Accent fill |
| Middle | `Quit` | Destructive | none | `hasDestructiveAction = true` (red title) |
| Bottom | `Cancel` | Cancel | Esc and ⌘. | Standard |

- **Quit is never the default.** It's the only choice that loses work (the current file's output), and the person didn't ask to lose it, so it gets the destructive style.
- **Default: Finish Current File.** It's the safe choice that still quits, which is what ⌘Q asked for. The HIG puts the default at the top of a stack and Cancel at the bottom.
- The brief lists the buttons in the order `Quit` · `Finish Current File` · `Cancel`. That's a list of labels, not a layout, and the labels stay exactly as approved (§3).
- **Alert icon:** the app icon, via `alertStyle = .warning`. I didn't use `.critical`, because the HIG keeps the caution badge for "unexpected loss of data" and only the partial file is at stake.
- **No suppression checkbox** ("Don't ask again"). Quitting mid-batch is rare and the consequence is real.

### 1.4 Presentation (AppKit inside the SwiftUI app, macOS 15+)

- **Alert:** `NSAlert` with `alertStyle = .warning`, `messageText`, `informativeText`, and buttons added in this order:
  1. `addButton(withTitle: "Finish Current File")`, which gets Return automatically as the first button.
  2. `addButton(withTitle: "Quit")`, then set `hasDestructiveAction = true` and `keyEquivalent = ""`.
  3. `addButton(withTitle: "Cancel")`. NSAlert gives a button titled Cancel the Esc key; also check that ⌘. works.
- **Show it as a sheet on the main window** with `beginSheetModal(for: mainWindow)`, not as an app-modal dialog. The question is about that window's batch, and the progress underneath stays visible.
- **⌘Q path:** `NSApplicationDelegate.applicationShouldTerminate(_:)` returns `.terminateNow` unless the batch is running or cancelling. If it is, return `.terminateLater`, show the sheet, then:
  - **Quit:** hard-stop (cancel the task). After the core has killed mkvmerge and deleted the partial file, call `NSApp.reply(toApplicationShouldTerminate: true)`. This takes well under a second, so a short `.terminateLater` wait is fine.
  - **Finish Current File:** call `NSApp.reply(toApplicationShouldTerminate: false)` **right away**. Then request a stop (the v2 Cancel path) and set a quit-after-stop flag. When the batch reaches Stopped, call `NSApp.terminate(nil)`, and the flag skips the alert. Don't hold `.terminateLater` for a whole file, because the app would sit in a modal run loop for minutes.
  - **Cancel:** call `NSApp.reply(toApplicationShouldTerminate: false)`. Nothing else changes.
- **Close path:** the main `NSWindow` delegate's `windowShouldClose(_:)` returns `false` while a batch is running or cancelling and shows the same sheet. The SwiftUI `Window` scene reaches its NSWindow through a small accessor view.
  - Quit and Finish Current File then follow the same paths as ⌘Q.
  - Because closing quits (Q1), there's no separate "close but keep running" outcome.
- **Settings in front:** if Settings is the key window when ⌘Q or a close comes in, bring the main window forward first (`makeKeyAndOrderFront`, and un-minimize it if needed). Then attach the sheet to the main window. Settings stays open behind it and closes when the app quits. Closing the Settings window never shows G1.
- **Logout, restart or shutdown** also call `applicationShouldTerminate`. **Default:** show the same alert. If nobody answers, macOS reports that MKVForge stopped the logout, which is the honest result while a file is half written.

### 1.5 The window during Finish Current File (reuse v2's Cancelling state)

After Finish Current File, the window is **exactly v2's Cancelling state** (§6/§7). There are no new strings:

- **Toolbar:** a disabled `Cancelling…` button with a small spinner. The subtitle reads `Cancelling · finishing current file`.
- **Bottom bar:** `Finishing <name>, then stopping · N of M complete`, and the files-based bar stays where it is.
- **Rows:** the current row keeps its spinner. Waiting rows go back to Ready and show `Won't start: batch cancelled`.
- **Locked controls:** the mode switch, folders, Scan and checkboxes stay disabled.
- **When the file ends:** the batch reaches Stopped, and MKVForge quits **without showing the Stopped bar and without a notification or Dock bounce**. That follows the approved v2 decision (b): those happen only after a normal finish. Done rows are unchecked as v2 requires. Folders and settings are kept, as always.
- **No "Quitting…" string.** A near-duplicate of the Cancelling copy isn't worth it, since the window disappears a moment later. VoiceOver gets one extra announcement: `MKVForge will quit after this file.`
- **⌘Q or close again during the wait** shows the alert again with the Cancelling text:
  - **Quit** hard-stops now.
  - **Finish Current File** and **Cancel** both keep the pending quit unchanged; Cancel just dismisses the alert.
  - There's no way to undo the pending quit. **Default:** this keeps the alert's meaning simple. If Arezhik wants "Keep MKVForge Open", that's a later addition.
- **If the person pressed Cancel (v2) and then ⌘Q:** that's the Cancelling row in §1.1. Finish Current File adds "and then quit" to the stop that's already happening.

### 1.6 Closing the single window (Q1 default)

- **Default:** `applicationShouldTerminateAfterLastWindowClosed(_:)` returns `true`.
- With Settings open, closing the main window wouldn't trigger that, because Settings is still a window. So the main window's `windowWillClose` also calls `NSApp.terminate(nil)`: **closing the main window always quits**, and Settings closes with it.
- **Idle, scanned, finished or stopped:** close quits immediately.
- **Running or cancelling:** close shows G1 first (§1.4).
- **Why:** MKVForge has one main window and no documents, and there's no menu command to reopen the window. The HIG's menu-bar table defines Close as "Closes the current window or document." In a single-window utility, a running app with no window left would be a dead end, so close-to-quit is the usual pattern.

### 1.7 Keyboard and accessibility

- **Keys:** Return = Finish Current File. Esc or ⌘. = Cancel. Tab moves between buttons when Full Keyboard Access is on, and Space presses the focused button.
- **VoiceOver:** the alert is announced automatically (title, then message). Quit's destructive role comes from the system.
- No color-only meaning: Quit's red title is paired with its word and its position.

## 2. G2 · Scanning state

### 2.1 What's locked during a scan

**Disabled:**
- the Scan button
- every Choose… button, and the folder fields' context menus
- the primary action `Split` / `Remux`
- the **mode switch** `Split | Remux`
- **queue checkboxes**, and Select All Ready / Deselect All

Locking these keeps the old rows and mode from being changed while new results are being built. The approved rule lists Choose… and the primary action; adding the mode switch and checkboxes is the same idea (§3).

**Unchanged:**
- the bottom bar
- the Settings window. A changed MKVToolNix location applies to the next scan.

**Toolbar subtitle:** `Split · Scanning…` / `Remux · Scanning…`, which follows v2's `Split · …` pattern.

### 2.2 Scan row: spinner and caption

Layout, trailing-aligned as in v2 §3: **[spinner] [caption] [Scan (disabled)]**.

- **Spinner:** `ProgressView().controlSize(.small)`, 12 pt, indeterminate, 6 pt before the caption. It's there only while scanning. Its space isn't reserved otherwise, so it's the caption that moves, not the Scan button.
- **Caption** (12 pt in v2, primary color while scanning, `.monospacedDigit()`):

  | Moment | Caption |
  |---|---|
  | Listing the folder (total not known yet) | `Scanning…` |
  | Reading files with mkvmerge -J | `Scanning… 3 of 9` |
  | Scan done | v2 grammar, e.g. `Scanned 9:12 PM · 7 MKV files` (Remux: `Scanned 9:20 PM · 6 names · 4 pairs`) |
  | **Stopped with Esc, previous queue existed** | **The previous caption, unchanged**, e.g. `Scanned 9:12 PM · 7 MKV files` |
  | **Stopped with Esc during a first scan** | `Not scanned yet` (v2) |

  - **3 of 9:** 3 = the file now being read, 1-based. It never shows `0 of 9`, and it shows `9 of 9` while the last file is read. 9 = MKV files found in Source (Split), or names found in either folder (Remux).
  - **Why the old caption comes back after a stop:** the queue on screen *is* that 9:12 scan, so the caption stays true. Feedback that the stop worked: the spinner disappears, Scan is enabled again, the queue un-dims, and VoiceOver hears "Scan stopped".
- **Esc hint:** it is **not** in the caption, so the approved `Scanning… 3 of 9` stays exact. It appears in three places instead:
  1. In the first-scan empty state (§2.4)
  2. As the menu item **Stop Scan, Esc**
  3. As `.help("Press Esc to stop scanning")` on the caption
- **Why the spinner is in the Scan row and not the bottom bar:**
  - The approved rule pairs the spinner with the disabled Scan button, and the HIG says to "Display a progress indicator in a consistent location".
  - In v2, the bottom bar is where batch progress goes (a files-based bar and summary). A scan spinner there would read as a batch, and on a re-scan it would replace the previous batch's finished summary.
  - The HIG prefers a spinner "when space is constrained", which fits the Scan row. The caption isn't a label for the spinner; it's the Scan row's existing status line, now with a count.

### 2.3 The menu command and Esc handling

- The scan menu command (v2's Scan, ⌘R) becomes **Stop Scan, Esc** while scanning. It's a `Button` in the app's `.commands` with `.keyboardShortcut(.cancelAction)`.
- A menu key equivalent fires whatever has focus in the main window, including the table. That's why I didn't use `.onExitCommand` alone, since it needs focus inside the view.
- Fallback if the menu route misses: an `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` for keyCode 53, active only while scanning and only when the main window is key.
- An open-panel sheet can't be showing during a scan, because Choose… is disabled, so Esc can't be taken by one.
- Esc never means "stop" for anything else during a scan. Scanning and running can't overlap, so it doesn't clash with v2's Esc = Cancel during a batch.

### 2.4 Queue during a scan

- **First scan (no previous queue), shown in the G2 mockup:** v2's empty-state layout (overlay in the table), with the column headers kept:
  - Title `Scanning the Source folder` (Remux: `Scanning the Video and Audio folders`)
  - Body `MKVForge reads each MKV file with mkvmerge. Files appear here when the scan is done.`
  - Then a key cap plus `Stop Scan` (`esc Stop Scan`)
  - **No spinner here**, so there's only ever one spinner. Rows don't stream in during the scan. The table fills all at once when the scan ends, which keeps the sorting and the pairing stable.
- **Re-scan (previous queue exists):**
  - The previous rows stay visible but **dimmed** (`.disabled(true)` plus about 45% opacity on the row content), and the selection is kept.
  - When the scan ends, the new rows replace them **in one step**. v2 §3's rule applies: rows still Ready keep their check state when the name matches.
  - On Esc, the old rows come back exactly as they were, with no changes.
- **Bottom bar during a re-scan:** it keeps showing the previous summary (`7 files · 4 selected · 2 flagged`, or a finished line), and it's updated after the swap.

### 2.5 Accessibility

- **VoiceOver announcements** (`AccessibilityNotification.Announcement`), at most one per event:

  | Event | Announcement |
  |---|---|
  | Scan starts | `Scanning` |
  | Scan ends | `Scan finished, 7 files, 2 flagged` |
  | Esc | `Scan stopped` |

- The caption is an element with label `Scan status` and value `Scanning, 3 of 9`. It isn't announced on every count change; people can read it when they want.
- The spinner is hidden from VoiceOver (`.accessibilityHidden(true)`) because the caption already says the same thing.
- Dimmed rows read as "dimmed", so the old queue isn't mistaken for live results.
- Reduce Motion: the system spinner is fine, and nothing else moves.

### 2.6 SwiftUI mapping (macOS 15+)

```
ScanRow: HStack(spacing: 6) { Spacer()
  if isScanning { ProgressView().controlSize(.small).accessibilityHidden(true) }
  Text(scanCaption).monospacedDigit().foregroundStyle(isScanning ? .primary : .secondary)
    .help(isScanning ? "Press Esc to stop scanning" : "")
  Button("Scan", systemImage: "arrow.clockwise") { scan() }.keyboardShortcut("r").disabled(!canScan || isScanning) }
Commands: Button(isScanning ? "Stop Scan" : "Scan") { … }
  .keyboardShortcut(isScanning ? .cancelAction : KeyboardShortcut("r"))
Locks: modePicker / chooseButtons / primaryAction / row checkboxes  .disabled(isRunning || isCancelling || isScanning)
Queue: previousRows.opacity(isScanning ? 0.45 : 1).disabled(isScanning); first scan → empty-state overlay (no spinner)
Swap: rows = newRows on completion only (one assignment); Esc → task.cancel(), rows untouched
```

## 3. Conflicts and extensions checked against v2 (flagged, not changed)

1. **Mode switch and checkboxes locked during a scan.** v2 locks them only while running. This addendum extends the lock to scanning. It's an extension, not a conflict.
2. **Order of the alert buttons.** The brief lists `Quit` · `Finish Current File` · `Cancel`. The stacked macOS order is Finish Current File (default, top), Quit, Cancel (bottom). The labels are unchanged.
3. **Stopped bar skipped on quit.** v2 §6 shows `Stopped · N of M complete` after a Cancel. When Finish Current File is quitting the app, the window closes right away instead. Nothing contradicts v2; the window just doesn't stay open.
4. **No notification or bounce when quitting.** This is exactly v2 decision (b). Listed here only to confirm it.
5. **Esc during a scan vs. v2's Esc = Cancel during a batch.** The two can't happen at the same time, so there's no overlap.
6. **Informative text explains the buttons.** The HIG says to avoid this except in rare cases. The approved Quit behavior differs from a normal quit (it deletes a file), so this is that rare case, written the way the HIG asks.

No approved v2 rule is changed by this addendum.

## 4. Cited sources (exact quotes, verified with designkit cache-quote)

Times are MST. Alerts and Buttons were retrieved 2026-11-18 at 9:16 PM. Progress indicators was retrieved 2026-11-11 at 6:18 PM. Modality, Keyboards and The menu bar were fetched for this addendum on 2026-11-19 between 7:24 and 7:26 PM.

- **Alerts** (https://developer.apple.com/design/human-interface-guidelines/alerts)
  - "Always place the default button on the trailing side of a row or at the top of a stack."
  - "Cancel buttons are typically on the leading side of a row or at the bottom of a stack."
  - "Use the destructive style to identify a button that performs a destructive action people didn’t deliberately choose."
  - "Always use the title “Cancel” for a button that cancels an alert’s action."
  - "Note that you don’t want to make a Cancel button the default button."
  - "Avoid explaining alert buttons."
  - "In rare cases where you need to provide guidance on choosing a button, use a term like choose to account for people’s current device and interaction method, and refer to a button using its exact title without quotes."
  - "Pressing Escape (Esc) or Command-Period (.) on an attached keyboard"
  - "Use the symbol only when extra attention is really needed, as when confirming an action that might result in unexpected loss of data."
- **Modality** (https://developer.apple.com/design/human-interface-guidelines/modality)
  - "When necessary, help people avoid data loss by getting confirmation before closing a modal view."
- **Buttons** (https://developer.apple.com/design/human-interface-guidelines/buttons)
  - "Consider using text when a short label communicates more clearly than an icon."
- **The menu bar** (https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
  - "Closes the current window or document."
- **Keyboards** (https://developer.apple.com/design/human-interface-guidelines/keyboards)
  - "Cancel the current action or process." (the system meaning of Esc)
- **Progress indicators** (https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
  - "Display a progress indicator in a consistent location."
  - "Prefer an activity indicator (spinner) to communicate the status of a background operation or when space is constrained."
  - "Don’t switch from the circular style to the bar style."

No command certifies HIG compliance. The vertical stacking of three buttons is NSAlert's own macOS 11+ behavior, and I didn't quote it from the HIG.

## Assumptions

- **A1.** I didn't read the repo code. Hard stop, partial-file deletion, `requestStop()` and scan cancellation work as the brief describes. Phase 5 adds the scan progress count.
- **A2.** The scan total is known after the folder listing and before mkvmerge -J starts. If listing a network folder is slow, the caption stays `Scanning…` until the total is known.
- **A3.** A hard stop finishes deleting the partial file in under about a second. If it can take longer, the sheet's Quit should show a brief disabled state before the app exits; that isn't designed here.
