import XCTest

// Component: one folder field. A component owns a region.
// Methods return a page or component when that helps the next step.

/// Identifiers on main, from `\(role.rawValue)Folder` in `ContentView.FolderField`.
enum FolderFieldIdentifier: String {
    case source = "sourceFolder"
    case output = "outputFolder"
    case video = "videoFolder"
    case audio = "audioFolder"

    /// The role word in the accessibility label ("Source folder, …").
    var roleName: String {
        switch self {
        case .source: return "Source"
        case .output: return "Output"
        case .video: return "Video"
        case .audio: return "Audio"
        }
    }
}

/// The chosen-folder row for one role.
///
/// The field sets `accessibilityIdentifier` and `accessibilityLabel`
/// (`"Source folder, <name>, <path>"`). `label` holds that string.
/// Split shows Source and Output. Remux shows Video, Audio, and Output.
@MainActor
struct FolderFieldComponent {
    let app: XCUIApplication
    let identifier: FolderFieldIdentifier

    init(app: XCUIApplication, identifier: FolderFieldIdentifier) {
        self.app = app
        self.identifier = identifier
    }

    init(app: XCUIApplication, role: FolderFieldIdentifier) {
        self.init(app: app, identifier: role)
    }

    var element: XCUIElement {
        app.descendants(matching: .any)[identifier.rawValue]
    }

    @discardableResult
    func requireExists(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        element.requireExists(
            timeout: timeout,
            message: "The \(identifier.roleName) folder field (\(identifier.rawValue)) never showed up",
            file: file,
            line: line
        )
    }

    /// Asserts the field shows a seeded path fragment such as `"input"` or `"output"`.
    /// The fixture folder's last path component is that fragment, and the accessibility
    /// label includes it (`FolderDisplay.accessibilityLabel`).
    func assertShowsPathFragment(
        _ fragment: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let field = requireExists(timeout: timeout, file: file, line: line)
        XCTAssertTrue(
            field.uiText.contains(fragment),
            "The \(identifier.roleName) folder did not show \(fragment): \(field.uiText)",
            file: file,
            line: line
        )
    }
}
