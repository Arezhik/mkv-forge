import AppKit
import Foundation
import SwiftUI
import UserNotifications
import MKVForgeCore

// The app's state and actions (docs/design/v1-layout-contract_v2.md, v2.1 addendum).
// The rules live in MKVForgeCore (ModeState, Workflow, QuitFlow, StatusLines, …), which
// `swift test` checks on Linux; this class only feeds them and talks to AppKit. Rules:
// - Each mode keeps its own folders, scan, checkboxes and last summary.
// - Scans and batches run off the main thread. Their updates come back through an
//   AsyncStream pumped by one main-actor task, so they arrive in order.
// - Esc stops a scan (task cancel, rows untouched) or cancels a batch (`requestStop`).
// - Quitting never holds `.terminateLater` across a file (v2.1 §1.4).
// - Menus read `CommandState`, which publishes only when a flag changes (L9, L11).

/// What the menus read. Published only when a value changes (L9).
@MainActor
final class CommandState: ObservableObject {
    @Published private(set) var flags = CommandFlags()

    func update(_ new: CommandFlags) {
        if new != flags { flags = new }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var toolStatus: ToolStatus = .checking { didSet { refreshCommands() } }
    @Published private(set) var activeMode: ScanMode = .split { didSet { refreshCommands() } }
    /// Counts mode switches. Not published: it only changes together with `activeMode`. The
    /// window uses it to clear the table selection in the same update as the switch.
    private(set) var modeSwitchCount = 0
    @Published private(set) var split = ModeState(mode: .split) { didSet { refreshCommands() } }
    @Published private(set) var remux = ModeState(mode: .remux) { didSet { refreshCommands() } }
    @Published private(set) var workflow = Workflow() { didSet { refreshCommands() } }
    /// A scan that failed (a folder can't be read), shown in the Scan row caption.
    @Published private(set) var scanErrors: [ScanMode: String] = [:]
    @Published private(set) var settings = AppSettings()
    /// True when notifications are off or unavailable for MKVForge (Settings shows a note).
    @Published private(set) var notificationsBlocked = false

    let commands = CommandState()
    private(set) weak var mainWindow: NSWindow?

    private var scanTask: Task<Void, Never>?
    private var runTask: Task<Void, Never>?
    private var runner: BatchRunner?
    /// This session's recent Split outputs: a Remux scan doesn't flag them as still
    /// changing (L32). Memory only.
    private var freshOutputs = FreshOutputs()
    private var toolCheck = 0
    private var escapeMonitor: Any?
    /// Set once MKVForge has decided to quit; no more alerts or batch-end feedback.
    private var terminating = false
    /// `applicationShouldTerminate` returned `.terminateLater` and still needs a reply.
    private var awaitingTerminateReply = false

    init() {
        DebugLog.shared.configure(directory: DebugLog.libraryLogsDirectory, mirror: { AppLog.write($0) })
        let loaded = AppSettings.load(from: .standard)
        settings = loaded.settings
        activeMode = loaded.settings.activeMode
        split = ModeState(mode: .split, folders: loaded.settings.folders[.split] ?? [:])
        remux = ModeState(mode: .remux, folders: loaded.settings.folders[.remux] ?? [:])
        logLaunch()
        detectTool()
        installEscapeMonitor()
        refreshNotificationStatus()
        refreshCommands()
    }

    // MARK: Derived state

    var current: ModeState { state(for: activeMode) }
    var toolUsable: Bool { toolStatus.isUsable }
    var enablement: Enablement { workflow.enablement(current, toolUsable: toolUsable) }

    func state(for mode: ScanMode) -> ModeState {
        mode == .split ? split : remux
    }

    private func mutate(_ mode: ScanMode, _ change: (inout ModeState) -> Void) {
        switch mode {
        case .split: change(&split)
        case .remux: change(&remux)
        }
    }

    private func refreshCommands() {
        commands.update(workflow.commandFlags(state(for: activeMode), toolUsable: toolStatus.isUsable))
    }

    /// The Scan row caption for the active mode.
    var scanCaption: String {
        if case let .scanning(progress) = workflow.activity { return ScanCaption.scanning(progress) }
        if let error = scanErrors[activeMode] { return error }
        return ScanCaption.idle(current, toolUsable: toolUsable)
    }

    var scanFailed: Bool { !workflow.activity.isScanning && scanErrors[activeMode] != nil }

    // MARK: Mode and folders

    func selectMode(_ mode: ScanMode) {
        guard mode != activeMode, enablement.modeSwitch else { return }
        modeSwitchCount += 1
        activeMode = mode
        settings.activeMode = mode
        settings.save(to: .standard)
        DebugLog.shared.record(.queue, "Mode \(mode.displayName)")
    }

    /// Choose… : an open panel as a sheet, starting at the remembered folder.
    func chooseFolder(_ role: FolderRole) {
        guard enablement.chooseFolders else { return }
        let mode = activeMode
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = role == .output
        panel.prompt = "Choose"
        panel.message = "Choose the \(role.displayName) folder (\(FolderDisplay.holds(role, mode: mode)))."
        if let path = state(for: mode).folder(role) {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                self?.setFolder(url.path, role: role, mode: mode)
            }
        }
        if let window = mainWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    private func setFolder(_ path: String, role: FolderRole, mode: ScanMode) {
        guard !workflow.activity.isBusy else { return }
        mutate(mode) { $0.setFolder(path, for: role) }
        scanErrors[mode] = nil
        settings.setFolder(path, mode, role)
        settings.save(to: .standard)
        DebugLog.shared.record(.queue, "Chose the \(mode.displayName) \(role.displayName) folder")
    }

    // MARK: Scan (G2)

    func scan() {
        let mode = activeMode
        let modeState = state(for: mode)
        guard let tool = toolStatus.executable, workflow.enablement(modeState, toolUsable: true).scan else { return }
        guard workflow.startScan() else { return }
        scanErrors[mode] = nil
        let roles = ModeState.roles(for: mode)
        let folders = roles.compactMap { modeState.folder($0) }
        guard folders.count == roles.count else {
            workflow.scanEnded()
            return
        }
        DebugLog.shared.record(.queue, "Scan \(mode.displayName) started")
        announce(ScanCaption.startedAnnouncement)
        let scanner = FolderScanner(identifier: MKVMergeIdentifier(executable: tool))
        freshOutputs.prune(now: Date())
        let fresh = freshOutputs
        let (progress, progressInput) = AsyncStream<ScanProgress>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let pump = Task { [weak self] in
            for await update in progress {
                self?.workflow.scanProgress(update)
            }
        }
        scanTask = Task { [weak self] in
            let report: @Sendable (ScanProgress) -> Void = { progressInput.yield($0) }
            do {
                let result: ScanResult
                switch mode {
                case .split:
                    result = try await scanner.scanSplit(source: folders[0], output: folders[1], progress: report)
                case .remux:
                    result = try await scanner.scanRemux(video: folders[0], audio: folders[1], output: folders[2], fresh: fresh, progress: report)
                }
                progressInput.finish()
                pump.cancel()
                self?.scanFinished(result, mode: mode)
            } catch is CancellationError {
                progressInput.finish()
                pump.cancel()
                self?.scanStopped(mode: mode)
            } catch {
                progressInput.finish()
                pump.cancel()
                self?.scanFailed(error, mode: mode)
            }
        }
    }

    /// Esc or Stop Scan: the old rows come back exactly as they were.
    func stopScan() {
        guard workflow.activity.isScanning else { return }
        DebugLog.shared.record(.queue, "Scan stop requested")
        scanTask?.cancel()
    }

    private func scanFinished(_ result: ScanResult, mode: ScanMode) {
        scanTask = nil
        // One assignment: the new rows replace the old ones in one step (v2.1 §2.4).
        mutate(mode) { $0.applyScan(result) }
        workflow.scanEnded()
        DebugLog.shared.record(.queue, "Scan \(mode.displayName) finished: \(result.nameCount) names, \(result.readyCount) ready, \(result.flaggedCount) flagged")
        announce(ScanCaption.finishedAnnouncement(result))
    }

    private func scanStopped(mode: ScanMode) {
        scanTask = nil
        workflow.scanEnded()
        DebugLog.shared.record(.queue, "Scan \(mode.displayName) stopped")
        announce(ScanCaption.stoppedAnnouncement)
    }

    private func scanFailed(_ error: Error, mode: ScanMode) {
        scanTask = nil
        workflow.scanEnded()
        scanErrors[mode] = ScanCaption.failed(error)
        DebugLog.shared.record(.error, "Scan \(mode.displayName) failed", isError: true)
    }

    // MARK: Checkboxes

    func setChecked(_ id: String, _ checked: Bool) {
        guard enablement.checkboxes else { return }
        mutate(activeMode) { _ = $0.setChecked(id, checked) }
    }

    func toggle(_ ids: Set<String>) {
        guard enablement.checkboxes, !ids.isEmpty else { return }
        mutate(activeMode) { $0.toggle(ids) }
    }

    func selectAllReady() {
        guard enablement.selectAll else { return }
        mutate(activeMode) { $0.selectAllReady() }
    }

    func deselectAll() {
        guard enablement.selectAll else { return }
        mutate(activeMode) { $0.deselectAll() }
    }

    // MARK: Batch

    /// The toolbar's primary slot.
    func primaryAction() {
        switch workflow.activity {
        case .idle: startRun()
        case .running: cancelBatch()
        case .scanning, .cancelling: break
        }
    }

    func startRun() {
        let mode = activeMode
        let modeState = state(for: mode)
        guard let tool = toolStatus.executable, workflow.enablement(modeState, toolUsable: true).primary, !workflow.activity.isBusy else { return }
        let jobs = modeState.jobs()
        guard workflow.startRun(mode: mode, total: jobs.count) else { return }
        mutate(mode) { $0.beginRun(jobs) }
        let flagged = modeState.flaggedCount
        let runner = BatchRunner(executable: tool)
        self.runner = runner
        if settings.notifyWhenFinished { requestNotificationAuthorizationIfNeeded() }
        let (events, eventInput) = AsyncStream<RunEvent>.makeStream()
        let pump = Task { [weak self] in
            for await event in events {
                self?.handle(event, mode: mode)
            }
        }
        runTask = Task {
            await runner.run(jobs, flaggedCount: flagged, onEvent: { eventInput.yield($0) })
            eventInput.finish()
            // The batch is over only when every event has been shown.
            await pump.value
        }
    }

    /// Cancel: finish the current file, then stop (v2 §6).
    func cancelBatch() {
        guard workflow.cancel() else { return }
        runner?.requestStop()
        mutate(workflow.batch?.mode ?? activeMode) { $0.markCancelling() }
        DebugLog.shared.record(.queue, "Cancel requested")
    }

    private func handle(_ event: RunEvent, mode: ScanMode) {
        mutate(mode) { $0.apply(event) }
        guard case let .batchFinished(summary) = event else {
            workflow.apply(event)
            return
        }
        runner = nil
        runTask = nil
        if mode == .split {
            freshOutputs.prune(now: Date())
            freshOutputs.record(paths: summary.outputPaths, at: Date())
        }
        let action = workflow.batchEnded(
            summary,
            appIsActive: NSApp.isActive,
            notifyOn: settings.notifyWhenFinished,
            bounceOn: settings.bounceWhenFinished
        )
        switch action {
        case .quitQuietly:
            DebugLog.shared.record(.lifecycle, "Batch stopped; quitting (Finish Current File)")
            finishTerminating()
        case let .feedback(feedback):
            guard !terminating else { return }
            deliver(feedback)
        }
    }

    // MARK: Show in Finder (L7)

    /// Bottom bar: this run's outputs, or the Output folder.
    func showOutputsInFinder() {
        let modeState = current
        guard let summary = modeState.lastSummary, let output = modeState.folder(.output) else { return }
        reveal(RevealPlan.plan(outputFolder: output, outputs: summary.outputPaths, exists: Self.exists))
    }

    /// A folder field or a Done row.
    func reveal(path: String) {
        reveal(RevealPlan.plan(item: path, exists: Self.exists))
    }

    private func reveal(_ plan: RevealPlan) {
        switch plan {
        case let .select(paths):
            NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
            DebugLog.shared.record(.lifecycle, "Show in Finder: \(paths.count) item(s)")
        case let .folder(path):
            _ = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
            DebugLog.shared.record(.lifecycle, "Show in Finder: Output folder")
        case let .nothing(reason):
            DebugLog.shared.record(.lifecycle, "Show in Finder: nothing to show (\(reason))", isWarning: true)
            // A clear message when the file is gone (L7).
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Nothing to show in Finder"
            alert.informativeText = reason
            alert.addButton(withTitle: "OK")
            if let window = mainWindow, window.attachedSheet == nil {
                alert.beginSheetModal(for: window, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }

    private static func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: mkvmerge (v2 §8, §9; L15)

    /// Looks for mkvmerge off the main thread. Runs at launch, when the app becomes
    /// active, and after a Settings change.
    func detectTool() {
        toolCheck += 1
        let check = toolCheck
        let chosen = settings.chosenToolPath
        Task {
            let status = await Task.detached(priority: .utility) {
                ToolStatus.resolve(chosen: chosen)
            }.value
            guard check == self.toolCheck else { return }
            if status != self.toolStatus { self.toolStatus = status }
        }
    }

    /// Choose mkvmerge… (banner) and Choose… (Settings): the MKVToolNix app or the binary.
    func chooseTool() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose the MKVToolNix app or the mkvmerge program."
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                self?.setChosenTool(url.path)
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    private func setChosenTool(_ path: String?) {
        settings.chosenToolPath = path
        settings.save(to: .standard)
        DebugLog.shared.record(.tool, path == nil ? "mkvmerge: back to the automatic search" : "mkvmerge: a copy was chosen in Settings")
        toolStatus = .checking
        detectTool()
    }

    func useAutomaticTool() {
        setChosenTool(nil)
    }

    // MARK: Batch end feedback (v2 §7)

    func setNotify(_ on: Bool) {
        guard on != settings.notifyWhenFinished else { return }
        settings.notifyWhenFinished = on
        settings.save(to: .standard)
        DebugLog.shared.record(.lifecycle, "Notification when finished \(on ? "on" : "off")")
        refreshNotificationStatus()
    }

    func setBounce(_ on: Bool) {
        guard on != settings.bounceWhenFinished else { return }
        settings.bounceWhenFinished = on
        settings.save(to: .standard)
        DebugLog.shared.record(.lifecycle, "Dock bounce when finished \(on ? "on" : "off")")
    }

    /// Nil without a bundle ID: UNUserNotificationCenter would crash (plan §3.3).
    private var notificationCenter: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func refreshNotificationStatus() {
        guard let center = notificationCenter else {
            notificationsBlocked = true
            return
        }
        center.getNotificationSettings { [weak self] notificationSettings in
            let status = notificationSettings.authorizationStatus
            Task { @MainActor in
                self?.notificationsBlocked = status == .denied
            }
        }
    }

    /// Asked lazily, at the first batch start with the switch on (a person is there).
    private func requestNotificationAuthorizationIfNeeded() {
        guard let center = notificationCenter else {
            DebugLog.shared.record(.lifecycle, "Notifications unavailable (no bundle identifier)", isWarning: true)
            notificationsBlocked = true
            return
        }
        center.getNotificationSettings { [weak self] notificationSettings in
            guard notificationSettings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                let detail = error.map { " (\($0.localizedDescription))" } ?? ""
                DebugLog.shared.record(.lifecycle, "Notification permission \(granted ? "granted" : "not granted")\(detail)", isWarning: !granted)
                Task { @MainActor in
                    self?.notificationsBlocked = !granted
                }
            }
        }
    }

    private func deliver(_ feedback: BatchEndFeedback) {
        if feedback.bounce {
            _ = NSApp.requestUserAttention(.informationalRequest)
            DebugLog.shared.record(.lifecycle, "Dock bounce")
        }
        guard feedback.notify else { return }
        guard let center = notificationCenter else {
            DebugLog.shared.record(.lifecycle, "Notification skipped: no bundle identifier", isWarning: true)
            notificationsBlocked = true
            return
        }
        let title = feedback.title
        let body = feedback.body
        center.getNotificationSettings { [weak self] notificationSettings in
            let status = notificationSettings.authorizationStatus
            guard status == .authorized || status == .provisional else {
                DebugLog.shared.record(.lifecycle, "Notification skipped: not allowed for MKVForge", isWarning: true)
                Task { @MainActor in
                    self?.notificationsBlocked = true
                }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    DebugLog.shared.record(.lifecycle, "Notification failed: \(error.localizedDescription)", isWarning: true)
                } else {
                    DebugLog.shared.record(.lifecycle, "Notification sent")
                }
            }
        }
    }

    func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? "com.arezhik.MKVForge"
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for text in candidates {
            if let url = URL(string: text), NSWorkspace.shared.open(url) { return }
        }
        DebugLog.shared.record(.lifecycle, "Couldn't open System Settings > Notifications", isWarning: true)
    }

    // MARK: Esc (v2 §11, v2.1 §2.3)

    /// Esc stops a scan or cancels a batch while the main window is key. A local monitor,
    /// so it works whatever has focus (the table, a button).
    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad, .capsLock])
            guard modifiers.isEmpty else { return event }
            let handled = MainActor.assumeIsolated { self?.handleEscape() ?? false }
            return handled ? nil : event
        }
    }

    private func handleEscape() -> Bool {
        guard let window = mainWindow, NSApp.keyWindow === window, window.attachedSheet == nil else { return false }
        switch workflow.activity {
        case .scanning:
            stopScan()
            return true
        case .running:
            cancelBatch()
            return true
        case .idle, .cancelling:
            return false
        }
    }

    // MARK: Window and quitting (G1, v2.1 §1)

    func attachMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
        DebugLog.shared.record(.window, "Main window ready")
    }

    /// The window's close button and ⌘W.
    func mainWindowShouldClose() -> Bool {
        guard !terminating else { return true }
        switch QuitFlow.decide(workflow) {
        case .quitNow:
            return true
        case let .ask(alert):
            presentQuitAlert(alert, fromTerminate: false)
            return false
        }
    }

    /// Closing the single window quits, even with Settings open (v2.1 §1.6).
    func mainWindowWillClose() {
        guard !terminating else { return }
        terminating = true
        scanTask?.cancel()
        DebugLog.shared.record(.lifecycle, "Main window closed; quitting")
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    /// ⌘Q, the Dock's Quit, logout and shutdown.
    func shouldTerminate() -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        switch QuitFlow.decide(workflow) {
        case .quitNow:
            terminating = true
            scanTask?.cancel()
            return .terminateNow
        case let .ask(alert):
            if presentQuitAlert(alert, fromTerminate: true) {
                awaitingTerminateReply = true
                return .terminateLater
            }
            return .terminateCancel
        }
    }

    /// Shows the G1 sheet on the main window. False when it can't be shown.
    @discardableResult
    private func presentQuitAlert(_ quitAlert: QuitAlert, fromTerminate: Bool) -> Bool {
        guard let window = mainWindow else { return false }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        guard window.attachedSheet == nil else { return false }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = quitAlert.title
        alert.informativeText = quitAlert.message
        for title in quitAlert.buttons {
            alert.addButton(withTitle: title)
        }
        if alert.buttons.count == 3 {
            alert.buttons[1].hasDestructiveAction = true
            alert.buttons[1].keyEquivalent = ""
            alert.buttons[2].keyEquivalent = "\u{1b}"
        }
        DebugLog.shared.record(.lifecycle, "Quit asked while a batch runs; showing the alert")
        alert.beginSheetModal(for: window) { [weak self] response in
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            MainActor.assumeIsolated {
                self?.quitChoice(QuitChoice(buttonIndex: index), fromTerminate: fromTerminate)
            }
        }
        return true
    }

    private func quitChoice(_ choice: QuitChoice, fromTerminate: Bool) {
        if terminating {
            // The batch already ended and MKVForge is quitting.
            if fromTerminate { replyToTerminate(true) }
            return
        }
        switch choice {
        case .finishCurrentFile:
            DebugLog.shared.record(.lifecycle, "Quit choice: Finish Current File")
            if fromTerminate { replyToTerminate(false) }
            guard workflow.activity.isBatch else {
                // The batch ended while the alert was up: nothing left to finish.
                finishTerminating()
                return
            }
            let needsStop = workflow.finishThenQuit()
            if needsStop {
                runner?.requestStop()
                mutate(workflow.batch?.mode ?? activeMode) { $0.markCancelling() }
            }
            announce(QuitFlow.willQuitAnnouncement)
        case .quit:
            DebugLog.shared.record(.lifecycle, "Quit choice: Quit (hard stop)")
            hardStopThenQuit()
        case .cancel:
            DebugLog.shared.record(.lifecycle, "Quit choice: Cancel")
            if fromTerminate { replyToTerminate(false) }
        }
    }

    /// Kills mkvmerge and deletes the unfinished file (the core does both on task
    /// cancel), waits briefly for that, then quits.
    private func hardStopThenQuit() {
        terminating = true
        scanTask?.cancel()
        runTask?.cancel()
        let task = runTask
        Task {
            let deadline = Date().addingTimeInterval(3)
            while self.workflow.activity.isBatch, Date() < deadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            if task != nil, self.workflow.activity.isBatch {
                DebugLog.shared.record(.lifecycle, "Hard stop still running after 3 s; quitting anyway", isWarning: true)
            }
            self.finishTerminating()
        }
    }

    private func finishTerminating() {
        terminating = true
        let wasAwaitingReply = awaitingTerminateReply
        if let window = mainWindow, let sheet = window.attachedSheet {
            // The alert's completion sees `terminating` and only answers a pending ⌘Q.
            window.endSheet(sheet, returnCode: .abort)
        }
        if wasAwaitingReply {
            replyToTerminate(true)
        } else {
            NSApp.terminate(nil)
        }
    }

    private func replyToTerminate(_ quit: Bool) {
        guard awaitingTerminateReply else { return }
        awaitingTerminateReply = false
        if quit { terminating = true }
        NSApp.reply(toApplicationShouldTerminate: quit)
    }

    func willTerminate() {
        scanTask?.cancel()
        runTask?.cancel()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    // MARK: Debug log

    /// Help menu. The file lands on the Desktop, with a save panel if that fails.
    func exportDebugLog() {
        let summary = settings.summary
        let status = toolStatus
        Task {
            let environment = await Task.detached(priority: .userInitiated) {
                DebugMachine.environment(settings: summary, toolStatus: status)
            }.value
            let name = DebugLogDocument.fileName(at: Date())
            DebugLog.shared.record(.lifecycle, "Exporting debug log \(name)")
            let text = DebugLogDocument.document(
                environment: environment,
                logText: DebugLog.shared.recentText(),
                homeDirectory: NSHomeDirectory()
            )
            DebugLogExporter.write(text: text, fileName: name)
        }
    }

    private func logLaunch() {
        let system = ProcessInfo.processInfo.operatingSystemVersionString
        DebugLog.shared.record(.lifecycle, "Launched \(AppVersion.marketing) (\(AppVersion.build)), \(system)")
        DebugLog.shared.record(.lifecycle, "Settings \(settings.summary)")
    }

    // MARK: VoiceOver

    func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
