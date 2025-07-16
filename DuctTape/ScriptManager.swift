import Foundation
import SwiftUI

class ScriptManager: ObservableObject {
    @Published var scripts: [ScriptItem] = []

    // Singleton instance
    static let shared = ScriptManager()

    init() {
        scripts = loadScripts()
    }

    // Computed property to get the appropriate SF symbol
    var appIcon: String {
        let hasErrors = scripts.contains(where: { $0.status == .error })
        let activeScriptCount = scripts.filter { $0.status == .running }.count

        if hasErrors && activeScriptCount > 0 {
            return "exclamationmark.circle.fill"
        } else if hasErrors {
            return "exclamationmark.circle"
        } else if activeScriptCount == 0 {
            return "pause.circle"
        } else if activeScriptCount <= 50 {
            return "\(activeScriptCount).circle.fill"
        } else {
            return "asterisk.circle.fill"
        }
    }

    private func loadScripts() -> [ScriptItem] {
        if let scriptPaths = UserDefaults.standard.stringArray(forKey: "savedScripts") {
            let urls = scriptPaths.map { URL(fileURLWithPath: $0) }
            let sortedUrls = urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            return sortedUrls.map { ScriptItem(url: $0) }
        }
        return []
    }

    private func saveScripts() {
        let scriptPaths = scripts.map { $0.url.path }
        UserDefaults.standard.set(scriptPaths, forKey: "savedScripts")
    }

    func addScript(url: URL) {
        let newScript = ScriptItem(url: url)
        scripts.append(newScript)
        scripts.sort { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
        saveScripts()
    }

    func removeScript(script: ScriptItem) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            // Terminate process if running
            if scripts[index].process != nil && scripts[index].process!.isRunning {
                scripts[index].process?.terminate()
            }
            scripts.remove(at: index)
            saveScripts()
        }
    }

    func runScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script.url.path]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        scripts[index].process = process
        scripts[index].status = .running
        scripts[index].outputLines = []

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
        scripts[index].outputLines.append(contentsOf: lines)
        if scripts[index].outputLines.count > maxOutputLines {
            scripts[index].outputLines = Array(scripts[index].outputLines.suffix(maxOutputLines))
        }
    }

    func stopScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }),
              let process = scripts[index].process,
              process.isRunning else { return }

        process.terminate()
        scripts[index].outputLines.append("Process terminated by user")
    }

    func restartScript(_ script: ScriptItem) {
        // First stop the script if it's running
        stopScript(script)

        // Wait a brief moment for the process to fully terminate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.runScript(script)
        }
    }

    func terminateAll() {
        for i in 0..<scripts.count {
            if scripts[i].process != nil && scripts[i].process!.isRunning {
                scripts[i].process?.terminate()
            }
        }
    }
}