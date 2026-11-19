# MKVForge v1 layout contract — v2 (Design Bot, 2026-11-18)

**Status: Approved by Arezhik 2026-11-18** (relayed by macOS Dev (test) at 9:57 PM MST, with two final answers: Reason shows the first mkvmerge warning line; notification and Dock bounce only on a normal finish, not after Cancel).

Answers macOS Dev (test)'s brief `inbox/processed/2026-11-18_from-macos-dev-test_mkvforge-v1-layout.md` (Phase 4 of epic #22, issue #4). **v2** applies Arezhik's decisions of 2026-11-18, relayed by macOS Dev (test), to v1 of this contract (v1 is archived at `archive/mkvforge-v1/v1-finals/`). Changes are listed in §0. This is a layout and visual spec only. There's no code here, and Arezhik approves it before any UI work starts.

**What I worked from.** I used the brief's "Confirmed functional requirements" summary, my own MP4SubRip decisions (notes.md, `work/mp4subrip-phase3/doc/body.md`, my Phase 2/3 sources and renders, and my as-delivered Phase 3 reply in macOS Dev's inbox), plus cached Apple HIG pages. **I did not read the scaffold** (`macos-dev-test/projects/mkv-forge/scaffold.md`), anything under `macos-dev/projects/` or `macos-dev-test/projects/`, or any PR code. That includes the MP4SubRip v2 spec path the brief cites. Anything the summary doesn't state is listed under Assumptions. If the scaffold disagrees with this document, the scaffold wins and I'll revise.

**Mockups.** There are 24 PNGs (12 screens × light/dark) in `mockups-v2/`, plus `2026-11-18_mkvforge_v1-mockups_v2.pdf` with one titled page per PNG. Each one is a 1080×760 pt canvas rendered at 2×. The main window is drawn at 980×640 pt and Settings at 540 pt wide. Magenta boxes and labels are annotations, not UI, and tooltips are drawn open only to illustrate them. All file names, paths, counts, times and mkvmerge messages are illustrative. The drawing follows the macOS 15 look. On macOS 26 the system toolbar and controls get Liquid Glass automatically, and nothing in this layout depends on either look.

| Screen | Light | Dark |
|---|---|---|
| Split · idle (first launch, reserved areas annotated) | [png](mockups-v2/2026-11-18_mkvforge_main-split-idle-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-split-idle-dark_v2.png) |
| Split · scanned with issues | [png](mockups-v2/2026-11-18_mkvforge_main-split-scanned-issues-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-split-scanned-issues-dark_v2.png) |
| Split · running | [png](mockups-v2/2026-11-18_mkvforge_main-split-running-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-split-running-dark_v2.png) |
| Split · cancelling (finish current file, then stop) | [png](mockups-v2/2026-11-18_mkvforge_main-split-cancelling-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-split-cancelling-dark_v2.png) |
| Split · finished | [png](mockups-v2/2026-11-18_mkvforge_main-split-finished-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-split-finished-dark_v2.png) |
| Remux · idle (folders remembered, not scanned) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-idle-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-idle-dark_v2.png) |
| Remux · scanned with issues | [png](mockups-v2/2026-11-18_mkvforge_main-remux-scanned-issues-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-scanned-issues-dark_v2.png) |
| Remux · running | [png](mockups-v2/2026-11-18_mkvforge_main-remux-running-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-running-dark_v2.png) |
| Remux · finished (no failures: zero count hidden; warning fallback text) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-finished-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_main-remux-finished-dark_v2.png) |
| MKVToolNix not found · main window | [png](mockups-v2/2026-11-18_mkvforge_mkvtoolnix-not-found-main-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_mkvtoolnix-not-found-main-dark_v2.png) |
| Settings · MKVToolNix found (auto-detected) | [png](mockups-v2/2026-11-18_mkvforge_settings-found-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_settings-found-dark_v2.png) |
| Settings · MKVToolNix not found | [png](mockups-v2/2026-11-18_mkvforge_settings-not-found-light_v2.png) | [png](mockups-v2/2026-11-18_mkvforge_settings-not-found-dark_v2.png) |

