import XCTest

// Component: the bottom bar. Summary, batch progress, Show Ready, and Show in Finder.
// The row context menu also has Show in Finder. This component reads the
// button identified `showInFinder`, which is the bar button after a finish.
// Do not click Show in Finder. It opens Finder (issue #31).
//
// Show Ready is identifier `showReadyToggle`, label `Show Ready`. It is a
// bordered toggle, so XCTest may see a button, a checkbox, or a switch.
// Queries are one element type on `app`. `app.windows["MKVForge"]` does not
// match the SwiftUI main window, and `descendants(matching: .any)` times out.

/// Leading summary, trailing progress, and the finished-run Show in Finder button.
@MainActor
struct BottomBarComponent {
    let app: XCUIApplication

    /// Accessibility label of `bottomSummary` is the plain string, such as `Finished · 1 done`.
    /// The query stays on that identifier. A text-wide exact match would also hit a
    /// notification body with the same words.
    func assertSummary(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let summary = UITestWait.firstExisting(summaryCandidates(), timeout: timeout) else {
            XCTFail("The bottom-bar summary never showed up", file: file, line: line)
            return
        }
        let deadline = Date().addingTimeInterval(timeout)
        var observed = Self.exposedText(summary)
        while Date() < deadline {
            observed = Self.exposedText(summary)
            if Self.showsExact(summary, expected) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "Bottom-bar summary was '\(observed)', expected '\(expected)'",
            file: file,
            line: line
        )
    }

