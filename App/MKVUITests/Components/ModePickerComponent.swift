import XCTest

// Component: the mode switch. A component owns a region.
// Selecting a segment returns the page for that mode.
//
// The segmented picker has accessibility identifier `modePicker` and
// accessibility label "Mode". Prefer the identifier. The "Mode" label is a fallback.
// The toolbar primary button is also titled "Split" or "Remux". Click a segment
// inside the picker, not `app.buttons["Remux"]`, or the test starts a batch.
//
// Each lookup is one element type. `descendants(matching: .any)` is not used.

/// Split | Remux segmented control in the toolbar.
@MainActor
struct ModePickerComponent {
    let app: XCUIApplication

    /// The mode control. Prefers identifier `modePicker`, then the "Mode" label.
    var element: XCUIElement {
        let candidates = pickerCandidates()
        return candidates.first { $0.exists } ?? candidates[0]
    }

    /// Clicks the segment titled `title` ("Split" or "Remux") inside the picker.
    @discardableResult
    func select(_ title: String, timeout: TimeInterval = UITestTimeout.standard) -> Self {
        let picker = resolvedPicker(timeout: timeout)
        let predicate = NSPredicate(format: "label == %@ OR title == %@ OR value == %@", title, title, title)
        let segments = [
            picker.buttons.matching(predicate).firstMatch,
            picker.radioButtons.matching(predicate).firstMatch,
            picker.checkBoxes.matching(predicate).firstMatch,
            picker.switches.matching(predicate).firstMatch,
            picker.segmentedControls.buttons.matching(predicate).firstMatch,
            picker.radioGroups.radioButtons.matching(predicate).firstMatch,
        ]
        guard let segment = UITestWait.firstExisting(segments, timeout: UITestTimeout.short) else {
            XCTFail("The \(title) segment in the Mode picker never showed up")
            return self
        }
        segment.click()
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

    private func pickerCandidates() -> [XCUIElement] {
        let types: [XCUIElement.ElementType] = [.segmentedControl, .radioGroup, .group, .popUpButton, .other]
        let identified = UITestQuery.identified("modePicker", in: app, types: types)
        let inToolbar = UITestQuery.identified("modePicker", in: app.toolbars.firstMatch, types: types)
        let labeled = UITestQuery.matching(
            NSPredicate(format: "label == %@", "Mode"),
            in: app,
            types: [.segmentedControl, .radioGroup, .group, .other]
        )
        return identified + [app.segmentedControls["Mode"], app.radioGroups["Mode"]] + inToolbar + labeled
    }

    private func resolvedPicker(timeout: TimeInterval) -> XCUIElement {
        let candidates = pickerCandidates()
        if let picker = UITestWait.firstExisting(candidates, timeout: timeout) {
            return picker
        }
        XCTFail("The Mode picker never showed up")
        return candidates[0]
    }
}
