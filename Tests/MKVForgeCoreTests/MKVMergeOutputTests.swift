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

    func testGUIWarningAndErrorMapOntoTheSameReason() {
        let warning = "Warning: '/in/a.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored."
        let gui = "#GUI#warning '/in/a.mkv': A track with the ID 9 was requested but not found in the file. The corresponding option will be ignored.\r#GUI#warning one more\n"
        let output = MKVMergeOutput(standardOutput: Data(gui.utf8))
        XCTAssertEqual(output.warnings, [warning, "Warning: one more"])
        XCTAssertEqual(MKVMergeOutput.warningReason(output.warnings), "\(warning) (+1 more)")

        let already = MKVMergeOutput(standardOutput: Data("#GUI#warning \(warning)\n".utf8))
        XCTAssertEqual(already.warnings, [warning])

        let error = "#GUI#error The type of file '/in/g.mkv' could not be recognized.\r"
        let failed = MKVMergeOutput(standardOutput: Data(error.utf8))
        XCTAssertEqual(failed.failureReason(status: 2), "mkvmerge exit 2: The type of file '/in/g.mkv' could not be recognized.")
        XCTAssertEqual(failed.errors, ["Error: The type of file '/in/g.mkv' could not be recognized."])
    }

    func testGUIProgressAndPlaylistMarkersAreDroppedFromTheReason() {
        let text = "#GUI#begin_scanning_playlists#num_playlists=1\r#GUI#progress 80%\r#GUI#end_scanning_playlists\n#GUI#progress 4%\r#GUI#progress 100%\rThe cue entries (the index) are being written...\n"
        let output = MKVMergeOutput(standardOutput: Data(text.utf8))
        XCTAssertEqual(output.lines, ["The cue entries (the index) are being written..."])
        XCTAssertTrue(output.warnings.isEmpty)
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testGUIProgressParsesCarriageReturnsClampsAndIgnoresPlaylistScan() {
        var parser = MKVMergeGUIParser()
        let text = "#GUI#progress 4%\r#GUI#progress 100%\r#GUI#progress -2%\n#GUI#progress 150%\n"
        var percents: [Int] = []
        for line in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            if let percent = parser.progressPercent(in: String(line)) {
                percents.append(percent)
            }
        }
        XCTAssertEqual(percents, [4, 100, 0, 100])

        XCTAssertNil(parser.progressPercent(in: "#GUI#begin_scanning_playlists#num_playlists=1#num_files_in_playlists=2"))
        XCTAssertNil(parser.progressPercent(in: "#GUI#progress 80%"))
        XCTAssertNil(parser.progressPercent(in: "#GUI#end_scanning_playlists"))
        XCTAssertEqual(parser.progressPercent(in: "#GUI#progress 15%"), 15)
        XCTAssertEqual(parser.progressPercent(in: "#GUI#progress   15 %"), 15)
        XCTAssertNil(parser.progressPercent(in: "Progress: 40%"))
        XCTAssertNil(parser.progressPercent(in: "#GUI#end_scanning_playlists"))
        XCTAssertEqual(parser.progressPercent(in: "#GUI#progress 3%"), 3)
    }
}
