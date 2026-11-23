import XCTest

// Component: one queue row. A component owns a region.
//
// The Name cell is a SwiftUI Text. Its visible string is often `value`
// (`"<stem>, Ready"` or `"<stem>, Issue, <reason>"`) and `label` is often empty.
// Match with `matching` (`label CONTAINS` OR `value CONTAINS`), never `containing`.
//
// Identifier `queueRow` is on the row. Its VoiceOver label is
// `"<stem>, Ready"` or `"<stem>, Issue, <reason>"`. Prefer that id.
// Label-or-value matching stays as a fallback.

/// One queue row, found by its file stem (the base name, such as `"sample"`).
@MainActor
struct QueueRowComponent {
    let app: XCUIApplication
    let stem: String

    /// `queueRow` whose label or value contains the stem.
    var identifiedElement: XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
                "queueRow", stem, stem
            )
        ).firstMatch
    }

    /// Name-cell fallback. `matching`, not `containing`.
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

    /// Exact VoiceOver string, for example
    /// `"<stem>, Ready"` or `"<stem>, Issue, No matching .mka in Audio folder"`.
    /// Prefers `queueRow`. Also matches a Name cell whose `value` is that whole string.
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
