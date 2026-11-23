import XCTest

// Component: the mode switch. A component owns a region.
// Selecting a segment returns the page for that mode.
//
// On main the segmented picker has accessibilityLabel "Mode" and no identifier.
// Identifier `modePicker` arrives with PR #36.
// The toolbar primary button is also titled "Split" or "Remux". Click a segment
// inside the picker, not `app.buttons["Remux"]`, or the test starts a batch.

/// Split | Remux segmented control in the toolbar.
@MainActor
struct ModePickerComponent {
    let app: XCUIApplication

    /// `modePicker` when this build has it (PR #36). Otherwise the "Mode" control.
    var element: XCUIElement {
        let identified = app.descendants(matching: .any)["modePicker"]
        if identified.exists {
            return identified
        }
        let segmented = app.segmentedControls["Mode"]
        if segmented.exists {
            return segmented
        }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Mode")).firstMatch
    }

    /// Clicks the segment titled `title` ("Split" or "Remux") inside the picker.
    @discardableResult
    func select(_ title: String, timeout: TimeInterval = UITestTimeout.standard) -> Self {
        let picker = resolvedPicker(timeout: timeout)
        let segment = picker.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR title == %@", title, title)
        ).firstMatch
        segment.clickWhenReady(
            timeout: UITestTimeout.short,
            message: "The \(title) segment in the Mode picker never showed up"
        )
        return self
    }

    /// Switches the main window to Remux and returns that page.
    @discardableResult
    func selectRemux() -> RemuxPage {
        select("Remux")
        return RemuxPage(app: app)
    }

    /// Switches the main window to Split and returns that page.
    @discardableResult
    func selectSplit() -> SplitPage {
        select("Split")
        return SplitPage(app: app)
    }

    private func resolvedPicker(timeout: TimeInterval) -> XCUIElement {
        // `modePicker` is the PR #36 identifier. The label fallback is what main has today.
        let identified = app.descendants(matching: .any)["modePicker"]
        let segmented = app.segmentedControls["Mode"]
        let labeled = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Mode")).firstMatch
        if let picker = UITestWait.firstExisting([identified, segmented, labeled], timeout: timeout) {
            return picker
        }
        XCTFail("The Mode picker never showed up")
        return labeled
    }
}
