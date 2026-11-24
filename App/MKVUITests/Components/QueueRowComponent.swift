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
//
// Lookups use groups, cells, static texts, other elements, and outline rows.
// `descendants(matching: .any)` snapshots the whole tree and times out on macOS.

/// One queue row, found by its file stem (the base name, such as `"sample"`).
@MainActor
struct QueueRowComponent {
    /// Element types that can carry `queueRow` or the name-cell string.
    static let elementTypes: [XCUIElement.ElementType] = [
        .group, .cell, .staticText, .other, .outlineRow,
    ]

    let app: XCUIApplication
    let stem: String

    /// `queueRow` whose label or value contains the stem.
    var identifiedElement: XCUIElement {
        rows(matching: NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "queueRow", stem, stem
        )).first { $0.exists } ?? rows(matching: NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "queueRow", stem, stem
        ))[0]
    }

    /// Name-cell fallback. `matching`, not `containing`.
    var stemElement: XCUIElement {
        let candidates = textRows(containing: stem)
        return candidates.first { $0.exists } ?? candidates[0]
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
        let identified = rows(matching: NSPredicate(
            format: "identifier == %@ AND (label CONTAINS %@ OR value CONTAINS %@)",
            "queueRow", stem, stem
        ))
        if let row = UITestWait.firstExisting(identified + textRows(containing: stem), timeout: timeout) {
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
        let identified = rows(matching: NSPredicate(
            format: "identifier == %@ AND (label == %@ OR value == %@)",
            "queueRow", expected, expected
        ))
        let fallback = textRows(equalTo: expected)
        guard let row = UITestWait.firstExisting(identified + fallback, timeout: timeout) else {
            XCTFail(
                "The queue row \(expected) never showed up. Observed: \(observedQueueTexts()). \(queueRowSummary())",
                file: file,
                line: line
            )
            return fallback[0]
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
            app.groups.matching(named(buttonLabel)).firstMatch,
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
        let sectionPredicate = NSPredicate(format: "label == %@ OR value == %@", sectionTitle, sectionTitle)
        let sectionVisible = UITestQuery.matching(
            sectionPredicate,
            in: app,
            types: [.staticText, .menuItem]
        ).contains { $0.exists }
        XCTFail(
            "Choose Match did not list \(candidateFileName). Section '\(sectionTitle)' visible=\(sectionVisible). Menu items: \(visibleMenuItems())",
            file: file,
            line: line
        )
    }

    /// Clicks `Unmatch <stem> from <audioFileName>`. `stem` is the video base name,
    /// such as `X Extended`. The on-screen title is `Unmatch`.
    ///
    /// Link-style buttons are `links`, not `buttons`. The accessible name is the
    /// full label, so a control titled only `Unmatch` does not match.
    func clickUnmatch(
        audioFileName: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let label = "Unmatch \(stem) from \(audioFileName)"
        guard let button = UITestWait.firstExisting(unmatchCandidates(label: label), timeout: timeout) else {
            XCTFail(
                "\(label) never showed up. \(queueRowSummary()) Unmatch controls: \(unmatchSummary())",
                file: file,
                line: line
            )
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
        let identified = rows(matching: NSPredicate(
            format: "identifier == %@ AND (label == %@ OR value == %@)",
            "queueRow", expected, expected
        ))
        let fallback = textRows(equalTo: expected)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !identified.contains(where: \.exists), !fallback.contains(where: \.exists) {
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
        let rows = UITestQuery.all(
            matching: NSPredicate(format: "identifier == %@", "queueRow"),
            in: app,
            types: Self.elementTypes
        )
        let labels = rows.map(\.label)
        let described = rows.map { describe($0) }
        return "queueRow labels: \(labels). queueRow texts: [\(described.joined(separator: "; "))]"
    }

    private func rows(matching predicate: NSPredicate) -> [XCUIElement] {
        UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    private func textRows(containing text: String) -> [XCUIElement] {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        return UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    private func textRows(equalTo text: String) -> [XCUIElement] {
        let predicate = NSPredicate(format: "label == %@ OR value == %@", text, text)
        return UITestQuery.matching(predicate, in: app, types: Self.elementTypes)
    }

    private func summarizedStaticTexts(_ query: XCUIElementQuery) -> String {
        let texts = query.allElementsBoundByIndex.prefix(12).map { describe($0) }
        return "staticTexts=[\(texts.joined(separator: "; "))]"
    }

    private func describe(_ element: XCUIElement) -> String {
        let value = element.value.map { "\($0)" } ?? ""
        return "label='\(element.label)' value='\(value)'"
    }

    /// Exact accessible name. Identifier alone is not enough: every Unmatch
    /// button shares `unmatchButton`, and the label names the pair.
    private func unmatchCandidates(label: String) -> [XCUIElement] {
        let exact = NSPredicate(
            format: "label == %@ OR value == %@ OR title == %@",
            label, label, label
        )
        return UITestQuery.matching(exact, in: app, types: [.button, .link, .menuButton, .group])
    }

    private func unmatchSummary() -> String {
        let predicate = NSPredicate(
            format: "identifier == %@ OR label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@",
            "unmatchButton", "Unmatch", "Unmatch", "Unmatch"
        )
        let hits = UITestQuery.all(
            matching: predicate,
            in: app,
            types: [.button, .link, .menuButton, .group]
        )
        if hits.isEmpty {
            return "(none)"
        }
        return hits.prefix(6).map { describe($0) }.joined(separator: "; ")
    }

    private func named(_ name: String) -> NSPredicate {
        NSPredicate(format: "label == %@ OR value == %@ OR title == %@", name, name, name)
    }

    /// `Include <stem>`. Checkboxes first, then switches.
    private func includeCheckbox(timeout: TimeInterval) -> XCUIElement? {
        let name = "Include \(stem)"
        return UITestWait.firstExisting([
            app.checkBoxes.matchingLabelOrValue(equalTo: name).firstMatch,
            app.switches.matchingLabelOrValue(equalTo: name).firstMatch,
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
