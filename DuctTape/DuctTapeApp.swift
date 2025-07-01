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
                            .frame(maxWidth: outputSectionMaxWidth, alignment: .leading)
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
                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(script.outputLines, id: \.self) { line in
                                            Text(line.count > maxOutputLineLength ? String(line.prefix(maxOutputLineLength)) + "..." : line)
                                                .font(.system(.body, design: .monospaced))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(maxWidth: outputSectionMaxWidth, alignment: .leading)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxWidth: outputSectionMaxWidth, maxHeight: outputSectionMaxHeight)
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
