import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("openOnLoginUserChoice") private var openOnLogin = false
    @AppStorage("hideDockIconUserChoice") private var hideDockIcon = false

    @State private var showingAlert = false
    @State private var alertMessage = ""

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
            }

            Spacer()
        }
        .frame(minWidth: 300, minHeight: 220, alignment: .topLeading)
        .padding(24)
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

#Preview {
    SettingsView()
}
