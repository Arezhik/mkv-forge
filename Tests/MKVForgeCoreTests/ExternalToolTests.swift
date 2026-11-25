import XCTest
@testable import MKVForgeCore

final class ExternalToolTests: XCTestCase {
    private let spec = ExternalToolSpec(name: "Demo", executables: ["demo", "demo-extract"], appBundlePrefix: "Demo")

    func testHomebrewBeatsAppBundleAndPath() {
        let existing: Set<String> = [
            "/opt/homebrew/bin/demo", "/opt/homebrew/bin/demo-extract",
            "/Applications/Demo.app/Contents/MacOS/demo", "/usr/bin/demo"
        ]
        let paths = ExternalTool.locate(spec, executableExists: { existing.contains($0) }, applications: ["Demo.app"], searchPath: "/usr/bin")
        XCTAssertEqual(paths?["demo"], "/opt/homebrew/bin/demo")
        XCTAssertEqual(paths?["demo-extract"], "/opt/homebrew/bin/demo-extract")
    }

    func testIntelHomebrewThenAppBundleThenPath() {
        let existing: Set<String> = ["/usr/local/bin/demo", "/Applications/Demo 2.app/Contents/MacOS/demo-extract"]
        let paths = ExternalTool.locate(spec, executableExists: { existing.contains($0) }, applications: ["Demo 2.app", "Other.app"], searchPath: "")
        XCTAssertEqual(paths?["demo"], "/usr/local/bin/demo")
        XCTAssertEqual(paths?["demo-extract"], "/Applications/Demo 2.app/Contents/MacOS/demo-extract")
    }

    func testPartialInstallCountsAsMissing() {
        let existing: Set<String> = ["/usr/bin/demo"]
        XCTAssertNil(ExternalTool.locate(spec, executableExists: { existing.contains($0) }, applications: [], searchPath: "/usr/bin"))
    }

    func testStderrIsFlattenedAndCut() {
        let long = String(repeating: "x", count: 2500)
        XCTAssertEqual(ToolCommandFormatting.stderrText(Data("a\nb\n".utf8)), "a b")
        XCTAssertEqual(ToolCommandFormatting.stderrText(Data(long.utf8))?.count, 2001)
        XCTAssertNil(ToolCommandFormatting.stderrText(Data()))
    }

    #if !os(Windows)
    func testRunReportsExitCodeAndCancels() async throws {
        let result = try await ToolCommand.run(executable: "/bin/sh", arguments: ["-c", "echo out; echo err >&2; exit 3"])
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(String(decoding: result.standardOutput, as: UTF8.self), "out\n")

        let box = LineBox()
        let split = try await ToolCommand.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf '#GUI#progress 10%%\\r#GUI#progress 20%%\\n'; printf 'tail\\n'; printf 'err-not-stdout\\n' >&2"]
        ) { line in
            box.add(line)
        }
        XCTAssertEqual(box.lines, ["#GUI#progress 10%", "#GUI#progress 20%", "tail"])
        XCTAssertEqual(String(decoding: split.standardOutput, as: UTF8.self), "#GUI#progress 10%\r#GUI#progress 20%\ntail\n")
        XCTAssertFalse(String(decoding: split.standardOutput, as: UTF8.self).contains("err-not-stdout"))
        XCTAssertTrue(String(decoding: split.standardError, as: UTF8.self).contains("err-not-stdout"))

        let task = Task { try await ToolCommand.run(executable: "/bin/sleep", arguments: ["30"]) }
        try await Task.sleep(nanoseconds: 200_000_000)
        let started = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("cancel should throw")
        } catch is CancellationError {
            XCTAssertLessThan(Date().timeIntervalSince(started), 5)
        }
    }
    #endif

    func testToolsAlwaysGetAUTF8Locale() {
        let environment = ToolEnvironment.forTools(inheriting: ["PATH": "/usr/bin", "LC_ALL": "C", "LANG": "de_DE.UTF-8"])
        XCTAssertEqual(environment["LC_ALL"], ToolEnvironment.utf8Locale)
        XCTAssertEqual(environment["PATH"], "/usr/bin")
        XCTAssertEqual(environment["LANG"], "de_DE.UTF-8")
        XCTAssertEqual(ToolEnvironment.forTools(inheriting: [:])["LC_ALL"], ToolEnvironment.utf8Locale)
        XCTAssertTrue(ToolEnvironment.utf8Locale.hasSuffix(".UTF-8"))
    }

    func testStdoutSplitterSplitsOnCRAndLFAcrossChunks() {
        var splitter = StdoutLineSplitter()
        XCTAssertEqual(splitter.append(Data("#GUI#progress 10%\r".utf8)), ["#GUI#progress 10%"])
        XCTAssertEqual(splitter.append(Data("\n#GUI#progress 20%\n".utf8)), ["#GUI#progress 20%"])

        var broken = StdoutLineSplitter()
        XCTAssertEqual(broken.append(Data("hel".utf8)), [])
        XCTAssertEqual(broken.append(Data("lo\rworld".utf8)), ["hello"])
        XCTAssertEqual(broken.finish(), ["world"])

        var paired = StdoutLineSplitter()
        XCTAssertEqual(paired.append(Data("A\r\nB\n".utf8)), ["A", "B"])
        XCTAssertEqual(paired.finish(), [])

        var held = StdoutLineSplitter()
        XCTAssertEqual(held.append(Data("A\r".utf8)), ["A"])
        XCTAssertEqual(held.append(Data("B\n".utf8)), ["B"])
    }
}

private final class LineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    func add(_ line: String) {
        lock.lock()
        stored.append(line)
        lock.unlock()
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
