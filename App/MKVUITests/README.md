# XCUITest layout

Playwright-style page objects for `MKVForgeUITests`. Tests stay thin. Screens and regions own the locators.

Every UI test lives in `Tests/` and subclasses `BaseUITest`. That includes `HelloWorldUITests`, `RemuxMatchOnMKANameUITests`, and `MainWindowSmokeUITests`. `UITestFixtureBuilder.swift` stays in this folder. Tests call it through `UITestFixtures` / `fixtures`.

```
App/MKVUITests/
├── UITestFixtureBuilder.swift         # temp folders and media; called through UITestFixtures
├── README.md
├── Tests/                             # every UI test; each subclasses BaseUITest
│   ├── HelloWorldUITests.swift
│   ├── MainWindowSmokeUITests.swift
│   └── RemuxMatchOnMKANameUITests.swift
├── Pages/                             # one class per major screen
├── Components/                        # reusable UI regions
├── Helpers/                           # waits, extensions, fixture forwarder
└── Base/                              # BasePage and BaseUITest
```

## Playwright mapping

| Here | Playwright |
| --- | --- |
| `Pages/` | page objects. A page owns locators and actions for one screen. Navigation returns the next page or component. |
| `Components/` | component classes. A component owns one region (a folder field, the mode picker, a queue row). |
| `Helpers/` | fixtures and utilities. `UITestFixtures` forwards to `UITestFixtureBuilder`. `XCUIElement+UITest` is waits and text matching. |
| `Base/BaseUITest` | the test fixture / `beforeEach`. It builds fixtures, launches, and cleans up. |
| `Base/BasePage` | base page. Holds `XCUIApplication` and the window root. |
| `Tests/` | the spec. Steps only. No locators inline. |

`MainWindowPage` holds the shared chrome (window, mode picker, folder fields, Scan, toolbar primary action, queue). `SplitPage` and `RemuxPage` specialize it. Launch opens **Split**. Video and Audio fields are not on screen until a test calls `switchToRemux()`.

`SettingsPage` wraps the Settings scene (`SettingsView`: MKVToolNix section, "When a batch finishes" toggles). `SettingsPage.open(in:)` uses the MKVForge application menu item "Settings…". If that title differs, construct `SettingsPage(app:)` after the window is up and use `mkvToolNixSection`, `sendNotificationToggle`, and `bounceDockIconToggle`.

## Launch

`BaseUITest` launches with:

```swift
app.launchArguments = ["--uitesting"]
```

That is the only argument. Replace the arguments. Do not append. Do not add `-ApplePersistenceIgnoreState YES`. Combined with `--uitesting`, which already disables restorable state, that flag suppresses the SwiftUI main Window: the app activates and has 0 windows (docs/LESSONS.md L34, verified 2026-11-22).

`setUp() async throws` creates a `UITestFixtureBuilder`, calls `try await prepareFixtures()`, launches, and `tearDown() async throws` calls `cleanup()`. The async overrides are what an `@MainActor` `XCTestCase` can use. XCTest's synchronous `setUp` is nonisolated. Only `BaseUITest` overrides `setUp`. A test overrides `prepareFixtures() async throws` to seed files **before** launch. Do not override `setUp`, `setUpWithError`, or `tearDown`. Do not call `app.launch()` or construct `XCUIApplication` in a test. The base does not seed media. A window-and-folders smoke needs no files.

## Environment

`UITestFixtures.launchEnvironment` sets these from the builder folders. `UITestingLaunch` reads them only when `--uitesting` is present:

| Variable | Folder |
| --- | --- |
| `UITEST_SOURCE_DIR` | `fixtures.input` (Split Source) |
| `UITEST_OUTPUT_DIR` | `fixtures.output` |
| `UITEST_VIDEO_DIR` | `fixtures.video` (Remux Video) |
| `UITEST_AUDIO_DIR` | `fixtures.audio` (Remux Audio) |

The seeded field's accessibility label looks like `Source folder, input, /path/…/input`. Assert a path fragment such as `"input"` or `"output"` through `FolderFieldComponent`.

## Window and element queries

Do not look up the main window with `app.windows["MKVForge"]`. SwiftUI `Window("MKVForge", id: "main")` often has a hidden or empty title, and the identifier is an internal id such as `main-AppWindow-1`. That subscript requires the identifier or the title to be `MKVForge`, so the window never matches. Do not hardcode the internal id.

`MainWindowPage.root` is `app.mainWindow`: the window whose title does not contain `Settings`. An empty title still matches. `BasePage.root` stays `app.windows.firstMatch` when that screen is the only window. Settings is not `app.windows["MKVForge Settings"]` alone. Match a title or label that contains `Settings`, and read `MKVForge Settings` from `app.staticTexts`.

Do not walk `descendants(matching: .any)`. That snapshot times out on macOS ("Timed out while evaluating UI query"). Query one element type (`buttons`, `staticTexts`, `switches`, `checkBoxes`, `groups`, `progressIndicators`, and so on). `MainWindowPage.scanButton` is `app.buttons["Scan"]`.

## Finding SwiftUI text

SwiftUI `Text` on macOS exposes its string as `value`. `label` is often empty. A scanned row's value looks like `sample, Issue, Empty file…`.

