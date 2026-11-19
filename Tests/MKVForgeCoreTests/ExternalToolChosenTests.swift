import XCTest
@testable import MKVForgeCore

final class ExternalToolChosenTests: XCTestCase {
    private let spec = ExternalToolSpec(name: "Demo", executables: ["demo", "demo-extract"], appBundlePrefix: "Demo")

    func testChosenExecutableFindsItsSiblings() {
        let existing: Set<String> = ["/opt/tools/demo", "/opt/tools/demo-extract", "/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract"]
        let paths = ExternalTool.locate(spec, chosen: "/opt/tools/demo", executableExists: { existing.contains($0) })
        XCTAssertEqual(paths?["demo"], "/opt/tools/demo")
        XCTAssertEqual(paths?["demo-extract"], "/opt/tools/demo-extract")
    }

    func testChosenAppBundle() {
        let existing: Set<String> = ["/Volumes/X/Demo-103.app/Contents/MacOS/demo", "/Volumes/X/Demo-103.app/Contents/MacOS/demo-extract"]
        let paths = ExternalTool.locate(spec, chosen: "/Volumes/X/Demo-103.app/", executableExists: { existing.contains($0) })
        XCTAssertEqual(paths?["demo"], "/Volumes/X/Demo-103.app/Contents/MacOS/demo")
    }

    func testChosenFolder() {
        let existing: Set<String> = ["/opt/local/bin/demo", "/opt/local/bin/demo-extract"]
        XCTAssertEqual(ExternalTool.locate(spec, chosen: "/opt/local/bin", executableExists: { existing.contains($0) })?["demo"], "/opt/local/bin/demo")
    }

    func testMissingChosenCopyIsNotFoundWithoutFallback() {
        // Homebrew has it, but the user chose another copy that's gone (AGENTS.md, L15).
        let existing: Set<String> = ["/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract"]
        XCTAssertNil(ExternalTool.locate(spec, chosen: "/Volumes/Gone/Demo.app", executableExists: { existing.contains($0) }))
    }

    func testNoChoiceUsesTheDefaultSearch() {
        XCTAssertEqual(ExternalTool.locate(.primary, chosen: nil), ExternalTool.locate(.primary))
        XCTAssertEqual(ExternalTool.locate(.primary, chosen: ""), ExternalTool.locate(.primary))
    }
}
