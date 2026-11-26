import Foundation

// Time remaining for a running batch (issue #23; layout contract v2.4). Rules:
// - The current file's remaining time is `elapsed × (100 − percent) / percent`.
// - Each file still queued after this one adds the average duration of files whose
//   mux already finished in this run. When none have finished, that average is this
//   file's own projected duration (`elapsed × 100 / percent`).
// - Hide at 0%, under `stablePercent` (5), at 100% and above, when elapsed is 0,
//   and after Cancel. 100% hides because mkvmerge keeps writing the cue index with
//   no further percent. Below 5% the sample is too small to extrapolate.
// - Wording rounds to the nearest second (halves away from zero). Under 60 seconds:
//   `About N second(s) left`, and a rounded 0 is shown as 1 second. Under 60 minutes:
//   the nearest minute, `About N minute(s) left`. From 60 minutes: whole hours plus
//   leftover minutes, `About 2 hours left` or `About 1 hour 30 minutes left`.
// - `event` publishes through `ProgressThrottle` (about 10 a second). The first
//   visible caption and a hide publish immediately.

public struct RunETA: Sendable {
    /// The first percent that is large enough to extrapolate. Below this, the caption stays empty.
    public static let stablePercent = 5

    public struct Sample: Equatable, Sendable {
        public var percent: Int
        public var elapsed: TimeInterval
        public var finishedDurations: [TimeInterval]
        /// Files still waiting after the one that is running.
        public var queuedAfterCurrent: Int
        public var cancelled: Bool

        public init(
            percent: Int,
            elapsed: TimeInterval,
            finishedDurations: [TimeInterval],
            queuedAfterCurrent: Int,
            cancelled: Bool = false
        ) {
            self.percent = percent
            self.elapsed = elapsed
            self.finishedDurations = finishedDurations
            self.queuedAfterCurrent = queuedAfterCurrent
            self.cancelled = cancelled
        }
    }

    private var throttle = ProgressThrottle()
    private var lastCaption = ""

    public init() {}

    /// Empty when the caption should be hidden.
    public static func caption(_ sample: Sample) -> String {
        guard let seconds = remainingSeconds(sample) else { return "" }
        return sentence(seconds)
    }

    /// A progress event, or nil when this tick should not be published.
    public mutating func event(for sample: Sample, at now: Date = Date()) -> RunEvent? {
        let caption = Self.caption(sample)
        if caption == lastCaption { return nil }
        let force = caption.isEmpty || lastCaption.isEmpty
        guard throttle.shouldPublish(at: now, force: force) else { return nil }
        lastCaption = caption
        return .progress(caption: caption)
    }

    static func remainingSeconds(_ sample: Sample) -> TimeInterval? {
        guard !sample.cancelled else { return nil }
        let percent = min(100, max(0, sample.percent))
        guard percent >= stablePercent, percent < 100 else { return nil }
        guard sample.elapsed > 0, sample.queuedAfterCurrent >= 0 else { return nil }
        let fraction = Double(percent) / 100
        let projected = sample.elapsed / fraction
        let remainingCurrent = projected - sample.elapsed
        let average: TimeInterval
        if sample.finishedDurations.isEmpty {
            average = projected
        } else {
            let total = sample.finishedDurations.reduce(0, +)
            average = total / Double(sample.finishedDurations.count)
        }
        let remaining = remainingCurrent + average * Double(sample.queuedAfterCurrent)
        guard remaining.isFinite, remaining >= 0 else { return nil }
        return remaining
    }

    static func sentence(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "" }
        let rounded = Int(seconds.rounded())
        if rounded < 60 {
            let count = max(1, rounded)
            return count == 1 ? "About 1 second left" : "About \(count) seconds left"
        }
        let minutesTotal = Int((Double(rounded) / 60).rounded())
        if minutesTotal < 60 {
            return minutesTotal == 1 ? "About 1 minute left" : "About \(minutesTotal) minutes left"
        }
        let hours = minutesTotal / 60
        let minutes = minutesTotal % 60
        let hourWord = hours == 1 ? "hour" : "hours"
        if minutes == 0 {
            return "About \(hours) \(hourWord) left"
        }
        let minuteWord = minutes == 1 ? "minute" : "minutes"
        return "About \(hours) \(hourWord) \(minutes) \(minuteWord) left"
    }
}
