//
//  ScriptOutputWindow.swift
//  DuctTape
//

import SwiftUI
import AppKit


struct ScriptOutputWindow: View {
    let scriptId: UUID
    @ObservedObject var scriptManager: ScriptManager
    @State private var showCopiedMessage = false
    @State private var scrollPosition = ScrollPosition()

    private var script: ScriptItem? {
        scriptManager.scripts.first { $0.id == scriptId }
    }

    var body: some View {
        Group {
            if let script = script {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with script info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(script.status.icon)
                                .font(.title2)
                            Text(script.url.lastPathComponent)
                                .font(.headline)
                                .lineLimit(1)

                            Spacer()

                            // Status indicator
                            Button(action: {
                                if let process = script.process {
                                    copyToClipboard(text: "\(process.processIdentifier)")
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showCopiedMessage = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showCopiedMessage = false
                                        }
                                    }
                                }
                            }) {
                                Text(showCopiedMessage ? "Copied" : statusText(for: script))
                                    .font(.caption)
                                    .foregroundColor(statusColor(for: script))
                                    .frame(minWidth: 120)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(for: script).opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .focusable(false)
                            .disabled(!(script.status == .running && script.process != nil))
                            .onHover { isHovering in
                                if isHovering && script.status == .running && script.process != nil {
                                    NSCursor.pointingHand.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                        }

                        Button(action: {
                            NSWorkspace.shared.selectFile(script.url.path, inFileViewerRootedAtPath: "")
                        }) {
                            Text(script.url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Divider()

                    // Control buttons
                    HStack {
                        if script.status == .running {
                            Button("Stop") {
                                scriptManager.stopScript(script)
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Restart") {
                                scriptManager.restartScript(script)
                            }
                        } else {
                            Button("Run") {
                                scriptManager.runScript(script)
                            }
                            .buttonStyle(.borderedProminent)

                            if script.status == .error {
                                Button("Reset") {
                                    scriptManager.resetScript(script)
                                }
                            }
                        }

                        Button("Clear Output") {
                            clearOutput()
                        }
                        .disabled(script.outputLines.isEmpty)

                        Spacer()

                        Toggle("Run on App Launch", isOn: Binding(
                            get: { script.autoStart },
                            set: { _ in scriptManager.toggleAutoStart(script) }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                    }
                    .padding(.horizontal)

                    // Output area
                    ScrollView {
                        VStack(alignment: .leading) {
                            if script.outputLines.isEmpty {
                                Text("No output yet...")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(script.outputLines.joined(separator: "\n"))
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                    }
                    .scrollPosition($scrollPosition, anchor: .bottom)
                    .defaultScrollAnchor(.bottom)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } else {
                VStack {
                    Text("Script not found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("This script may have been removed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.windowBackgroundColor))
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(Color(.windowBackgroundColor))
    }

    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func statusText(for script: ScriptItem) -> String {
        switch script.status {
        case .idle:
            return "Idle"
        case .running:
            if let process = script.process {
                return "Running (PID: \(process.processIdentifier))"
            } else {
                return "Running"
            }
        case .error:
            return "Error"
        }
    }

    private func statusColor(for script: ScriptItem) -> Color {
        switch script.status {
        case .idle:
            return .secondary
        case .running:
            return .green
        case .error:
            return .red
        }
    }

    private func clearOutput() {
        if let index = scriptManager.scripts.firstIndex(where: { $0.id == scriptId }) {
            scriptManager.clearOutput(for: index)
        }
    }
}

// Window management for script output
class OutputWindowManager: ObservableObject {
    static let shared = OutputWindowManager()

    private var windows: [UUID: NSWindow] = [:]

    func openOutputWindow(for script: ScriptItem) {
        // If window already exists, bring it to front
        if let existingWindow = windows[script.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Output - \(script.url.lastPathComponent)"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ScriptOutputWindow_\(script.url.lastPathComponent)")

        let contentView = ScriptOutputWindow(scriptId: script.id, scriptManager: ScriptManager.shared)
        window.contentView = NSHostingView(rootView: contentView)

        // Handle window closing
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.windows.removeValue(forKey: script.id)
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windows[script.id] = window
    }

    func closeWindow(for scriptId: UUID) {
        windows[scriptId]?.close()
        windows.removeValue(forKey: scriptId)
    }

    func closeAllWindows() {
        for window in windows.values {
            window.close()
        }
        windows.removeAll()
    }
}
