//
//  ScriptShortcutApp.swift
//  ScriptShortcut
//

import SwiftUI

@main
struct ScriptShortcutApp: App {
    @State private var scriptURLs: [URL] = []

    init() {
        _scriptURLs = State(initialValue: loadScripts())
    }

    var body: some Scene {
        MenuBarExtra("▶") {
            ForEach(scriptURLs, id: \.path) { url in
                Button(url.lastPathComponent) {
                    print("Selected script: \(url.path)")
                }
            }

            if !scriptURLs.isEmpty {
                Divider()
            }

            Button("Add script") {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowsMultipleSelection = false

                if openPanel.runModal() == .OK {
                    if let url = openPanel.url {
                        scriptURLs.append(url)
                        scriptURLs.sort { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                        saveScripts()
                    }
                }
            }

            if !scriptURLs.isEmpty {
                Menu("Remove script") {
                    ForEach(scriptURLs, id: \.path) { url in
                        Button(url.lastPathComponent) {
                            if let index = scriptURLs.firstIndex(where: { $0.path == url.path }) {
                                scriptURLs.remove(at: index)
                                saveScripts()
                            }
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

    private func saveScripts() {
        let scriptPaths = scriptURLs.map { $0.path }
        UserDefaults.standard.set(scriptPaths, forKey: "savedScripts")
    }

    private func loadScripts() -> [URL] {
        if let scriptPaths = UserDefaults.standard.stringArray(forKey: "savedScripts") {
            let urls = scriptPaths.map { URL(fileURLWithPath: $0) }
            return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        }
        return []
    }
}
