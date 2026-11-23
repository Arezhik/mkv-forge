# MKVForge v1 layout contract — v2.2 addendum (Design Bot, 2026-11-21)

**Status: Draft for issue #33, Match on MKA Name.** Arezhik approved the functional rules on 2026-11-21. This addendum adds the layout, strings and accessibility for those rules. Every v2 and v2.1 rule stays as approved. If this addendum and v2 or v2.1 seem to disagree, the earlier text wins, and §4 lists each point I checked.

**Repo:** commit this text as docs/design/v1-layout-contract_v2.2-addendum.md in Arezhik/mkv-forge, next to the v2 and v2.1 files. I assumed the v2.1 rule still applies, so the four PNGs stay out of git in Design Bot's mockups-v2.2 folder, and docs/design/README.md points there (A1). Links below are relative to this file.

**What I worked from:** the macOS Dev (test) brief of 2026-11-21, my approved v2 contract and v2.1 addendum, the public issue page https://github.com/Arezhik/mkv-forge/issues/33, and my Apple HIG cache. **I did not read the repo, any projects folder, or any app or PR code.** The matching behavior is taken from the issue and the brief.

## Confirm with Arezhik

**None blocking.** Each choice below has a default that follows the approved rules. The flags in §4 are defaults that he can overrule but doesn't have to answer.

## Mockups (2× PNG, 1080×760 pt canvas, same 980×640 window and 540 pt Settings as v2)

| Screen | Light | Dark |
|---|---|---|
| Settings · new Remux section, `Match on MKA Name` on | [png](mockups-v2.2/2026-11-21_mkvforge_settings-match-on-mka-name_light.png) | [png](mockups-v2.2/2026-11-21_mkvforge_settings-match-on-mka-name_dark.png) |
| Remux · Ambiguous-match rows, `Choose Match` menu open on X.mka | [png](mockups-v2.2/2026-11-21_mkvforge_remux-ambiguous-match_light.png) | [png](mockups-v2.2/2026-11-21_mkvforge_remux-ambiguous-match_dark.png) |

Magenta callouts are annotations, not UI. The queue mockup shows every #33 row type at once: a prefix pair, a pick by you (Aliens Director's Cut), the pair left after that pick resolved to Ready (Aliens CRF20), an exact pair, a one-sided Issue, the #30 existing-output Issue, and the brief's X.mka + X.mkv + X Extended.mkv group, still unresolved.

---

## A. Settings · Match on MKA Name

### A.1 Placement and strings

- **New section `Remux`** in v2 §8's single grouped Form, **between "MKVToolNix" and "When a batch finishes".** It comes after the tool section, because mkvmerge applies to both modes, and before the post-batch section, because it changes what a scan finds.
- One row, the same pattern as v2's notification rows:
  - Label: `Match on MKA Name`
  - Help, line 1: `Pairs each .mka with the video file whose name starts with the .mka name. The finished file keeps the full video name.`
  - Help, line 2: `Changing this clears the Remux queue. Scan again afterward.`
  - Control: a trailing **mini switch**, `Toggle(isOn:)` with `.toggleStyle(.switch).controlSize(.mini)`, the same as v2 §8.
- **Default: on.** Store it in `@AppStorage`, with the key left to Dev.
- **Off** brings back v2 §5 exact matching, unchanged.

### A.2 Window height

Settings is still 540 pt wide, not resizable, and fitted to its content. The new section adds about **120 pt**: the 22 pt section header, the 3-line row and the group spacing. With mkvmerge found, the pane goes from v2's **about 330 pt to about 450 pt** (the mockup draws it at about 475 pt including the title bar). The not-found state is taller by the same amount as in v2. Don't hard-code the height. Let `Form` size it.

### A.3 What changing it does to the Remux view

- **Right away, even when Remux isn't the active mode:** the Remux queue, any picks (§B), the Remux undo actions and the last Remux summary are dropped. The Split queue isn't touched.
- The Remux view goes back to the approved v2 not-scanned state: the caption `Not scanned yet` in the Scan row, and the `Ready to scan` empty overlay in the table. The bottom bar shows nothing, and the primary `Remux` button is disabled, because nothing has been scanned (v2 §6).
- **No extra caption.** `Not scanned yet` plus the help line already say what happened.
- If Remux is the visible mode, VoiceOver posts the announcement `Remux queue cleared. Scan again.` (`AccessibilityNotification.Announcement`). There's no announcement when the Split view is showing.
- **The switch is disabled while a Remux batch runs or a Remux scan is in progress.** Its help gets a third line, `Available when Remux isn't running.` Otherwise, flipping it would clear a queue that's still being worked on (flag F1).
- Folders aren't touched. The user just clicks Scan (⌘R) again.

