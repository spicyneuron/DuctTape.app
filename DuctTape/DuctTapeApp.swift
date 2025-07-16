//
//  DuctTapeApp.swift
//  DuctTape
//

import SwiftUI
import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Slight delay to ensure all scripts are terminated
        ScriptManager.shared.terminateAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct DuctTapeApp: App {
    @StateObject private var scriptManager = ScriptManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("▶") {
            if !scriptManager.scripts.isEmpty {
                ForEach(scriptManager.scripts) { script in
                    Menu("\(script.status.icon) \(script.url.lastPathComponent)") {
                        if script.status == .running {
                            Button("Stop") { scriptManager.stopScript(script) }
                            Button("Restart") { scriptManager.restartScript(script) }
                        } else {
                            Button("Run") { scriptManager.runScript(script) }
                        }

                        Section("Path") {
                            Button(script.url.path) {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: script.url.deletingLastPathComponent().path)
                            }
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
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
                                let displayLines = script.outputLines.suffix(maxOutputLines)
                                let truncatedLines = displayLines.map { line in
                                    line.count > maxOutputLineLength ? String(line.prefix(maxOutputLineLength)) + "..." : line
                                }
                                Text(truncatedLines.joined(separator: "\n"))
                                    .font(.system(.body, design: .monospaced))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: maxMenuWidth, alignment: .leading)
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

            Button("Settings...") {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 150), // Initial size, will be adapted by SettingsView
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered, defer: false)
                window.center()
                window.setFrameAutosaveName("SettingsWindow")
                window.contentView = NSHostingView(rootView: SettingsView())
                window.isReleasedWhenClosed = false // Important to keep the window instance if you plan to re-show it
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true) // Bring the app to the foreground
            }

            Divider()

            Button("Close") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
