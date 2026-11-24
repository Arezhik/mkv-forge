import XCTest

// Component: the bottom bar. Summary, batch progress, and Show in Finder.
// The row context menu also has Show in Finder. This component reads the
// button in the main window, which is the bar button after a finish.
// Do not click Show in Finder. It opens Finder (issue #31).

/// Leading summary, trailing progress, and the finished-run Show in Finder button.
@MainActor
struct BottomBarComponent {
    let app: XCUIApplication

    private var window: XCUIElement {
        app.windows["MKVForge"]
    }

    /// Accessibility label of `bottomSummary` is the plain string, such as `Finished · 1 done`.
    /// The query stays on that identifier. A window-wide exact match would also hit a
    /// notification body with the same words.
    func assertSummary(
        _ expected: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let summary = window.descendants(matching: .any)["bottomSummary"]
        summary.requireExists(
            timeout: timeout,
            message: "The bottom-bar summary never showed up",
            file: file,
            line: line
        )
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
    func assertProgress(
        value expectedValue: String,
        caption expectedCaption: String,
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let progress = window.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Batch progress")
        ).firstMatch
        progress.requireExists(
            timeout: timeout,
            message: "Batch progress never showed up",
            file: file,
            line: line
        )
        let deadline = Date().addingTimeInterval(timeout)
        var observed = Self.stringValue(progress)
        while Date() < deadline {
            observed = Self.stringValue(progress)
            if observed == expectedValue {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(observed, expectedValue, "Batch progress value", file: file, line: line)

        let caption = window.descendants(matching: .any)["batchProgressCaption"]
        caption.requireExists(
            timeout: timeout,
            message: "The progress caption never showed up",
            file: file,
            line: line
        )
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

    /// The bottom-bar Show in Finder button (`showInFinder`). Does not click it.
    /// Folder fields and Done rows use the same title on a context menu. Those
    /// menus do not have this identifier.
    func assertShowInFinderVisible(
        timeout: TimeInterval = UITestTimeout.long,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = window.descendants(matching: .any)["showInFinder"]
        button.requireExists(
            timeout: timeout,
            message: "Show in Finder never showed up in the bottom bar",
            file: file,
            line: line
        )
        let named = button.label == "Show in Finder"
            || button.title == "Show in Finder"
            || button.descendants(matching: .any).matchingLabelOrValue(equalTo: "Show in Finder").firstMatch.exists
        XCTAssertTrue(
            named,
            "showInFinder was label='\(button.label)' title='\(button.title)'",
            file: file,
            line: line
        )
    }

    /// `label` or `value` equals `expected`, or a child of this element does.
    /// Children outside this element do not count.
    private static func showsExact(_ element: XCUIElement, _ expected: String) -> Bool {
        if element.label == expected {
            return true
        }
        if let text = element.value as? String, text == expected {
            return true
        }
        return element.descendants(matching: .any).matchingLabelOrValue(equalTo: expected).firstMatch.exists
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

    private static func stringValue(_ element: XCUIElement) -> String {
        if let text = element.value as? String {
            return text
        }
        if let value = element.value {
            return "\(value)"
        }
        return ""
    }
}
