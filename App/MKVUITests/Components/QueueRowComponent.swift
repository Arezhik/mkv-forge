import XCTest

// Component: one queue row. A component owns a region.
//
// On main the Name cell is a SwiftUI Text. Its visible string is `value`
// (often `"<stem>, Ready"` or `"<stem>, Issue, <reason>"`) and `label` is often empty.
// Match with `matching` (`label CONTAINS` OR `value CONTAINS`), never `containing`.
//
// Identifier `queueRow` arrives with PR #36. The row's VoiceOver label is then
// `"<stem>, Ready"` or `"<stem>, Issue, <reason>"`. `identifiedElement` references that id.

/// One queue row, found by its file stem (the base name, such as `"sample"`).
@MainActor
struct QueueRowComponent {
    let app: XCUIApplication
    let stem: String

    /// PR #36 row whose label or value contains the stem. Absent on current main.
    var identifiedElement: XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
                "queueRow", stem, stem
            )
        ).firstMatch
    }

    /// Name cell on current main. `matching`, not `containing`.
    var stemElement: XCUIElement {
        app.descendants(matching: .any).matchingLabelOrValue(containing: stem).firstMatch
    }

    /// The row to read. Prefers `queueRow` when that element is already on screen.
    var element: XCUIElement {
        identifiedElement.exists ? identifiedElement : stemElement
    }

    @discardableResult
    func requireExists(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        if let row = UITestWait.firstExisting([identifiedElement, stemElement], timeout: timeout) {
            return row
        }
        XCTFail("The queue row for \(stem) never showed up", file: file, line: line)
        return stemElement
    }

    /// Exact VoiceOver string used after PR #36, for example
    /// `"<stem>, Ready"` or `"<stem>, Issue, No matching .mka in Audio folder"`.
    /// Also matches a main-branch Name cell whose `value` is that whole string.
    @discardableResult
    func requireExactLabel(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let identified = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND (label == %@ OR value == %@)", "queueRow", expected, expected)
        ).firstMatch
        let fallback = app.descendants(matching: .any).matchingLabelOrValue(equalTo: expected).firstMatch
        guard let row = UITestWait.firstExisting([identified, fallback], timeout: timeout) else {
            XCTFail("The queue row \(expected) never showed up", file: file, line: line)
            return fallback
        }
        return row
    }
}
