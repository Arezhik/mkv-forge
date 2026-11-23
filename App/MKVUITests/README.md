# XCUITest layout

Playwright-style page objects for `MKVForgeUITests`. Tests stay thin. Screens and regions own the locators.

`HelloWorldUITests.swift`, `RemuxMatchOnMKANameUITests.swift`, and `UITestFixtureBuilder.swift` stay in this folder. Do not move them until the migration below. Do not rewrite `RemuxMatchOnMKANameUITests.swift` here.

```
App/MKVUITests/
├── HelloWorldUITests.swift            # existing test; stays here for now
├── RemuxMatchOnMKANameUITests.swift   # from #36; stays here. Do not rewrite or move it in this PR.
├── UITestFixtureBuilder.swift         # temp folders and media; stays here for now
├── README.md
├── Tests/                        # thin test cases only
├── Pages/                        # one class per major screen
├── Components/                   # reusable UI regions
├── Helpers/                      # waits, extensions, fixture forwarder
└── Base/                         # BasePage and BaseUITest
```

## Playwright mapping

| Here | Playwright |
| --- | --- |
| `Pages/` | page objects. A page owns locators and actions for one screen. Navigation returns the next page or component. |
| `Components/` | component classes. A component owns one region (a folder field, the mode picker, a queue row). |
| `Helpers/` | fixtures and utilities. `UITestFixtures` forwards to `UITestFixtureBuilder`. `XCUIElement+UITest` is waits and text matching. |
| `Base/BaseUITest` | the test fixture / `beforeEach`. It builds fixtures, launches, and cleans up. |
| `Base/BasePage` | base page. Holds `XCUIApplication` and the window root. |
| `Tests/` | the spec. Steps only. No new locators inline. |

`MainWindowPage` holds the shared chrome (window, mode picker, folder fields, Scan, toolbar primary action, queue). `SplitPage` and `RemuxPage` specialize it. Launch opens **Split**. Video and Audio fields are not on screen until a test calls `switchToRemux()`.

`SettingsPage` wraps the Settings scene (`SettingsView`: MKVToolNix section, "When a batch finishes" toggles). `SettingsPage.open(in:)` uses the MKVForge application menu item "Settings…". If that title differs, construct `SettingsPage(app:)` after the window is up and use `mkvToolNixSection`, `sendNotificationToggle`, and `bounceDockIconToggle`.

## Launch

`BaseUITest` launches with:

```swift
app.launchArguments = ["--uitesting"]
```

That is the only argument. Do not add `-ApplePersistenceIgnoreState YES`. Combined with `--uitesting`, which already disables restorable state, that flag suppresses the SwiftUI main Window: the app activates and has 0 windows (docs/LESSONS.md L34, verified 2026-11-22).

`setUp() async throws` creates a `UITestFixtureBuilder`, calls `prepareFixtures()` (empty in the base), launches, and `tearDown() async throws` calls `cleanup()`. The async overrides are what an `@MainActor` `XCTestCase` can use. XCTest's synchronous `setUp` is nonisolated. Override `prepareFixtures()` to seed files **before** launch. Do not replace `setUp` in a subclass. The base does not seed media. A window-and-folders smoke needs no files. Do not call `app.launch()` again in the test.

## Environment

`UITestFixtures.launchEnvironment` sets these from the builder folders. `UITestingLaunch` reads them only when `--uitesting` is present:

| Variable | Folder |
| --- | --- |
| `UITEST_SOURCE_DIR` | `fixtures.input` (Split Source) |
| `UITEST_OUTPUT_DIR` | `fixtures.output` |
| `UITEST_VIDEO_DIR` | `fixtures.video` (Remux Video) |
| `UITEST_AUDIO_DIR` | `fixtures.audio` (Remux Audio) |

The seeded field's accessibility label looks like `Source folder, input, /path/…/input`. Assert a path fragment such as `"input"` or `"output"` through `FolderFieldComponent`.

## Finding SwiftUI text

SwiftUI `Text` on macOS exposes its string as `value`. `label` is often empty. A scanned row's value looks like `sample, Issue, Empty file…`.

`containing` matches descendants, so a `StaticText` never matches `label CONTAINS`. Use `matching` with `label CONTAINS %@ OR value CONTAINS %@`. `XCUIElementQuery.matchingLabelOrValue(containing:)` does that. Do not write the `containing` query in a new test.

