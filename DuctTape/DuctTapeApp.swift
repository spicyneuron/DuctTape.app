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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct DuctTapeApp: App {
    @StateObject private var scriptManager = ScriptManager.shared
    @StateObject private var outputWindowManager = OutputWindowManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private func openSettings() {
        // Check if settings window already exists using the autosave name
        if let existingWindow = NSApp.windows.first(where: { $0.frameAutosaveName == "SettingsWindow" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect.zero,
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SettingsWindow")
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        MenuBarExtra {
            if !scriptManager.scripts.isEmpty {
                ForEach(scriptManager.scripts) { script in
                    Menu("\(script.status.icon) \(script.url.lastPathComponent)") {
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
                        }

                        Section("Status") {
                            if let process = script.process, process.isRunning {
                                Text("PID: \(process.processIdentifier)")
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Text("Not running")
                                    .font(.system(.body, design: .monospaced))
                            }

                            Button("Show Output Window") {
                                outputWindowManager.openOutputWindow(for: script)
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
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Close") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: scriptManager.appIcon)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
