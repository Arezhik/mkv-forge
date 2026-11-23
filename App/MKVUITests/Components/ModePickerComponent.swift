import XCTest

// Component: the mode switch. A component owns a region.
// Selecting a segment returns the page for that mode.
//
// The segmented picker has accessibility identifier `modePicker` and
// accessibility label "Mode". Prefer the identifier. The "Mode" label is a fallback.
// The toolbar primary button is also titled "Split" or "Remux". Click a segment
// inside the picker, not `app.buttons["Remux"]`, or the test starts a batch.

/// Split | Remux segmented control in the toolbar.
@MainActor
struct ModePickerComponent {
    let app: XCUIApplication

    /// The mode control. Prefers identifier `modePicker`, then the "Mode" label.
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
        // Prefer `modePicker`. Fall back to the "Mode" label.
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