    /// Label `Batch progress`, value such as `1 of 1 complete`.
    /// The caption (`1 .mka saved`) is identifier `batchProgressCaption`.
    /// The caption must equal `expectedCaption`. `contains` would let `11 .mka saved`
    /// pass a check for `1 .mka saved`.
    ///
    /// The sentence is identifier `batchProgress` (a text behind the bar).
    /// An NSProgressIndicator with the same label exposes `value` as `""`, so a
    /// candidate counts only when its value, label, or static-text child equals
    /// `expectedValue`.
    func assertProgress(
        value expectedValue: String,
        caption expectedCaption: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var observed = ""
        var sawCandidate = false
        while Date() < deadline {
            let present = progressCandidates(expectedValue: expectedValue).filter(\.exists)
            if !present.isEmpty {
                sawCandidate = true
            }
            if present.contains(where: { Self.exposedProgress($0, expected: expectedValue) == expectedValue }) {
                observed = expectedValue
                break
            }
            observed = ""
            for element in present {
                let text = Self.exposedProgress(element, expected: expectedValue)
                if !text.isEmpty {
                    observed = text
                    break
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if !sawCandidate {
            XCTFail("Batch progress never showed up", file: file, line: line)
            return
        }
        XCTAssertEqual(observed, expectedValue, "Batch progress value", file: file, line: line)

        guard let caption = UITestWait.firstExisting(captionCandidates(), timeout: timeout) else {
            XCTFail("The progress caption never showed up", file: file, line: line)
            return
        }
        let captionDeadline = Date().addingTimeInterval(timeout)
        var captionText = ""
        while Date() < captionDeadline {
            captionText = caption.uiText
            if captionText == expectedCaption {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "The progress caption was '\(captionText)', expected '\(expectedCaption)'.",
            file: file,
            line: line
        )
    }

    /// Turns the bottom-bar Show Ready toggle on or off.
    /// Identifier `showReadyToggle`. The accessible name is `Show Ready`.
    /// One click when the control does not already match `on`.
    func setShowReady(
        _ on: Bool,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let toggle = UITestWait.firstExisting(showReadyCandidates(), timeout: timeout) else {
            XCTFail("Show Ready never showed up in the bottom bar", file: file, line: line)
            return
        }
        let named = toggle.label == "Show Ready"
            || toggle.title == "Show Ready"
            || toggle.staticTexts.matchingLabelOrValue(equalTo: "Show Ready").firstMatch.exists
        XCTAssertTrue(
            named,
            "showReadyToggle was label='\(toggle.label)' title='\(toggle.title)'",
            file: file,
            line: line
        )
        // A bordered toggle sometimes exposes only its title. After one click
        // fails to move `value`, later calls click again instead of trusting it.
        let current = Self.valueIsUnreliable ? nil : Self.isOn(toggle)
        if current == on {
            return
        }
        toggle.click()
        if current == nil {
            return
        }
        let deadline = Date().addingTimeInterval(min(timeout, 1))
        while Date() < deadline {
            let now = Self.isOn(toggle)
            if now == on || now == nil {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        Self.valueIsUnreliable = true
    }

    /// The bottom-bar Show in Finder button (`showInFinder`). Does not click it.
    /// Folder fields and Done rows use the same title on a context menu. Those
    /// menus do not have this identifier.
    func assertShowInFinderVisible(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identified = app.buttons.matching(NSPredicate(format: "identifier == %@", "showInFinder")).firstMatch
        guard let button = UITestWait.firstExisting([identified], timeout: timeout) else {
            XCTFail("Show in Finder never showed up in the bottom bar", file: file, line: line)
            return
        }
        let named = button.label == "Show in Finder"
            || button.title == "Show in Finder"
            || button.staticTexts.matchingLabelOrValue(equalTo: "Show in Finder").firstMatch.exists
        XCTAssertTrue(
            named,
            "showInFinder was label='\(button.label)' title='\(button.title)'",
            file: file,
            line: line
        )
    }

    /// `showReadyToggle` on a button, checkbox, or switch. Identifier only.
    /// `value CONTAINS` is not used: a switch value is `0` or `1`.
    private func showReadyCandidates() -> [XCUIElement] {
        let predicate = NSPredicate(format: "identifier == %@", "showReadyToggle")
        return [
            app.buttons.matching(predicate).firstMatch,
            app.checkBoxes.matching(predicate).firstMatch,
            app.switches.matching(predicate).firstMatch,
        ]
    }

    /// Set when a click does not change the exposed value. See `setShowReady`.
    private static var valueIsUnreliable = false

    /// `1` / `on` is on, `0` / `off` is off. A title-only button returns nil.
    private static func isOn(_ element: XCUIElement) -> Bool? {
        if let text = element.value as? String {
            switch text.lowercased() {
            case "1", "on": return true
            case "0", "off": return false
            default: break
            }
        }
        if let number = element.value as? NSNumber {
            return number.intValue != 0
        }
        return nil
    }

    private func summaryCandidates() -> [XCUIElement] {
        UITestQuery.identified("bottomSummary", in: app, types: [.staticText, .group, .other])
    }

    /// Static text first. The progress indicator's label can match while its
    /// value stays empty, so it is not the only candidate.
    private func progressCandidates(expectedValue: String) -> [XCUIElement] {
        let predicate = NSPredicate(
            format: "identifier == %@ OR label == %@ OR value == %@",
            "batchProgress", "Batch progress", expectedValue
        )
        return UITestQuery.matching(
            predicate,
            in: app,
            types: [.staticText, .group, .other, .progressIndicator]
        )
    }

    private func captionCandidates() -> [XCUIElement] {
        UITestQuery.identified("batchProgressCaption", in: app, types: [.staticText, .group, .other])
    }

    /// `label` or `value` equals `expected`, or a static-text child of this element does.
    /// Children outside this element do not count.
    private static func showsExact(_ element: XCUIElement, _ expected: String) -> Bool {
        if element.label == expected {
            return true
        }
        if let text = element.value as? String, text == expected {
            return true
        }
        return element.staticTexts.matchingLabelOrValue(equalTo: expected).firstMatch.exists
    }

    private static func exposedText(_ element: XCUIElement) -> String {
        if !element.label.isEmpty {
            return element.label
        }
        if let text = element.value as? String {
            return text
        }
        return ""
    }

    /// The progress sentence. An empty indicator value is not that sentence.
    /// A static-text child of this element counts. Other elements do not.
    private static func exposedProgress(_ element: XCUIElement, expected: String) -> String {
        if let text = element.value as? String, text == expected {
            return text
        }
        if element.label == expected {
            return element.label
        }
        if element.staticTexts.matchingLabelOrValue(equalTo: expected).firstMatch.exists {
            return expected
        }
        if let text = element.value as? String, !text.isEmpty {
            return text
        }
        return ""
    }
}