### A.4 Accessibility

- VoiceOver reads the label as the switch label and the two help lines as its hint, using `.accessibilityHint`.
- When it's disabled, VoiceOver says "dimmed", and the third line becomes the hint.
- Tab and Space work with Full Keyboard Access, the same as v2's other switches.

---

## B. Ambiguous match (Remux, Match on MKA Name on)

### B.1 Rows

v2 §5 says there's "one row per base name". With matching on, **a row is a pair or a single unpaired file**. The extension is flag F2.

| Case | Name column | Status | Reason | Checkbox |
|---|---|---|---|---|
| Exact pair (V == K) | base name, as in v2 | `Ready` | `—` | checked |
| Prefix pair, one-to-one (V ≠ K) | video base name V, then a secondary `↔ K.mka` | `Ready` | `—` | checked |
| Pair you picked | V, plus `↔ K.mka` when V ≠ K | `Ready` | `Matched by you` + `Unmatch` | checked |
| Ambiguous candidate | **the full file name with its extension** (`X.mka`, `X.mkv`, `X Extended.mkv`) | `Issue` | `Ambiguous match` + `Choose Match` | unchecked, disabled |
| Unmatched | base name | `Issue` | `No matching .mka in Audio folder` / `No matching .mkv in Video folder` (v2, unchanged) | unchecked, disabled |
| Output already exists | as the pair would show | `Issue` | `Output already exists` (§C) | unchecked, disabled |

- **Why extensions on ambiguous rows:** X.mka and X.mkv have the same base name. Without the extension, two rows would read `X`. Only ambiguous rows get extensions. Every other row keeps v2's base-name rule.
- **`↔ counterpart`:** 11.5 pt secondary text after the name, separated by a 6 pt gap. It uses **middle truncation**, so the end and the .mka extension stay visible, and it truncates **before** the video name does. `.help` on the cell shows both full file names: `Arrival.2016 CRF21.mkv ↔ Arrival.2016.mka`.
- **Sorting** uses the shown name (V, or the file name for ambiguous rows), case-insensitive. Candidates in one group end up next to each other because they share the prefix K.
- **The status stays `Issue`.** No new status is added. The reason carries the meaning, which matches v2's rule that the text decides.

### B.2 The picker: `Choose Match`

