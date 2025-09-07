import Foundation

class ScriptManager: ObservableObject {
    @Published var scripts: [ScriptItem] = []
    @Published var hasNewOutput: Bool = false
    @Published var outputUpdateTrigger: UUID = UUID()

    // Singleton instance
    static let shared = ScriptManager()

    private var notificationTimer: Timer?
    private var updateThrottlers: [UUID: ThrottleHelper<Void>] = [:]

    private var outputBufferLimit: Int {
        let key = "outputBufferLimit"
        if UserDefaults.standard.object(forKey: key) != nil {
            return UserDefaults.standard.integer(forKey: key)
        } else {
            return Configuration.outputBufferLimitDefault
        }
    }

    init() {
        scripts = loadScripts()

        // Auto-start scripts that are flagged for auto-start
        DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.dockIconDelay) {
            for script in self.scripts where script.autoStart && script.fileExists {
                self.runScript(script)
            }
        }
    }

    // Computed property to get the appropriate SF symbol
    var appIcon: String {
        let hasErrors = scripts.contains { $0.status == .error }
        let runningCount = scripts.count { $0.status == .running }
        let suffix = hasNewOutput ? ".fill" : ""

        switch (hasErrors, runningCount) {
        case (true, _):
            return "exclamationmark.circle\(suffix)"
        case (false, 0):
            return "pause.circle"
        case (false, 1...50):
            return "\(runningCount).circle\(suffix)"
        default:
            return "asterisk.circle\(suffix)"
        }
    }

    private func loadScripts() -> [ScriptItem] {
        guard let scriptsData = UserDefaults.standard.array(forKey: "savedScriptsData") as? [[String: Any]] else {
            return []
        }

        return scriptsData
            .compactMap { data -> ScriptItem? in
                guard let path = data["path"] as? String else { return nil }
                let autoStart = data["autoStart"] as? Bool ?? false
                return ScriptItem(url: URL(fileURLWithPath: path), autoStart: autoStart)
            }
            .sorted { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    private func saveScripts() {
        saveScripts(scripts)
    }

    private func saveScripts(_ scriptsToSave: [ScriptItem]) {
        let scriptsData = scriptsToSave.map { script in
            [
                "path": script.url.path,
                "autoStart": script.autoStart
            ] as [String: Any]
        }
        UserDefaults.standard.set(scriptsData, forKey: "savedScriptsData")
    }

    func addScript(url: URL) {
        let newScript = ScriptItem(url: url)
        scripts.append(newScript)
        scripts.sort { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
        saveScripts()
    }

    func removeScript(script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }

        terminateProcessIfRunning(scripts[index].process)

        updateThrottlers[script.id]?.invalidate()
        updateThrottlers.removeValue(forKey: script.id)

        scripts.remove(at: index)
        saveScripts()
    }

    func runScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }),
              script.fileExists else { return }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script.url.path]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        scripts[index].process = process
        scripts[index].status = .running
        clearOutput(for: index)

        // Handle output
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    if let scriptIndex = self.scripts.firstIndex(where: { $0.id == script.id }) {
                        self.appendOutput(lines, to: scriptIndex)
                    }
                }
            }
        }

        // Handle process termination
        process.terminationHandler = { proc in
            fileHandle.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let scriptIndex = self.scripts.firstIndex(where: { $0.id == script.id }) else { return }
                if proc.terminationReason == .uncaughtSignal {
                    self.scripts[scriptIndex].status = .idle // Process terminated by user
                } else {
                    self.scripts[scriptIndex].status = proc.terminationStatus == 0 ? .idle : .error
                }
                self.scripts[scriptIndex].process = nil
            }
        }

        do {
            try process.run()
        } catch {
            scripts[index].status = .error
            appendOutput(["Failed to run script: \(error.localizedDescription)"], to: index)
            fileHandle.readabilityHandler = nil
        }
    }

    func appendOutput(_ lines: [String], to index: Int) {
        guard outputBufferLimit != 0, index < scripts.count else { return }

        scripts[index].outputLines.append(contentsOf: lines)
        applyBufferLimit(to: index)

        // Throttle UI notifications
        let scriptId = scripts[index].id
        if updateThrottlers[scriptId] == nil {
            updateThrottlers[scriptId] = ThrottleHelper(interval: Configuration.outputThrottleInterval) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.outputUpdateTrigger = UUID() // Trigger UI refresh
                    self?.triggerNewOutputNotification()
                }
            }
        }
        updateThrottlers[scriptId]?.update(())
    }

    func clearOutput(for index: Int) {
        scripts[index].outputLines = []

        // Clear any pending throttled notifications
        let scriptId = scripts[index].id
        updateThrottlers[scriptId]?.invalidate()
        updateThrottlers.removeValue(forKey: scriptId)

        // Immediate UI update for clear action
        outputUpdateTrigger = UUID()
    }

    private func applyBufferLimit(to index: Int) {
        let bufferLimit = outputBufferLimit
        if bufferLimit > 0 && scripts[index].outputLines.count > bufferLimit {
            scripts[index].outputLines = Array(scripts[index].outputLines.suffix(bufferLimit))
        }
    }

    private func triggerNewOutputNotification() {
        hasNewOutput = true

        // Cancel existing timer if any
        notificationTimer?.invalidate()

        // Set timer to reset notification after 5 seconds
        notificationTimer = Timer.scheduledTimer(withTimeInterval: Configuration.outputActivityDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hasNewOutput = false
            }
        }
    }

    func stopScript(_ script: ScriptItem, completion: (() -> Void)? = nil) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }),
              let process = scripts[index].process,
              process.isRunning else {
            completion?()
            return
        }

        let originalHandler = process.terminationHandler
        process.terminationHandler = { proc in
            originalHandler?(proc)
            DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.scriptTerminationDelay) {
                completion?()
            }
        }

        process.terminate()
        appendOutput(["Process terminated by user"], to: index)
    }

    func restartScript(_ script: ScriptItem) {
        stopScript(script) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.scriptRestartDelay) {
                self?.runScript(script)
            }
        }
    }

    func resetScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }

        // Reset script status to idle and clear output
        scripts[index].status = .idle
        clearOutput(for: index)
        scripts[index].process = nil
    }

    func toggleAutoStart(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }

        scripts[index].autoStart.toggle()
        saveScripts()
    }

    func terminateAll() {
        for script in scripts {
            terminateProcessIfRunning(script.process)
        }

        notificationTimer?.invalidate()
        notificationTimer = nil

        for throttler in updateThrottlers.values {
            throttler.invalidate()
        }
        updateThrottlers.removeAll()
    }

    private func terminateProcessIfRunning(_ process: Process?) {
        guard let process = process, process.isRunning else { return }
        process.terminate()
    }
}