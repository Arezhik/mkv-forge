import XCTest

// Helpers: waits and the macOS SwiftUI text query shared by pages and components.

/// Timeouts for `waitForExistence`. Window and controls use `standard`.
/// A queue row after Scan uses `long`.
enum UITestTimeout {
    static let short: TimeInterval = 2
    static let standard: TimeInterval = 5
    static let long: TimeInterval = 10
    /// One 1-second mkvmerge job, including process startup.
    static let batch: TimeInterval = 60
}

enum UITestWait {
    /// Returns the first element that exists, polling until `timeout`.
    /// Use this when several locators can match the same control (an identifier
    /// that arrives in a later PR, then a label fallback).
    @MainActor
    static func firstExisting(_ elements: [XCUIElement], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            for element in elements where element.exists {
                return element
            }
            if Date() >= deadline {
                return nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}

@MainActor
extension XCUIElementQuery {
    /// Elements whose own `label` or `value` contains `text`.
    ///
    /// SwiftUI `Text` on macOS exposes its string as `value`. `label` is often empty.
    /// `containing` searches descendants, so a `StaticText` never matches
    /// `label CONTAINS`. Use `matching` with both keys.
    func matchingLabelOrValue(containing text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
    }

    /// Elements whose own `label` or `value` equals `text`.
    func matchingLabelOrValue(equalTo text: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "label == %@ OR value == %@", text, text))
    }
}

@MainActor
extension XCUIElement {
    /// Visible string. Folder fields set `accessibilityLabel` (`label`).
    /// SwiftUI `Text` usually puts the string in `value` and leaves `label` empty.
    var uiText: String {
        if !label.isEmpty {
            return label
        }
        if let text = value as? String {
            return text
        }
        return ""
    }

    @discardableResult
    func requireExists(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(waitForExistence(timeout: timeout), message, file: file, line: line)
        return self
    }

    func clickWhenReady(
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExists(timeout: timeout, message: message, file: file, line: line)
        click()
    }

    /// Switch and checkbox values. macOS reports `1`/`0` or `on`/`off`.
    var switchIsOn: Bool? {
        let raw = (value.map { "\($0)" } ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "1", "on", "true":
            return true
        case "0", "off", "false":
            return false
        default:
            return nil
        }
    }

    /// The Settings bindings write on the next main-actor turn, so poll the value.
    func waitUntilSwitch(
        isOn expected: Bool,
        timeout: TimeInterval = UITestTimeout.standard,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if switchIsOn == expected {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("\(message) Value was \(value.map { "\($0)" } ?? "nil").", file: file, line: line)
    }
}