## 0. Changes in v2

- **Dock badge removed** everywhere (spec, mockups, annotations). The HIG badge conflict note is gone with it.
- **Progress is files-based only.** The bottom bar is a determinate bar = files completed ÷ files in the run, stepping once per finished file. No ETA in v1 (future). Rows lose the per-file % bar: the current file shows a small spinner + `Splitting…`/`Remuxing…`.
- **Warnings:** `Done · warning`, with mkvmerge's warning text in Reason, or the fallback `mkvmerge reported a warning (no details)`.
- **Finish summary:** zero counts hidden; warnings shown as `N done (M with warning)`.
- **After finish:** Done rows are unchecked automatically.
- **Launch:** no auto-scan; remembered folders show `Not scanned yet`.
- **Not-found states:** a `Get MKVToolNix` link to https://mkvtoolnix.download/ in the banner and in Settings.
- **Show in Finder after Cancel:** kept (decided).
- **Notification + Dock bounce:** on by default, background only, **normal finish only — never after a completed Cancel** (decided).
- Open questions from v1 are all decided (§13). The conflicts list (§14) keeps only what is still worth a look.

## 1. Window structure

There's one main window (a `Window` scene, not a document window). From top to bottom:

1. **Toolbar** (unified, about 52 pt):
   - **Title area (leading):** the title `MKVForge`, and under it a subtitle that mirrors state:
     - `Split · 4 of 7 selected`
     - `Splitting · 2 of 4 complete`
     - `Finished · 3 of 4 succeeded`
     - `Split · MKVToolNix not found`
   - **Mode switch (centered):** see §2.
   - **Primary action (trailing):** see §6.
2. **MKVToolNix-not-found banner** (only in that state, §9).
3. **Folder panel** (§3): one row per folder, then the Scan row. It sits in the window body, with a hairline separator below it.
4. **Queue table** (§4). It takes all remaining height.
5. **Bottom bar** (52 pt, §7): a summary on the leading side, and progress plus Show in Finder on the trailing side.

**Sizes:**

