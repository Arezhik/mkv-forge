import AppKit
import SwiftUI
import MKVForgeCore

// Two window patterns (docs/LESSONS.md L8).
//
// 1. WindowEvents (use this by default). It observes the window's notifications and
//    logs minimize, restore, key, and close to the debug log. It never replaces the
//    window's delegate, so it cannot break what SwiftUI's own delegate does. A past
//    window hang was hard to diagnose because the log had no window events at all.
//
// 2. SafeWindowDelegateProxy (use only when you must veto a close, such as for unsaved
//    edits). A forwarding proxy that keeps the original delegate and ignores
//    unknown selectors. A Swift NSWindowDelegate otherwise answers
//    `responds(to:)` with YES for every optional method; AppKit then sends one that is
//    not implemented (windowDidMiniaturize: on minimize) and raises
//    NSInvalidArgumentException, and the window stops responding.
//    Rule: list every method you implement in `implemented`, forward everything else.

/// Attach with `.background { WindowEvents(name: "Queue") }`.
struct WindowEvents: NSViewRepresentable {
    var name: String

    func makeNSView(context: Context) -> WindowEventsView {
        let view = WindowEventsView()
        view.name = name
        return view
    }

    func updateNSView(_ view: WindowEventsView, context: Context) {
        view.name = name
    }
}

final class WindowEventsView: NSView {
    var name = "window"
    private var tokens: [NSObjectProtocol] = []
    private weak var observed: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window !== observed else { return }
        // Leaving a window (window == nil) also stops the old observers, so no deinit is needed.
        stopObserving()
        guard let window else { return }
        observed = window
        let events: [(Notification.Name, String)] = [
            (NSWindow.didBecomeKeyNotification, "became key"),
            (NSWindow.didMiniaturizeNotification, "minimized"),
            (NSWindow.didDeminiaturizeNotification, "restored"),
            (NSWindow.didEnterFullScreenNotification, "entered full screen"),
            (NSWindow.didExitFullScreenNotification, "left full screen"),
            (NSWindow.willCloseNotification, "will close")
        ]
        let name = self.name
        for (notification, label) in events {
            let token = NotificationCenter.default.addObserver(forName: notification, object: window, queue: .main) { _ in
                DebugLog.shared.record(.window, "\(name) window \(label)")
            }
            tokens.append(token)
        }
    }

    private func stopObserving() {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
        tokens = []
        observed = nil
    }
}

/// The main window's accessor (v2.1 §1.4, §1.6). Attach with
/// `.background { MainWindowAccessor(model: model) }`. It hands the NSWindow to the model
/// (sheets, Esc, the G1 alert) and installs the proxy: a close while a batch runs shows
/// G1 instead, and a close that goes through quits MKVForge, even with Settings open.
struct MainWindowAccessor: NSViewRepresentable {
    let model: AppModel

    func makeNSView(context: Context) -> MainWindowAccessorView {
        let view = MainWindowAccessorView()
        view.model = model
        return view
    }

    func updateNSView(_ view: MainWindowAccessorView, context: Context) {
        view.model = model
        view.installIfNeeded()
    }
}

final class MainWindowAccessorView: NSView {
    weak var model: AppModel?
    // NSWindow.delegate is weak: this view keeps the proxy alive.
    private lazy var proxy = SafeWindowDelegateProxy()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installIfNeeded()
    }

    func installIfNeeded() {
        guard let window, let model else { return }
        model.attachMainWindow(window)
        proxy.shouldClose = { [weak model] _ in
            MainActor.assumeIsolated { model?.mainWindowShouldClose() ?? true }
        }
        proxy.onClose = { [weak model] in
            MainActor.assumeIsolated { model?.mainWindowWillClose() }
        }
        proxy.install(on: window)
    }
}

/// Install with `proxy.install(on: window)` from an NSView's viewDidMoveToWindow.
/// Keep the proxy alive (store it on that view); NSWindow.delegate is weak.
final class SafeWindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var forward: NSWindowDelegate?
    var allowClose = false
    /// Return false to keep the window open, then call `closeNow(_:)` when ready.
    var shouldClose: (NSWindow) -> Bool = { _ in true }
    var onClose: () -> Void = {}

    func install(on window: NSWindow) {
        if window.delegate !== self {
            forward = window.delegate
            window.delegate = self
        }
    }

    func closeNow(_ window: NSWindow) {
        allowClose = true
        window.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowClose {
            allowClose = false
            return true
        }
        return shouldClose(sender)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
        forward?.windowWillClose?(notification)
    }

    /// Selectors this object actually implements. Add to this set whenever you add a
    /// delegate method above. Everything else goes to SwiftUI's own delegate.
    private static let implemented: Set<Selector> = [
        #selector(windowShouldClose(_:)),
        #selector(windowWillClose(_:))
    ]

    override func responds(to aSelector: Selector!) -> Bool {
        guard let aSelector else { return false }
        if Self.implemented.contains(aSelector) { return true }
        return forward?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let aSelector, !Self.implemented.contains(aSelector) else { return nil }
        return forward
    }
}