Folder fields are different: they set `accessibilityLabel` explicitly, so `label` holds `Source folder, input, …`. `FolderFieldComponent` reads `uiText`, which prefers `label` and falls back to `value`.

## Accessibility identifiers

These identifiers are on main and in this tree:

| Identifier | What |
| --- | --- |
| `sourceFolder` | Split Source field (`\(role.rawValue)Folder`) |
| `outputFolder` | Output field (both modes) |
| `videoFolder` | Remux Video field |
| `audioFolder` | Remux Audio field |
| `modePicker` | The segmented mode control. Also labeled `"Mode"`. `ModePickerComponent` prefers this id and keeps the `"Mode"` label as a fallback. |
| `queueRow` | A queue row. Label like `"<stem>, Ready"` or `"<stem>, Issue, <reason>"`. `QueueRowComponent` prefers this id and keeps `matching` on `label` or `value` as a fallback. |
| Scan button | Title `"Scan"`. Disabled without MKVToolNix. `XCTSkip` when `isEnabled` is false. Do not fail the test for a missing tool. |

The toolbar primary button is titled `"Split"` or `"Remux"` while idle, so it is easy to click it instead of the mode segment. `ModePickerComponent` clicks a segment **inside** the picker. `primaryActionButton(titled:)` is the toolbar button and starts work. It is not the mode switch.

## Adding a test

Put a new thin test in `Tests/`. Subclass `BaseUITest`. Use pages and components. Name steps with `XCTContext.runActivity` when a sequence is easier to read that way. Keep edge cases in `MKVForgeCoreTests`.

`scripts/scaffold-xcuitest.sh` still writes `App/MKVUITests/<Flow>UITests.swift` and subclasses `XCTestCase` directly. Prefer `Tests/` and `BaseUITest` (still `--uitesting` only). PR #44 has merged, and its row-query note is already in that template. This branch does not move the script's output into `Tests/`.

`UITestFixtureBuilder.swift` stays at `App/MKVUITests/`. Helpers wrap it. They do not copy `createDummyFile` or `createValidMediaFile`.

## Migration (do not do this on the scaffold branch)

PR #36 and PR #44 have merged. `RemuxMatchOnMKANameUITests.swift` is in this tree. Do not rewrite it here, and do not move it in this PR. `HelloWorldUITests` already has the #44 row-query fix (`matching` + `label CONTAINS` OR `value CONTAINS`). Migrate that later. Do not re-fix the query on this branch, and do not move `HelloWorldUITests.swift` in this PR.

Later:

1. Move existing tests into `Tests/`. Leave `UITestFixtureBuilder.swift` here until a later change, and keep calling it through `UITestFixtures`.
2. `HelloWorldUITests` should subclass `BaseUITest` and use `SplitPage`, `FolderFieldComponent`, and `QueueRowComponent`. Seed `sample.mkv` / `sample.mka` in `prepareFixtures()`. Keep the #44 row query when you migrate. Do not re-fix it.
3. When `RemuxMatchOnMKANameUITests.swift` moves:
   - `BaseUITest` owns launch (`--uitesting` only), the four `UITEST_*` variables, and `cleanup()`.
   - `prepareFixtures()` keeps today's setup: valid video, audio, and unmatched files, with modification dates settled so the "still changing" rule does not flag them.
   - `RemuxPage.switchToRemux()` replaces the private `selectRemux` helper. It must keep clicking the segment inside `modePicker`, not the toolbar Remux button.
   - `videoFolder`, `audioFolder`, and `outputFolder` replace the seeded-folder asserts (`"video"`, `"audio"`, `"output"`).
   - `scanButton` stays the Scan click, with the same `XCTSkip` when Scan is disabled.
   - `QueueRowComponent.requireExactLabel` replaces the `queueRow` label asserts: `"<video stem>, Ready"` and `"<unmatched stem>, Issue, No matching .mka in Audio folder"`.
   - The test does not open Settings. Match on MKA name defaults on, and `--uitesting` starts from a cleared defaults suite.

`Tests/MainWindowSmokeUITests` is the example. It checks the window and the Source and Output fragments only. It does not click Scan and it does not switch to Remux.
