//
//  DuctTapeApp.swift
//  DuctTape
//

import SwiftUI
import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply saved dock icon preference after a brief delay to avoid timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.dockIconDelay) {
            let hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIconUserChoice")
            if hideDockIcon {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ScriptManager.shared.terminateAll()
        OutputWindowManager.shared.closeAllWindows()

        // Slight delay to ensure all scripts are terminated
        DispatchQueue.main.asyncAfter(deadline: .now() + Configuration.appTerminationDelay) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

private struct AppIconHelper {
    static func icon(for scripts: [ScriptItem], hasNewOutput: Bool) -> String {
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
}

@main
struct DuctTapeApp: App {
    @StateObject private var scriptManager = ScriptManager.shared
    @StateObject private var outputWindowManager = OutputWindowManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            if !scriptManager.scripts.isEmpty {
                ForEach(scriptManager.scripts) { script in
                    Menu("\(script.status.icon)\(script.autoStart ? "⚡️" : "") \(script.url.lastPathComponent)",
                         content: {
                        if script.status == .running {
                            Button("Stop") { scriptManager.stopScript(script) }
                            Button("Restart") { scriptManager.restartScript(script) }
                        } else {
                            Button("Run") { scriptManager.runScript(script) }
                            if script.status == .error {
                                Button("Reset") { scriptManager.resetScript(script) }
                            }
                        }

                        Section("Path") {
                            Button(script.url.path) {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: script.url.deletingLastPathComponent().path)
                            }
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help("Open in Finder")
                        }

                        Section("Status") {
                            if let process = script.process, process.isRunning {
                                Button("PID: \(String(process.processIdentifier))") {
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(String(process.processIdentifier), forType: .string)
                                }
                                .help("Copy PID to Clipboard")
                            } else {
                                Text("Not running")
                            }

                            Button("Run on App Launch: \(script.autoStart ? "Enabled" : "Disabled")") {
                                scriptManager.toggleAutoStart(script)
                            }

                            Divider()

                            Button("Show Script Output...") {
                                outputWindowManager.openOutputWindow(for: script)
                            }
                        }
                    }, primaryAction: {
                        outputWindowManager.openOutputWindow(for: script)
                    })
                    .frame(maxWidth: Configuration.maxMenuWidth, alignment: .leading)
                }

                Divider()
            }

            Button("Add Script") {
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
                Menu("Remove Script") {
                    ForEach(scriptManager.scripts) { script in
                        Button(script.url.lastPathComponent) {
                            scriptManager.removeScript(script: script)
                        }
                    }
                }
            }

            Divider()

            Button("Settings...") {
                SettingsWindowManager.shared.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Close") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: AppIconHelper.icon(for: scriptManager.scripts, hasNewOutput: scriptManager.hasNewOutput))
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowManager.shared.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
