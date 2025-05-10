//
//  ScriptShortcutApp.swift
//  ScriptShortcut
//

import SwiftUI
import Foundation

// Config
let maxOutputLines = 20

// Script status enum
enum ScriptStatus {
    case idle
    case running
    case error

    var icon: String {
        switch self {
        case .idle: return "⚪️"
        case .running: return "🟢"
        case .error: return "🔴"
        }
    }
}

// Script model
struct ScriptItem: Identifiable {
    let id = UUID()
    let url: URL
    var status: ScriptStatus = .idle
    var process: Process? = nil
    var outputLines: [String] = []
}

@main
struct ScriptShortcutApp: App {
    @State private var scripts: [ScriptItem] = []

    init() {
        let urls = loadScriptURLs()
        _scripts = State(initialValue: urls.map { ScriptItem(url: $0) })
    }

    var body: some Scene {
        MenuBarExtra("▶") {
            if !scripts.isEmpty {
                // Scripts
                ForEach(scripts) { script in
                    Menu("\(script.status.icon) \(script.url.lastPathComponent)") {
                        // Run/Stop Button
                        if script.status == .running {
                            Button("Stop") {
                                stopScript(script)
                            }
                        } else {
                            Button("Run") {
                                runScript(script)
                            }
                        }

                        Divider()

                        // Output display
                        Section("Output") {
                            if script.outputLines.isEmpty {
                                Text("...")
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                ForEach(script.outputLines, id: \.self) { line in
                                    Text(line)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                    }
                }

                Divider()
            }

            Button("Add script") {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowsMultipleSelection = false

                if openPanel.runModal() == .OK {
                    if let url = openPanel.url {
                        let newScript = ScriptItem(url: url)
                        scripts.append(newScript)
                        scripts.sort { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
                        saveScripts()
                    }
                }
            }

            if !scripts.isEmpty {
                Menu("Remove script") {
                    ForEach(scripts) { script in
                        Button(script.url.lastPathComponent) {
                            if let index = scripts.firstIndex(where: { $0.id == script.id }) {
                                // Terminate process if running
                                if scripts[index].process != nil && scripts[index].process!.isRunning {
                                    scripts[index].process?.terminate()
                                }
                                scripts.remove(at: index)
                                saveScripts()
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Close") {
                // Terminate all running processes before quitting
                for i in 0..<scripts.count {
                    if scripts[i].process != nil && scripts[i].process!.isRunning {
                        scripts[i].process?.terminate()
                    }
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func runScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }

        // Create and configure process
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script.url.path]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        // Update ScriptItem
        scripts[index].status = .running
        scripts[index].process = process
        scripts[index].outputLines = []

        func appendOutput(_ lines: [String], to index: Int) {
            print("appendOutput: \(lines)")

            scripts[index].outputLines.append(contentsOf: lines)
            if scripts[index].outputLines.count > maxOutputLines {
                scripts[index].outputLines = Array(scripts[index].outputLines.suffix(maxOutputLines))
            }
        }

        // Set up pipe handling before running the process
        let fileHandle = outputPipe.fileHandleForReading

        // Make the pipe's file descriptor non-blocking
        var flags = fcntl(fileHandle.fileDescriptor, F_GETFL)
        flags = flags | O_NONBLOCK
        let result = fcntl(fileHandle.fileDescriptor, F_SETFL, flags)
        if result == -1 {
            print("Error setting non-blocking mode: \(String(cString: strerror(errno)))")
        }

        // Create a dispatch source to monitor when data is available
        let dispatchSource = DispatchSource.makeReadSource(
            fileDescriptor: fileHandle.fileDescriptor,
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        dispatchSource.setEventHandler {
            // Read available data from the pipe
            let data = fileHandle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    if let scriptIndex = self.scripts.firstIndex(where: { $0.id == script.id }) {
                        appendOutput(lines, to: scriptIndex)
                    }
                }
            }
        }

        dispatchSource.setCancelHandler {
            try? fileHandle.close()
        }

        dispatchSource.resume()

        // Start the process
        do {
            try process.run()
            DispatchQueue.global(qos: .background).async {
                process.waitUntilExit()
                dispatchSource.cancel()
                DispatchQueue.main.async {
                    guard let scriptIndex = self.scripts.firstIndex(where: { $0.id == script.id }) else { return }
                    self.scripts[scriptIndex].status = process.terminationStatus == 0 ? .idle : .error
                    self.scripts[scriptIndex].process = nil
                }
            }
        } catch {
            scripts[index].status = .error
            appendOutput(["Failed to run script: \(error.localizedDescription)"], to: index)
            print("Failed to run script: \(error)")
            dispatchSource.cancel()
        }
    }

    private func stopScript(_ script: ScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }),
              let process = scripts[index].process,
              process.isRunning else { return }

        process.terminate()
        scripts[index].outputLines.append("Process terminated by user")
        scripts[index].status = .idle
        scripts[index].process = nil
    }

    private func saveScripts() {
        let scriptPaths = scripts.map { $0.url.path }
        UserDefaults.standard.set(scriptPaths, forKey: "savedScripts")
    }

    private func loadScriptURLs() -> [URL] {
        if let scriptPaths = UserDefaults.standard.stringArray(forKey: "savedScripts") {
            let urls = scriptPaths.map { URL(fileURLWithPath: $0) }
            return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        }
        return []
    }
}
