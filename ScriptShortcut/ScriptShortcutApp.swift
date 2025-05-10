//
//  ScriptShortcutApp.swift
//  ScriptShortcut
//

import SwiftUI

@main
struct ScriptShortcutApp: App {
    @State private var scriptURLs: [URL] = []

    var body: some Scene {
        MenuBarExtra("▶") {
            ForEach(scriptURLs, id: \.path) { url in
                Button(url.lastPathComponent) {
                    print("Selected script: \\(url.path)")
                }
            }

            if !scriptURLs.isEmpty {
                Divider()
            }

            Button("Add Script") {
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowsMultipleSelection = false

                if openPanel.runModal() == .OK {
                    if let url = openPanel.url {
                        scriptURLs.append(url)
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