| Item | Size |
|---|---|
| Default window | 980 × 640 pt |
| Minimum window | 760 × 480 pt (folder panel ≈ 117/150 pt + header + about 6 rows + bar) |
| Maximum window | none (the table grows) |
| Outer margins | 16 pt |
| Gap between columns in the folder panel | 8 pt |
| Gap between rows in the folder panel | 7 pt |
| Table row height | 28 pt, single line (base names don't need a second line) |

The window remembers its size and position (system default). Folders are remembered (approved rule).

## 2. Mode switch: Split | Remux

- It's a `Picker("Mode", selection:)` with `.pickerStyle(.segmented)` in `ToolbarItem(placement: .principal)`. There are two text segments, `Split` and `Remux`, each about 84 pt minimum and equal in width. There's no "Mode:" label; VoiceOver reads it as "Mode".
- Each mode keeps its own folders, scan results, checkbox state and last finish summary. Switching modes swaps the folder panel and the queue, and nothing is lost.
- **It's disabled while a batch runs** (including while cancelling), and it re-enables when the batch finishes or stops. Shortcuts: ⌘1 and ⌘2 in the View menu, which are disabled while running.
- The folder panel is 2 rows tall in Split and 3 rows tall in Remux. The queue absorbs the 32 pt difference. I didn't pad Split to 3 rows because an empty reserved row reads as a missing field.

## 3. Folder picker rows and Scan

- **Split rows:** `Source:` (MKV files) and `Output:` (.mka files).
- **Remux rows:** `Video:` (.mkv files), `Audio:` (.mka files) and `Output:` (finished .mkv).
- **Row layout:** `Grid` with 3 columns:

  | Column | Width | Contents |
  |---|---|---|
  | 1. Label | 92 pt, trailing-aligned | Label in 12.5 pt, with an 10.5 pt secondary line under it that says what the folder holds |
  | 2. Read-only folder field | flexible | 26 pt tall. Folder icon, folder name (medium weight), then the full path in secondary text with **middle truncation**. `.help` shows the full path, and the context menu has Show in Finder. |
  | 3. `Choose…` button | fits its title | Regular bordered button. The ellipsis is there because it opens the open panel. |

- **Empty folder:** a dashed folder glyph plus `No folder chosen` in secondary text.
- **No drag and drop** (approved rule). The field isn't a drop target and isn't editable.
- **Scan row:** right-aligned under the grid. A caption comes first, then the `Scan` button (arrow.clockwise icon, ⌘R).
  - Caption examples: `Scanned 9:12 PM · 7 MKV files`, `Not scanned yet`, `Choose a Source and an Output folder to scan`, `Scan needs mkvmerge`.
  - Scan is disabled until every folder in that mode is chosen and mkvmerge is found. It's also disabled while running.
  - Rescanning replaces the queue. Rows that are still Ready keep their checkbox state when their name still matches.
- **While running:** every Choose… button, the fields, and Scan are disabled (dimmed, not hidden).
- I didn't use NSPathControl. SwiftUI has no native path control, and a pop-up path control would make folder choosing a two-step menu. The read-only field plus Choose… is the simplest and keeps the control in the window body, as the HIG asks.

## 4. Queue table

`Table(rows, selection:, sortOrder:)` with `.alternatingRowBackgrounds()`. The columns are fixed in v1, with no `TableColumnCustomization`.

| # | Header | Width (pt) | Content |
|---|---|---|---|
| 1 | *(none)* | 28 fixed | Checkbox: `Toggle(isOn:).toggleStyle(.checkbox).labelsHidden()` |
| 2 | Name | min 220, ideal 300, flex | Base name, no extension, 13 pt, tail truncation, `.help` full name. Default sort is by name, ascending. |
| 3 | Status | min 140, ideal 160, max 200 | Status label (icon + text), below |
| 4 | Reason | min 220, flex | Issue reason, mkvmerge warning or error message, or `—`. Secondary text, tail truncation, `.help` full message. |

**Statuses (icon + text, never color alone):**

| Status | Symbol (SF) | Text | Color | When |
|---|---|---|---|---|
| Ready | `chevron.forward.circle` | `Ready` | secondary icon, primary text | Scanned OK |
| Issue | `exclamationmark.triangle` (outline) | `Issue` | orange | Flagged at scan. Reason says why. |
| Waiting | `clock` | `Waiting` | secondary | Checked, in the run, not started *(assumption A3)* |
| Splitting… / Remuxing… | small spinner (`ProgressView().controlSize(.small)`) | `Splitting…` / `Remuxing…` | accent spinner | The current file. **No per-file % or bar** (decided) |
| Done | `checkmark.circle.fill` | `Done` | green | mkvmerge exit 0 |
| Done · warning | `exclamationmark.triangle.fill` | `Done · warning` | yellow icon, primary text | **mkvmerge exit 1.** The output exists. Reason holds mkvmerge's warning description when it gives one (**the first warning line** (decided), `Warning:` prefix kept, for example `Warning: timestamps adjusted on track 2`; more than one → first line + `(+2 more)`, all lines in `.help`). **Fallback when there's no text:** `mkvmerge reported a warning (no details)`. |
| Failed | `xmark.octagon.fill` | `Failed` | red | mkvmerge exit 2, or launch failed. Reason holds the short error (`mkvmerge exit 2: not enough disk space`). |

The Issue and warning icons are both triangles, but they differ in fill (outline vs filled), color (orange vs yellow) and text (`Issue` vs `Done · warning`). The text decides.

**Flagged rows:**
- The checkbox is **unchecked and disabled** (approved rule). The row stays full contrast so the reason is readable.
- The row stays selectable, and its context menu is reserved for #14.
- The checkbox gets `.help("Flagged: <reason>")`.

**Checkbox rules:**
- Ready rows start checked.
- **After a natural finish, Done and Done · warning rows are unchecked automatically** (decided). Failed rows stay checked, so pressing Split/Remux again retries only them. If nothing is checked, the primary action is disabled.
- All checkboxes are disabled while running.
- The primary action needs at least one checked row.
- Edit menu and context menu: `Select All Ready` / `Deselect All`. No header checkbox: SwiftUI `Table` headers don't host controls reliably, and a mixed-state header that ignores disabled rows is confusing.

**Empty states** use an overlay (`ContentUnavailableView` is fine on 15+):
- `No files yet`, telling people to choose folders and then click Scan
- `Ready to scan`, when folders are remembered but not scanned
- `Can't scan yet`, when mkvmerge is missing

## 5. Remux pairing display

There's one row per **base name**, which is the union of the two folders. Pairs that match are Ready. Names that exist on one side only are Issues (`No matching .mka in Audio folder`, `No matching .mkv in Video folder`).

The full reason list comes from the scaffold's validation rules, which I didn't read. The reasons in the mockups are illustrative.

## 6. Toolbar primary action and Cancel

- **Idle or finished:** a prominent button `Split` (scissors) or `Remux` (merge symbol), with ⌘↩. It's disabled when nothing is checked, nothing is scanned, or mkvmerge is missing. The disabled `.help` says why.
- **Running:** the same slot becomes `Cancel` (stop.fill, bordered, not prominent) with ⌘. and Esc. The slot keeps a 96 pt minimum width, so the toolbar doesn't jump.
- **Cancel = finish the current file, then stop** (approved rule):
  - Clicking it immediately turns the button into a disabled `Cancelling…` with a small spinner.
  - The subtitle reads `Cancelling · finishing current file`.
  - The bottom bar reads `Finishing The.Expanse.S01E03, then stopping · 2 of 4 complete`.
  - Waiting rows go back to **Ready** (still checked), and their Reason reads `Won't start: batch cancelled` until the stop completes.
  - **There's no confirmation alert.** No finished work is lost, and the file in progress still completes, so the HIG's "negative consequence" case doesn't apply.
- **After the stop:**
  - The bottom bar shows `Stopped · 3 of 4 complete` (MP4SubRip rule). There's no full bar and no `N saved` line.
  - **Show in Finder** stays if at least one file was written (**decided**: kept after Cancel).
  - **No notification and no Dock bounce after a completed Cancel** (decided). The person chose to stop, so the stopped bottom bar is the only feedback.
  - Done rows from the stopped run are unchecked too, the same as after a finish.
  - Rows that didn't run show Ready again, and their Reason returns to `—`.

## 7. Bottom bar, progress and finish summary

`HStack` 52 pt with `.background(.bar)` and a top hairline, added via `.safeAreaInset(edge: .bottom)`. The layout follows MP4SubRip Phase 3:

`[summary] — Spacer — [Show in Finder (finished only)] [progress column 152 pt]`

**Summary (leading, 12.5 pt; the key word or count is semibold):**

| State | Text |
|---|---|
| Idle, no scan | `No files` |
| Scanned | **`7 files`**` · 4 selected · 2 flagged` |
| Running | **`2 of 4 complete`**` · Splitting The.Expanse.S01E03` |
| Cancelling | **`Finishing The.Expanse.S01E03, then stopping`**` · 2 of 4 complete` |
| Stopped | **`Stopped`**` · 3 of 4 complete` |
| Finished | **`Finished`**` · 3 done (1 with warning) · 2 flagged · 1 failed` |

- **Zero counts are hidden** (decided): `Finished · 4 done (1 with warning) · 2 flagged` when nothing failed; `(… with warning)` only when there are warnings; `Finished · 4 done` when that's all.
- **Warning format (decided by me, per Arezhik's ask): a parenthetical on the done count**, `3 done (1 with warning)`. Why: a warning row *is* done (exit 1, the output exists), so a separate `· 1 warning` segment would read as a fourth outcome and make the counts look like they add to more files than ran. The parenthetical keeps done + flagged + failed = rows, and still makes the warning count visible. Plural: `(2 with warnings)`.
- N in `N of M complete` = files checked into this run, not every row. Flagged rows aren't in the run.

**Progress column (152 pt, trailing):**
- A small linear `ProgressView(value: completed, total: filesInRun)` under a caption line.
- **Running:** value = **files completed ÷ files in the run**. It steps forward once per finished file (Done, Done · warning or Failed all count as finished) and reaches 100% when the last file ends. There's no partial fill for the current file and no animation between steps. The caption line stays empty in v1; it's the slot a future ETA would use.
- **Finished:** caption `3 .mka saved` / `3 .mkv saved` (files written this run, including warnings), bar full in the accent tint. The text carries the outcome, not the color.
- The column is absent when idle, so nothing jumps, and it sits in the same place in both modes.
- **ETA: not in v1.** Noted as a possible future feature (it would use the caption line; MP4SubRip's rule is "show only when reliable").

**Show in Finder** (bordered, small) appears after a finish or a Cancel that wrote at least one file. It opens the mode's Output folder and selects this run's outputs when they're all in that folder. It's hidden when the run wrote nothing.

**Batch end (normal finish only; never after a completed Cancel, decided):**
- If MKVForge is in the background, send a notification (when on): title `Batch finished`, body = the summary string.
- If MKVForge is in the background, bounce the Dock icon **once** (when on): `NSApp.requestUserAttention(.informationalRequest)`.
- Neither happens when the app is active. Both settings default to on (decided).

The bottom bar holds only status that's repeated elsewhere (the toolbar subtitle carries the count), and Show in Finder is also in the Output field's context menu, so nothing critical lives only in the bar.

## 8. Settings window

There's one pane, so I left out the toolbar. Title `MKVForge Settings`, ⌘, from the app menu, minimize and zoom dimmed. It's a `Settings { Form { … }.formStyle(.grouped) }`, 540 pt wide, with the height fitted to its content (about 330 pt). It isn't resizable.

**Section "MKVToolNix":**
- **Row 1, `mkvmerge`:** the resolved path in 11 pt monospaced secondary text, with a trailing status (icon + text):
  - `✓ Found · v88.0` (auto-detected)
  - `✓ Chosen · v88.0` (manual)
  - `⚠︎ Not found` (orange triangle + text)
- **Row 2, `Location`:** help text, then buttons:
  - **Found automatically:** help `Found automatically. Choose another copy to override.`, then `Choose…` and a dimmed `Use Automatic`.
  - **Chosen manually:** `Choose…` and an enabled `Use Automatic` (goes back to auto-detect).
  - **Not found:** help `Looked in /Applications, /opt/homebrew/bin and /usr/local/bin.` (the real search list comes from the scaffold, A8), then a `Get MKVToolNix ↗` link (`Link`, opens https://mkvtoolnix.download/ in the default browser; decided), `Search Again` and `Choose…`. Choose… accepts the MKVToolNix .app or the `mkvmerge` binary.
  - **A chosen copy that fails to run:** shows `⚠︎ Can't run this mkvmerge` with the reason in the help line.

**Section "When a batch finishes":**
- `Send a notification`, with help `Only when MKVForge isn't the active app.`, as a mini switch.
- `Bounce the Dock icon`, with help `Once, only when MKVForge is in the background.`, as a mini switch.
- Both default to **on** and fire only when MKVForge is in the background, and only when a batch finishes normally, not after Cancel (decided). If notifications are off in System Settings, the notification row shows an inline note with `Open System Settings…` (same pattern as PGS2SRT Settings Q5).

## 9. MKVToolNix-not-found state (main window)

- An inline banner sits at the top of the window body: an orange-tinted rounded box with a triangle icon.
  - It reads **`MKVToolNix wasn't found.`** plus `MKVForge needs mkvmerge to scan, split and remux. Install MKVToolNix or show MKVForge where it is.`
  - Actions: a `Get MKVToolNix ↗` link (opens https://mkvtoolnix.download/; decided), then `Choose mkvmerge…` and `Settings…` (`SettingsLink`).
- **It's not an alert at launch.** The folders stay usable. Scan and the primary action are disabled with `.help("Needs MKVToolNix")`, and the empty state reads `Can't scan yet`.
- The banner disappears as soon as a working mkvmerge is found. Auto-detect runs again when the app becomes active.

## 10. Reserved room for later features (not designed)

| Issue | Where it will go | What v1 must do now |
|---|---|---|
| #17 console log | A collapsible pane between the table and the bottom bar (`VSplitView`), toggled by a toolbar button left of the primary action | Keep the table in a container that can become a split view. Don't pin the bottom bar to the table. Keep the 760×480 minimum honest by letting the log collapse to 0. |
| #18 track details | A trailing inspector (`.inspector`, 240–320 pt) for the selected row | Keep row selection working, including on flagged rows. Don't put anything at the trailing window edge below the toolbar. |
| #19 dry run | The primary button becomes a split button with a menu (`Split` ▾ `Dry Run`) or a View/Batch menu item | Keep the primary slot as one toolbar item. Don't add a second trailing toolbar item in v1. |
| #14 overrides | The flagged row's context menu (`Override…`) and possibly the Reason cell | Keep flagged rows selectable, and keep the row context menu (Show in Finder for Done rows) |

## 11. Accessibility

- Status is always symbol plus word. Reason text is plain text. Flagged rows aren't dimmed into illegibility. The finished bar color never carries the outcome.
- **VoiceOver:**
  - Each row combines into one element, with label `"<name>, <status>, <reason>"`.
  - The checkbox label is `Include <name>`. When disabled, it has the hint `Flagged: <reason>` and the value `not selectable`.
  - The bar's value is `2 of 4 complete`. The row spinner's label is `Splitting` / `Remuxing`.
  - Mode reads "Mode, Split".
  - Folder fields read `"Source folder, Rips, ~/Movies/Rips"`.
  - Choose… buttons read `Choose Source folder`.
  - The banner is announced once when it appears (`AccessibilityNotification.Announcement`).
- The `Get MKVToolNix` link reads "Get MKVToolNix, link, opens in browser".
- **Keyboard:**

  | Keys | Action |
  |---|---|
  | ⌘↩ | Split / Remux |
  | ⌘. or Esc | Cancel |
  | ⌘R | Scan |
  | ⌘1 / ⌘2 | Switch mode |
  | Space | Toggle the selected row's checkbox |
  | ⌘, | Settings |

  Full Keyboard Access reaches every Choose… button.
- Colors are system semantic colors (`.secondary`, `.orange`, `.yellow`, `.green`, `.red`, `.accentColor`) so they adapt to Increase Contrast and dark mode. The only motion is the system spinner and the progress bar.

## 12. SwiftUI view mapping (macOS 15+, universal)

```
Window("MKVForge", id: "main") → MainView
  .toolbar {
    ToolbarItem(.principal)      Picker(.segmented) Split | Remux        .disabled(isRunning)
    ToolbarItem(.primaryAction)  Button(verb, systemImage:) .buttonStyle(.borderedProminent) ⌘↩ | Cancel ⌘. | Cancelling… (disabled)
  }
  .navigationTitle("MKVForge").navigationSubtitle(statusLine)
  VStack(spacing: 0)
    MKVToolNixBanner?                       // custom HStack, orange 12% fill, 8 pt radius
    FolderPanel: Grid(horizontalSpacing: 8, verticalSpacing: 7)
      GridRow { Text("Source:") + secondary line ; FolderField(url) ; Button("Choose…") → .fileImporter([.folder]) / NSOpenPanel }
      Scan row: HStack { Spacer; Text(caption).secondary; Button("Scan", systemImage: "arrow.clockwise") ⌘R }
    Divider
    Table(rows, selection:, sortOrder:) { checkbox · Name · Status(StatusLabel; running = small spinner + verb) · Reason }
      .alternatingRowBackgrounds() .contextMenu(forSelectionType:) .overlay(empty state)
  .safeAreaInset(edge: .bottom) { BottomBar }   // summary · Spacer · Show in Finder · ProgressColumn(152): ProgressView(value: completedFiles, total: filesInRun)
Settings { SettingsView: Form { Section("MKVToolNix") …; Section("When a batch finishes") { Toggle(…).toggleStyle(.switch).controlSize(.mini) ×2 } }.formStyle(.grouped).frame(width: 540) }
Batch end (background + normal finish only, not after Cancel): UNUserNotificationCenter · NSApp.requestUserAttention(.informationalRequest)   // no Dock badge
Not found: Link("Get MKVToolNix", destination: URL(string: "https://mkvtoolnix.download/")!)
```

Everything above is available on macOS 15. Universal (Apple silicon and Intel) doesn't affect layout.

## 13. Decisions (resolved 2026-11-18 by Arezhik)

| # | Question in v1 | Decided |
|---|---|---|
| 1 | Mode switch while running | **Disabled** while running and cancelling |
| 2 | Zero counts in the finish summary | **Hidden** |
| 3 | Warnings in the summary | **Included**, as `N done (M with warning)` (format chosen in §7) |
| 4 | Done rows after finish | **Unchecked automatically**; Failed stays checked |
| 5 | Auto-scan at launch | **No.** Scan only on click; remembered folders show `Not scanned yet` |
| 6 | Get MKVToolNix link | **Yes**, to https://mkvtoolnix.download/ in the banner and in Settings |
| 7 | Notification + Dock bounce | **On by default, only when the app is in the background** |
| — | Notification + Dock bounce after Cancel | **No.** Only after a normal finish (Arezhik, 2026-11-18 approval) |
| — | Which mkvmerge warning line in Reason | **The first line**, with `(+N more)` and all lines on hover (Arezhik, 2026-11-18 approval) |
| — | Show in Finder after Cancel | **Kept** |
| — | Dock badge | **Removed** |
| — | Progress | **Files-based bar only; no ETA in v1; transient row statuses approved** |

**Open questions:** none.

## 14. Remaining notes against the approved rules (flagged, not changed)

1. **Warning label.** I kept `Done · warning` as the status text (approved in this round). If the scaffold names it differently, only the label changes.

## 15. Cited sources (exact quotes, verified with `designkit cache-quote`)

These were checked against `sources/designkit-cache/`.

**Retrieval times (MST):**
- Toolbars, Lists and tables, Accessibility: 2026-10-30.
- Notifications, Progress indicators, Settings, Segmented controls, Toggles: 2026-11-11, 6:18–6:25 PM.
- Windows: 2026-11-11, 10:30 PM.
- Path controls, Alerts, Buttons: fetched for this brief on 2026-11-18 at 9:16 PM.

**Quotes:**

- **Toolbars** (https://developer.apple.com/design/human-interface-guidelines/toolbars)
  - "Only specify one primary action, and put it on the trailing side of the toolbar."
  - "Items on the trailing edge remain visible at all window sizes."
- **Segmented controls** (https://developer.apple.com/design/human-interface-guidelines/segmented-controls)
  - "Consider using a segmented control to help people switch views in a toolbar or inspector pane."
  - "Use nouns or noun phrases for segment labels."
- **Path controls** (https://developer.apple.com/design/human-interface-guidelines/path-controls)
  - "Use a path control in the window body, not the window frame."
- **Buttons** (https://developer.apple.com/design/human-interface-guidelines/buttons)
  - "Append a trailing ellipsis to the title when a push button opens another window, view, or app."
- **Lists and tables** (https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)
  - "Use descriptive column headings in a multicolumn table."
  - "Consider using alternating row colors in a multicolumn table."
- **Progress indicators** (https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
  - "When possible, use a determinate progress indicator." (the files-based bottom bar)
  - "Display a progress indicator in a consistent location."
  - "Don’t switch from the circular style to the bar style." (The running row uses a spinner throughout and never turns into a bar.)
  - "When it’s feasible, let people halt processing."
  - "Let people know when halting a process has a negative consequence." (Cancel loses nothing, so there's no alert.)
- **Accessibility** (https://developer.apple.com/design/human-interface-guidelines/accessibility)
  - "Convey information with more than color alone."
  - "Describe your app’s interface and content for VoiceOver."
- **Alerts** (https://developer.apple.com/design/human-interface-guidelines/alerts)
  - "Avoid showing an alert when your app starts."
  - "Avoid using an alert merely to provide information."
- **Notifications** (https://developer.apple.com/design/human-interface-guidelines/notifications)
  - "Handle notifications gracefully when your app is in the foreground." (why the notification fires only in the background)
- **Settings** (https://developer.apple.com/design/human-interface-guidelines/settings)
  - "Put general, infrequently changed settings in your custom settings area."
  - "Dim a settings window’s minimize and maximize buttons."
  - "If your settings window doesn’t have multiple panes, use the title App Name Settings."
- **Toggles** (https://developer.apple.com/design/human-interface-guidelines/toggles)
  - "Within a grouped form, consider using a mini switch to control the setting in a single row."
  - "Use switches, checkboxes, and radio buttons in the window body, not the window frame." (This is why there are no checkboxes in the toolbar or bottom bar.)
- **Windows** (https://developer.apple.com/design/human-interface-guidelines/windows)
  - "Avoid putting critical information or actions in a bottom bar, because people often relocate a window in a way that hides its bottom edge."
  - "Choose a minimum and maximum size for each window to help keep your content looking great."

No command certifies HIG compliance. These quotes support specific choices, and visual review is still needed.

## Assumptions

- **A1.** The scaffold was **not read**. Everything comes from the brief's summary. If the scaffold's UI Outline differs, it wins.
- **A2.** The MP4SubRip v2 spec path in the brief is under `macos-dev/projects/`, which I didn't read. I copied the Phase 3 bottom-bar decisions (which supersede v2's bar) from my own Phase 3 sources. My out/mp4subrip finals folders weren't on disk at the time, so I used `work/mp4subrip-phase3/doc/body.md`, the Phase 2/3 renders, and my as-delivered Phase 3 reply in macOS Dev's inbox.
- **A3.** Batches run **one file at a time**: one current row, the rest Waiting. If they run in parallel, several rows show the spinner, and the summary becomes `2 of 4 complete · 2 splitting`.
- **A4.** (v2) Withdrawn: no per-file percentage is shown, so nothing depends on mkvmerge's `Progress:` output.
- **A5.** Each mode has one Output folder, and outputs are named from the base name (Split → `<base>.mka`, Remux → `<base>.mkv`).
- **A6.** (v2) Decided: notification and Dock bounce fire only when the app is in the background, and only on a normal finish (not after Cancel).
- **A7.** (v2) Decided: Show in Finder kept after Cancel.
- **A8.** The auto-detect search locations shown are illustrative: /Applications, /opt/homebrew/bin, /usr/local/bin.
- **A9.** (v2) Decided: both batch-finished toggles default to on.
- **A10.** The 980×640 default and 760×480 minimum are my proposal. Measure the real folder panel and the localized strings in the build.
