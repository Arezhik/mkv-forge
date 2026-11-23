#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/scaffold-xcuitest.sh <FlowName>
# Example: ./scripts/scaffold-xcuitest.sh RemuxMatchFlow
#
# When App/MKVUITests/Tests and Base/BaseUITest.swift exist, this writes
# Tests/<Flow>UITests.swift as a BaseUITest subclass (no inline locators,
# no app.launch()). Otherwise it writes a root *UITests.swift that still
# launches with --uitesting only.

if [ $# -lt 1 ]; then
  echo "Usage: $0 <FlowName>"
  exit 1
fi

FLOW="$1"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "Error: not inside a git repository."
  exit 1
fi
cd "$ROOT"

if ! [[ "$FLOW" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Error: FlowName must be a Swift identifier (letters, digits, and underscore; not starting with a digit)."
  exit 1
fi

# Auto-detect UITests directory (e.g., App/UITests or *UITests).
# Skip .build, DerivedData, and .git so maxdepth 3 cannot pick build products.
UI_TEST_DIR=$(find . -maxdepth 3 \( -name .build -o -name DerivedData -o -name .git \) -prune -o -type d -name "*UITests" -print | head -n 1)

if [ -z "$UI_TEST_DIR" ]; then
  echo "Error: No *UITests directory found. Ensure a UI Test target exists in App/project.yml."
  exit 1
fi

# Playwright-style layout: thin tests live in Tests/ and subclass BaseUITest.
if [ -d "$UI_TEST_DIR/Tests" ] && [ -f "$UI_TEST_DIR/Base/BaseUITest.swift" ]; then
  TEST_FILE="$UI_TEST_DIR/Tests/${FLOW}UITests.swift"
  USE_POM=1
else
  TEST_FILE="$UI_TEST_DIR/${FLOW}UITests.swift"
  USE_POM=0
fi

if [ -e "$TEST_FILE" ]; then
  echo "Error: $TEST_FILE already exists."
  exit 1
fi

if [ "$USE_POM" -eq 1 ]; then
  cat > "$TEST_FILE" <<EOF
import XCTest

// Thin test. Launch, fixtures, and teardown live on BaseUITest.
// Do not override setUp, setUpWithError, or tearDown.
// Do not call app.launch() or construct XCUIApplication in this file.
// Do not add -ApplePersistenceIgnoreState YES: combined with --uitesting it suppresses the main Window.
//
// Pages and components own every locator. Do not query XCUIElement here.
// MainWindowPage, SplitPage, RemuxPage, SettingsPage,
// FolderFieldComponent, ModePickerComponent, QueueRowComponent.
// clickScanOrSkip() skips when Scan is disabled. This smoke does not click Scan.

@MainActor
final class ${FLOW}UITests: BaseUITest {
    override func prepareFixtures() async throws {
        // Seed files before launch. This window-and-folders smoke needs none.
    }

    func test${FLOW}CriticalPath() throws {
        let page = SplitPage(app: app)

        XCTContext.runActivity(named: "Main window appears") { _ in
            page.waitForSplitChrome()
        }

        XCTContext.runActivity(named: "Source folder shows the input fixture") { _ in
            page.sourceFolder.assertShowsPathFragment("input")
        }

        XCTContext.runActivity(named: "Output folder shows the output fixture") { _ in
            page.outputFolder.assertShowsPathFragment("output")
        }
    }
}
EOF
else
  cat > "$TEST_FILE" <<EOF
import XCTest

@MainActor
final class ${FLOW}UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Do not add -ApplePersistenceIgnoreState YES: it combines with --uitesting to suppress the main Window.
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Pareto Critical Path: Verify main window and key controls render and respond.
    func test${FLOW}CriticalPath() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "Main application window did not appear.")

        // TODO: Assert critical controls via accessibilityIdentifier (avoid brittle coordinates)
        // Do not query SwiftUI Text with containing() + "label CONTAINS" (matches descendants; macOS text is the value). Use matching() on label OR value.
        // Example:
        // let toggle = app.checkBoxes["matchOnMKANameToggle"]
        // XCTAssertTrue(toggle.waitForExistence(timeout: 2))
    }
}
EOF
fi

echo "Created XCUITest: $TEST_FILE"

# New UI test files belong to the Xcode app project, so they need a
# project regen. On this Linux VM (no Swift), use the churn-free
# verify-linux.sh path instead of a raw `xcodegen generate`.
if [ -f "App/project.yml" ]; then
  if ! command -v swift >/dev/null 2>&1 && [ -x "./scripts/verify-linux.sh" ]; then
    ./scripts/verify-linux.sh
  else
    echo "Swift is on PATH; regenerate the Xcode project with your usual XcodeGen path."
  fi
fi
