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
        XCTFail(
            "The queue row for \(stem) never showed up. Observed: \(observedQueueTexts()). \(queueRowSummary())",
            file: file,
            line: line
        )
        return stemElement
    }

    /// Exact VoiceOver string, for example
    /// `"<stem>, Ready"` or `"<stem>, Issue, No matching .mka in Audio folder"`.
    ///
    /// Primary match is the query that passed for Remux #33:
    /// `identifier == "queueRow" AND label == expected`.
    /// `value == expected` stays as a broader OR for SwiftUI `Text`, whose
    /// visible string is often `value` while `label` is empty. Do not drop
    /// the identifier + label equality.
    /// The Name-cell fallback uses `matchingLabelOrValue(equalTo:)`.
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
            XCTFail(
                "The queue row \(expected) never showed up. Observed: \(observedQueueTexts()). \(queueRowSummary())",
                file: file,
                line: line
            )
            return fallback
        }
        return row
    }

    /// Labels and values from the queue outline, for a failed row assertion (L35).
    private func observedQueueTexts() -> String {
        let outline = app.outlines.firstMatch
        guard outline.exists else {
            return "no outline; " + summarizedStaticTexts(app.staticTexts)
        }
        let rows = outline.descendants(matching: .outlineRow).allElementsBoundByIndex
        guard !rows.isEmpty else {
            return "outline with 0 rows; " + summarizedStaticTexts(outline.descendants(matching: .staticText))
        }
        let described = rows.prefix(6).map { row -> String in
            let texts = row.descendants(matching: .staticText).allElementsBoundByIndex.map { describe($0) }
            return "row(\(describe(row)) texts=[\(texts.joined(separator: "; "))])"
        }
        return described.joined(separator: " | ")
    }

    /// `queueRow` labels, plus each row's label and value. The label list is the
    /// same report the Remux #33 test printed on failure.
    private func queueRowSummary() -> String {
        let rows = app.descendants(matching: .any)
            .matching(identifier: "queueRow")
            .allElementsBoundByIndex
        let labels = rows.map(\.label)
        let described = rows.map { describe($0) }
        return "queueRow labels: \(labels). queueRow texts: [\(described.joined(separator: "; "))]"
    }

    private func summarizedStaticTexts(_ query: XCUIElementQuery) -> String {
        let texts = query.allElementsBoundByIndex.prefix(12).map { describe($0) }
        return "staticTexts=[\(texts.joined(separator: "; "))]"
    }

    private func describe(_ element: XCUIElement) -> String {
        let value = element.value.map { "\($0)" } ?? ""
        return "label='\(element.label)' value='\(value)'"
    }
}
