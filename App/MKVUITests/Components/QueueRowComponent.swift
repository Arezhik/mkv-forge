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

    /// The row's checkbox. Accessibility label is `Include <stem>`.
    /// Flagged rows use the same label and stay disabled.
    func clickIncludeCheckbox(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let checkbox = includeCheckbox(timeout: timeout) else {
            XCTFail(
                "The Include \(stem) checkbox never showed up. \(queueRowSummary())",
                file: file,
                line: line
            )
            return
        }
        checkbox.click()
    }

    func assertIncludeCheckbox(
        enabled: Bool,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var observed = "missing"
        while Date() < deadline {
            if let checkbox = includeCheckbox(timeout: 0.2) {
                observed = "enabled=\(checkbox.isEnabled) \(describe(checkbox))"
                if checkbox.isEnabled == enabled {
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "Include \(stem) was \(observed), expected enabled \(enabled)",
            file: file,
            line: line
        )
    }

    /// Opens `Choose match for <stem>` and picks `candidateFileName`.
    /// `stem` is the file name on the button, such as `X.mka`.
    /// The menu section is `Pair <stem> with`. A miss fails with the menu items
    /// that were actually visible.
    func chooseMatch(
        _ candidateFileName: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let buttonLabel = "Choose match for \(stem)"
        let sectionTitle = "Pair \(stem) with"
        guard let button = UITestWait.firstExisting([
            app.menuButtons.matching(named(buttonLabel)).firstMatch,
            app.popUpButtons.matching(named(buttonLabel)).firstMatch,
            app.buttons.matching(named(buttonLabel)).firstMatch,
            app.descendants(matching: .any).matching(named(buttonLabel)).firstMatch,
        ], timeout: timeout) else {
            XCTFail(
                "\(buttonLabel) never showed up. \(queueRowSummary())",
                file: file,
                line: line
            )
            return
        }
        button.click()

        let item = app.menuItems.matching(named(candidateFileName)).firstMatch
        let nested = app.menus.menuItems.matching(named(candidateFileName)).firstMatch
        let inButtonMenu = button.menus.menuItems.matching(named(candidateFileName)).firstMatch
        let inButton = button.menuItems.matching(named(candidateFileName)).firstMatch
        let deadline = Date().addingTimeInterval(UITestTimeout.standard)
        while Date() < deadline {
            if let pick = firstHit([item, nested, inButtonMenu, inButton]) {
                pick.click()
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let sectionVisible = app.descendants(matching: .any)
            .matchingLabelOrValue(equalTo: sectionTitle)
            .firstMatch
            .exists
        XCTFail(
            "Choose Match did not list \(candidateFileName). Section '\(sectionTitle)' visible=\(sectionVisible). Menu items: \(visibleMenuItems())",
            file: file,
            line: line
        )
    }

    /// Clicks `Unmatch <stem> from <audioFileName>`. `stem` is the video base name,
    /// such as `X Extended`. The button title on screen is `Unmatch`.
    func clickUnmatch(
        audioFileName: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let label = "Unmatch \(stem) from \(audioFileName)"
        guard let button = UITestWait.firstExisting([
            app.buttons.matching(named(label)).firstMatch,
            app.descendants(matching: .any).matching(named(label)).firstMatch,
        ], timeout: timeout) else {
            XCTFail("\(label) never showed up. \(queueRowSummary())", file: file, line: line)
            return
        }
        button.click()
    }

    /// Waits until no queue row still shows `expected`. The pick that removes a row
    /// lands on the next main-actor turn.
    func assertExactLabelAbsent(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identified = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND (label == %@ OR value == %@)", "queueRow", expected, expected)
        ).firstMatch
        let fallback = app.descendants(matching: .any).matchingLabelOrValue(equalTo: expected).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !identified.exists, !fallback.exists {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail(
            "The queue row \(expected) was still on screen. \(queueRowSummary())",
            file: file,
            line: line
        )
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

    private func named(_ name: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR value == %@ OR title == %@", name, name, name)
    }

    /// `Include <stem>`. Checkboxes first, then switches, then any element with that label.
    private func includeCheckbox(timeout: TimeInterval) -> XCUIElement? {
        let name = "Include \(stem)"
        return UITestWait.firstExisting([
            app.checkBoxes.matchingLabelOrValue(equalTo: name).firstMatch,
            app.switches.matchingLabelOrValue(equalTo: name).firstMatch,
            app.descendants(matching: .any).matchingLabelOrValue(equalTo: name).firstMatch,
        ], timeout: timeout)
    }

    private func firstHit(_ elements: [XCUIElement]) -> XCUIElement? {
        elements.first { $0.exists }
    }

    private func visibleMenuItems() -> String {
        let items = app.menuItems.allElementsBoundByIndex.prefix(12).map { element -> String in
            let value = element.value.map { "\($0)" } ?? ""
            return "label='\(element.label)' title='\(element.title)' value='\(value)'"
        }
        if items.isEmpty {
            return "(none)"
        }
        return items.joined(separator: "; ")
    }
}
