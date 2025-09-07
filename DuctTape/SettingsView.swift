import SwiftUI
import ServiceManagement
import AppKit

class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    func openSettingsWindow() {
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

        self.window = window
    }
}

struct SettingsView: View {
    @AppStorage("openOnLoginUserChoice") private var openOnLogin = false
    @AppStorage("hideDockIconUserChoice") private var hideDockIcon = false
    @AppStorage("outputBufferLimit") private var outputBufferLimit = Configuration.outputBufferLimitDefault

    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var backgroundFocused: Bool

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DuctTape Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Because defaults are for amateurs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                SettingRow(
                    icon: "power",
                    title: "Open on login",
                    description: "We'll skip the small talk",
                    isOn: $openOnLogin,
                    onToggle: toggleLaunchAtLogin
                )

                SettingRow(
                    icon: "dock.rectangle",
                    title: "Hide dock icon",
                    description: "Become one with the shadows",
                    isOn: $hideDockIcon,
                    onToggle: toggleDockIcon
                )

                OutputLimitSettingRow(
                    icon: "doc.text",
                    title: "Max output lines",
                    description: "Kept for sentimental value",
                    value: $outputBufferLimit
                )
            }

            Spacer()

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .frame(minWidth: 320, minHeight: 280, alignment: .topLeading)
        .padding(24)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    backgroundFocused = true
                }
        )
        .focused($backgroundFocused)
        .alert("Settings Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            alertMessage = "Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func toggleDockIcon(hidden: Bool) {
        let targetPolicy: NSApplication.ActivationPolicy = hidden ? .accessory : .regular
        let success = NSApplication.shared.setActivationPolicy(targetPolicy)
        if !success {
            // Reset the toggle and show error
            hideDockIcon = !hidden
            alertMessage = "Failed to \(hidden ? "hide" : "show") dock icon. Please restart the app for this setting to take effect."
            showingAlert = true
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    onToggle(newValue)
                }
            ))
            .labelsHidden()
        }
    }
}

struct OutputLimitSettingRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var value: Int
    @FocusState private var isFocused: Bool
    
    private func validateValue() {
        value = max(0, min(Configuration.outputBufferLimitMax, value))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            TextField("0-\(Configuration.outputBufferLimitMax)", value: $value, formatter: NumberFormatter())
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onSubmit(validateValue)
                .onChange(of: isFocused) { _, focused in
                    if !focused { validateValue() }
                }
        }
    }
}

#Preview {
    SettingsView()
}