- **Control:** a compact **pull-down button**, placed in the Reason cell right after the `Ambiguous match` text, with an 8 pt gap. SwiftUI: `Menu("Choose Match") { … }`, `.menuStyle(.button)`, `.controlSize(.small)`, `.fixedSize()`. The reason text truncates before the button does.
- **Why a pull-down and not a pop-up:** a pop-up button shows a current value and should have a default. The rule here is "never auto-picked", so there's no default to show. A pull-down shows a fixed title and lists actions, so it never looks pre-selected.
- **Title `Choose Match`, without an ellipsis.** The brief suggested `Choose match…`. The HIG puts an ellipsis on a menu *item* that needs more input before it finishes. This button opens a menu and finishes on one click, and title style matches the other MKVForge buttons (flag F3).
- **Menu contents** (only this row's candidates):
  - A section header: `Pair X.mka with` (or `Pair X.mkv with` on a video row). `Section("Pair \(file) with")`.
  - One item per candidate, as the **full file name with its extension**, sorted case-insensitively: `X Extended.mkv`, `X.mkv`.
  - Nothing else: no "Ignore" item and no default.
- **Both directions:** a .mka row lists its candidate .mkv files, and a .mkv row lists its candidate .mka files. Every candidate row in the group has its own `Choose Match`. Picking from any of them gives the same result.
- **Future close-name candidates (extensibility, not designed):** the menu is built from a list of `(file, reason)` candidates. A later fuzzy-match feature can add a second `Section("Close names")` to this same menu, and nothing else changes. #33 only fills the prefix section.

### B.3 What a pick does

Using the brief's example (X.mka + X.mkv + X Extended.mkv; X.mka matches both videos):

1. In row X.mka, Choose Match › `X Extended.mkv`.
2. That pair becomes **one row**: `X Extended ↔ X.mka`, `Ready`, **checked**, Reason `Matched by you` + `Unmatch`. The output name is the full video name (X Extended.mkv), as #33 says.
3. Both files **leave every other candidate list.** The other rows are re-evaluated with the normal rules:
   - one candidate left → `Ready` pair, checked
   - no candidates left → the usual v2 one-sided Issue (here X.mkv → `No matching .mka in Audio folder`)
   - still 2+ → stays `Ambiguous match`, with a shorter menu
4. A pair that turns Ready this way is then checked for §C. If its output exists, it becomes `Output already exists` instead.
5. The queue keeps the current sort. The selection follows the new pair row, and focus moves to that row's checkbox.
6. VoiceOver announcement: `Paired X.mka with X Extended.mkv.` Toolbar subtitle and bottom-bar counts update as usual.

Issue's Aliens cases come out the same way: 4 ambiguous rows → pick DC ↔ DC CRF21 → both pairs Ready; or 3 ambiguous rows → pick CRF21 → that pair Ready and CRF20 becomes `No matching .mka in Audio folder`.

### B.4 Undo and changing a pick

- **`Unmatch`:** a small borderless link-style button (`Button("Unmatch").buttonStyle(.link).controlSize(.small)`) in the Reason cell of a picked row, right after `Matched by you`. It splits the pair and re-evaluates the whole group with any other picks that are still in place. Usually this brings back the original Ambiguous rows.
- **Edit › Undo Match (⌘Z)** and **Redo Match (⇧⌘Z)**, from the window's `UndoManager`, with the action name `Match`. Each pick and each Unmatch is one undo step.
- **To change a pick:** click Unmatch, then Choose Match again. There's no "re-pick" item on a matched row, so there's one path in and one path out.
- The undo stack for matching is cleared whenever picks are cleared (B.5).
- Unmatch and Choose Match are disabled while a batch runs or a scan is in progress (v2 locks the queue).

### B.5 When picks are cleared

Picks are dropped on **Scan (⌘R)**, on **any Remux folder change** (Video, Audio or Output), and on **any change to Match on MKA Name** (§A.3). After a re-scan, the group shows as Ambiguous again. That's on purpose, and v2 §3's "keep check state when the name matches" doesn't keep picks.

v2.1 §2.4 still applies: if a re-scan is stopped with Esc, the old rows come back exactly as they were, **with their picks**.

### B.6 Keyboard and VoiceOver

- **Full Keyboard Access:** Tab goes to the row's Choose Match button, Space opens the menu, the arrow keys move through it, and Return picks. Esc closes the menu without picking. Unmatch is reached with Tab and pressed with Space.
- **Row label:** `X.mka, Issue, Ambiguous match, 2 possible matches`. For a picked row: `X Extended paired with X.mka, Ready, matched by you`.
- **Picker label:** `.accessibilityLabel("Choose match for X.mka")`, with the hint `Lists the files this one could pair with.`
- **Unmatch label:** `Unmatch X Extended from X.mka`.
- **Tooltip** (`.help`) on Ambiguous match: `X.mka matches 2 video files. Choose the right one.` (on a video row: `X.mkv matches 2 audio files. Choose the right one.`).
- The checkbox's v2 `.help("Flagged: <reason>")` reads `Flagged: Ambiguous match`.
- **Not color alone:** the state is text (`Ambiguous match`, `Matched by you`) plus v2's triangle icon.

### B.7 Bottom bar and toolbar

There's no new count. Ambiguous rows count as **flagged** in v2's `N files · M selected · K flagged`. A pair counts as one row. The mockup shows `9 files · 4 selected · 5 flagged`. When every Ready row is unchecked or flagged, v2's disabled-primary rule applies, and the disabled `.help` reads `Choose a match or check a Ready row.` when ambiguous rows exist.

---

## C. Output already exists (#30 context)

**Specified for #30.** #33 needs it for Remux, because the issue's test case says an existing output is an Issue and is never overwritten. Whether Split gets it in #33 or waits for #30 is up to Dev.

- **When:** at scan, and again after a pick or an Unmatch, **only for rows that would otherwise be Ready**. If a file with the output name is already in the Output folder (Remux: the full video name .mkv; Split: `<base>.mka`, v2 A5), the row becomes:
  - Status `Issue`, Reason **`Output already exists`**, checkbox unchecked and disabled (v2's flagged-row rule).
  - `.help`: `“X Extended.mkv” is already in the Output folder. MKVForge never overwrites it.`
  - VoiceOver: `<name>, Issue, Output already exists`.
- **Never overwritten.** There's no overwrite prompt in v1. A future #14 override in the row context menu, which v2 reserved for #14, could allow it.
- **Why Issue and not a warning:** the brief's #30 note calls it a "warning". In v2, "warning" means only mkvmerge exit 1 (`Done · warning`), and a file that MKVForge won't process is a flagged row (flag F4).
- An ambiguous row isn't checked for this until it's paired, because its output name isn't known yet.

---

## 4. Conflicts and extensions checked against v2 / v2.1 (flagged, not changed)

- **F1 · Switch disabled during Remux run or scan.** This is new. v2 §8 doesn't lock Settings. It's needed because changing the switch clears the queue.
- **F2 · Rows are pairs, not base names.** v2 §5 says "one row per base name". With matching on, a pair's name is the video's base name, and ambiguous rows show file names with extensions. v2 §4's "base name, no extension" still applies to every other row. With matching off, v2 §5 is unchanged.
- **F3 · `Choose Match` instead of the brief's `Choose match…`.** See §B.2. If Arezhik prefers the brief's wording, it's a one-string change.
- **F4 · Existing output is `Issue`, not a warning.** See §C.
- **F5 · New reason strings:** `Ambiguous match`, `Matched by you`, `Output already exists`. v2 §5 says its reason list is illustrative, so these add to it without replacing anything.
- **F6 · Undo Match in the Edit menu** is new. v2's Edit menu had only `Select All Ready` / `Deselect All`, which stay.
- **No conflict:** statuses, colors, the checkbox rules, v2's re-scan keep-checked rule (picks aren't kept, but check state still is), v2.1 G2 dimming and Esc restore, and the v2 empty states and captions are used as approved.

## 5. Cited sources (exact quotes, verified with designkit cache-quote)

Times are MST. Pull-down buttons, Menus and Undo and redo were fetched for this addendum on 2026-11-21 at about 6:29 PM. Pop-up buttons was fetched 2026-11-10 at 10:11 PM, Toggles 2026-11-11 at 6:25 PM, and Settings 2026-11-11 at 6:18 PM. Accessibility and Lists and tables were cached 2026-10-29.

- **Pull-down buttons** (https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons)
  - "A pull-down button displays a menu of items or actions that directly relate to the button’s purpose."
  - "Display a succinct menu title only if it adds meaning."
- **Pop-up buttons** (https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons)
  - "Provide a useful default selection." (why a pop-up doesn't fit a never-auto-picked choice)
- **Menus** (https://developer.apple.com/design/human-interface-guidelines/menus)
  - "Append an ellipsis to a menu item’s label when the action requires more information before it can complete."
  - "To be consistent with platform experiences, use title-style capitalization."
- **Undo and redo** (https://developer.apple.com/design/human-interface-guidelines/undo-and-redo)
  - "Briefly and precisely describe the operation to be undone or redone."
  - "Place undo and redo commands in the Edit menu and support the standard keyboard shortcuts."
- **Toggles** (https://developer.apple.com/design/human-interface-guidelines/toggles)
  - "Within a grouped form, consider using a mini switch to control the setting in a single row."
- **Settings** (https://developer.apple.com/design/human-interface-guidelines/settings)
  - "Put general, infrequently changed settings in your custom settings area."
- **Lists and tables** (https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)
  - "Consider ways to preserve readability of text that might otherwise get clipped or truncated."
- **Accessibility** (https://developer.apple.com/design/human-interface-guidelines/accessibility)
  - "Convey information with more than color alone."

No command certifies HIG compliance.

## Assumptions

- **A1.** The PNGs stay out of git, as they did for v2.1, unless Arezhik says otherwise.
- **A2.** Matching follows the #33 issue text: K is the .mka name without its extension, and a .mkv stem V matches when V starts with K, case-insensitive (V == K included). Close or fuzzy names (the issue's Open Questions 2–5) are out of scope.
- **A3.** The scanner knows each row's candidate list, so the UI can rebuild the menus and re-evaluate after a pick without a new scan.
- **A4.** Mockup file names, sizes and times are illustrative.