`containing` matches descendants, so a `StaticText` never matches `label CONTAINS`. Use `matching` with `label CONTAINS %@ OR value CONTAINS %@`. `XCUIElementQuery.matchingLabelOrValue(containing:)` and `matchingLabelOrValue(equalTo:)` do that. Do not write a raw `containing` query. On a failed row check, `QueueRowComponent` includes the observed queue-row labels and values in the assertion message (docs/LESSONS.md L35).

`QueueRowComponent.requireExists` prefers `identifier == "queueRow" AND (label CONTAINS stem OR value CONTAINS stem)`, then `matchingLabelOrValue(containing:)`.

`QueueRowComponent.requireExactLabel` keeps the Remux #33 query as its primary match: `identifier == "queueRow" AND label == expected` (for example `"<stem>, Ready"` or `"<stem>, Issue, No matching .mka in Audio folder"`). It also accepts `value == expected` on that same `queueRow`. The failure message lists `queueRow` labels.

Folder fields are different: they set `accessibilityLabel` explicitly, so `label` holds `Source folder, input, …`. `FolderFieldComponent` reads `uiText`, which prefers `label` and falls back to `value`.

## Accessibility identifiers

| Identifier | What |
| --- | --- |
| `sourceFolder` | Split Source field (`\(role.rawValue)Folder`) |
| `outputFolder` | Output field (both modes) |
| `videoFolder` | Remux Video field |
| `audioFolder` | Remux Audio field |
| `modePicker` | The segmented mode control. Also labeled `"Mode"`. `ModePickerComponent` prefers this id and keeps the `"Mode"` label as a fallback. |
| `queueRow` | A queue row. Label like `"<stem>, Ready"` or `"<stem>, Issue, <reason>"`. `QueueRowComponent` prefers this id and keeps `matching` on `label` or `value` as a fallback. |
| `primaryAction` | The toolbar Split, Remux, or Cancel button. Not the mode segment. Its accessibility label is that title. `assertPrimary(titled:enabled:)` and `clickPrimaryAction(titled:)` use this id. |
| `scanStatus` | The scan-row caption. Label is `Scan status`. The caption is the value. |
| `toolBanner` | The MKVToolNix-missing banner. The title text is `MKVToolNix wasn't found.` |
| `bottomSummary` | The bottom-bar summary. Its accessibility label is the plain summary, such as `Finished · 1 done`. |
| `showInFinder` | The bottom-bar Show in Finder button. Not the folder-field or row context-menu item of the same title. Do not click it. |
| `batchProgressCaption` | The finished-run caption under the progress bar. The text is exact, such as `1 .mka saved`. |
| Scan button | Title `"Scan"`. Disabled without MKVToolNix. `MainWindowPage.clickScanOrSkip()` throws `XCTSkip("Scan is disabled (needs MKVToolNix); folder seeding was verified")` when `isEnabled` is false. Do not fail the test for a missing tool. Do not query `app.buttons["Scan"]` from a test. |

The toolbar primary button is titled `"Split"` or `"Remux"` while idle, so it is easy to click it instead of the mode segment. `ModePickerComponent` clicks a segment **inside** the picker. `switchToRemux()` uses that segment. `clickPrimaryAction(titled:)` clicks identifier `primaryAction`. It is not the mode switch.

## Fixtures

`UITestFixtureBuilder.swift` stays at `App/MKVUITests/`. `UITestFixtures` creates it, cleans it up, and maps its folders onto the launch environment. Do not copy `createDummyFile` or `createValidMediaFile`. Call them on `fixtures` from `prepareFixtures()`.

`createValidMediaFile` throws `XCTSkip` when ffmpeg is missing. A file modified in the last minute is "still changing", which blocks Ready. `fixtures.settle(_:)` sets the modification date back two minutes. `HelloWorldUITests` uses dummy files, which stay in the queue as an empty-file issue and never need mkvmerge. `RemuxMatchOnMKANameUITests` uses settled valid media and does not open Settings.

## Adding a test

Run `./scripts/scaffold-xcuitest.sh <FlowName>`. When `Tests/` and `Base/BaseUITest.swift` exist, it writes `Tests/<Flow>UITests.swift` as an `@MainActor` `BaseUITest` subclass. The generated test overrides `prepareFixtures() async throws`, uses pages and `XCTContext.runActivity`, and does not click Scan. It does not override `setUp` or call `app.launch()`. It does not add `-ApplePersistenceIgnoreState YES`.

If `Tests/` or `Base/BaseUITest.swift` is missing, the script writes a root `*UITests.swift` instead. That fallback still launches with `--uitesting` only.

Put steps in the test. Keep locators on pages and components. Keep edge cases in `MKVForgeCoreTests`.

`Tests/MainWindowSmokeUITests` checks the window and the Source and Output fragments only. It does not click Scan and it does not switch to Remux.

`HelloWorldUITests` seeds `sample.mkv` / `sample.mka`, checks the Split folders, calls `clickScanOrSkip()`, and `queueRow(stem: "sample").requireExists()`.

`RemuxMatchOnMKANameUITests` seeds a settled video-only matched pair and an unmatched video, calls `switchToRemux()`, checks the `"video"` / `"audio"` / `"output"` fragments, calls `clickScanOrSkip()`, then `requireExactLabel` for `"<video stem>, Ready"` and `"<unmatched stem>, Issue, No matching .mka in Audio folder"`.
