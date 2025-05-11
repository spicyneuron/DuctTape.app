//
//  ScriptShortcutApp.swift
//  ScriptShortcut
//

import SwiftUI
import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        ScriptManager.shared.terminateAll()
    }
}

@main
struct ScriptShortcutApp: App {
    @StateObject private var scriptManager = ScriptManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("▶") {
            if !scriptManager.scripts.isEmpty {
                ForEach(scriptManager.scripts) { script in
                    Menu("\(script.status.icon) \(script.url.lastPathComponent)") {
                        if script.status == .running {
                            Button("Stop") { scriptManager.stopScript(script) }
                        } else {
                            Button("Run") { scriptManager.runScript(script) }
                        }

                        Section("Path") {
                            Button(script.url.path) {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: script.url.deletingLastPathComponent().path)
                            }
                            .font(.system(.body, design: .monospaced))
                        }

                        Section("PID") {
                            if let process = script.process, process.isRunning {
                                Text(String(process.processIdentifier))
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Text("Not running")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }

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
                        scriptManager.addScript(url: url)
                    }
                }
            }

            if !scriptManager.scripts.isEmpty {
                Menu("Remove script") {
                    ForEach(scriptManager.scripts) { script in
                        Button(script.url.lastPathComponent) {
                            scriptManager.removeScript(script: script)
                        }
                    }
                }
            }

            Divider()

            Button("Close") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
