import XCTest
@testable import MKVForgeCore

/// mkvmerge's stdout as captured from 82.0 and 103.0 in Phase 3 research.
final class MKVMergeOutputTests: XCTestCase {
    func testProgressPiecesAndBlankLinesAreDropped() {
        let text = "mkvmerge v103.0 ('The Darkness') 64-bit\n'/in/a.mkv': Using the demultiplexer for the format 'Matroska'.\nProgress: 4%\rProgress: 100%\rThe cue entries (the index) are being written...\r\n\nMultiplexing took 0 seconds.\n"
        let output = MKVMergeOutput(standardOutput: Data(text.utf8))
        XCTAssertEqual(output.lines, [
            "mkvmerge v103.0 ('The Darkness') 64-bit",
            "'/in/a.mkv': Using the demultiplexer for the format 'Matroska'.",
            "The cue entries (the index) are being written...",
            "Multiplexing took 0 seconds.",
        ])
        XCTAssertTrue(output.warnings.isEmpty)
    }

    func testOneWarningIsTheReason() {
        let warning = "Warning: '/in/a.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored."
        let output = MKVMergeOutput(standardOutput: Data("mkvmerge v82.0\n\(warning)\n".utf8))
        XCTAssertEqual(output.warnings, [warning])
        XCTAssertEqual(MKVMergeOutput.warningReason(output.warnings), warning)
        XCTAssertEqual(JobStatus.doneWithWarning(outputPath: "/o", warnings: output.warnings).helpText, warning)
    }

    func testSeveralWarningsShowTheFirstAndACount() {
        let warnings = ["Warning: one", "Warning: two", "Warning: three"]
        XCTAssertEqual(MKVMergeOutput.warningReason(warnings), "Warning: one (+2 more)")
        XCTAssertEqual(MKVMergeOutput.warningHelp(warnings), "Warning: one\nWarning: two\nWarning: three")
    }

    func testExit1WithoutWarningTextUsesTheFallback() {
        let status = JobStatus.doneWithWarning(outputPath: "/o", warnings: [])
        XCTAssertEqual(status.reasonText, "mkvmerge reported a warning (no details)")
        XCTAssertEqual(status.helpText, "mkvmerge reported a warning (no details)")
        XCTAssertEqual(status.statusText(mode: .remux), "Done · warning")
    }

    func testTheFirstErrorLineIsTheFailureReasonAndRawTextIsCapped() {
        let text = "mkvmerge v82.0\nError: The type of file '/in/g.mkv' could not be recognized.\n"
        let output = MKVMergeOutput(standardOutput: Data(text.utf8), standardError: Data("Error: second\n".utf8))
        XCTAssertEqual(output.failureReason(status: 2), "mkvmerge exit 2: The type of file '/in/g.mkv' could not be recognized.")
        XCTAssertEqual(output.errors.count, 2, "stderr is read too")
        XCTAssertEqual(MKVMergeOutput(standardOutput: Data()).failureReason(status: 2), "mkvmerge exit 2 (no details)")
        let long = MKVMergeOutput(standardOutput: Data(String(repeating: "x", count: 5000).utf8))
        XCTAssertEqual(long.rawText.count, MKVMergeOutput.rawLimit + 1)
        XCTAssertTrue(long.rawText.hasSuffix("…"))
    }
}
