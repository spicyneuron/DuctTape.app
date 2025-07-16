import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var openOnLogin = false
    @State private var hideDockIcon = false
    @State private var serviceStatus: SMAppService.Status = .notRegistered // To reflect actual status

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header section
            VStack(alignment: .leading, spacing: 4) {
                Text("DuctTape Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Because defaults are for amateurs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Settings section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Open on login", isOn: $openOnLogin)
                    .onChange(of: openOnLogin) { _, newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }

                Toggle("Hide dock icon", isOn: $hideDockIcon)
                    .onChange(of: hideDockIcon) { _, newValue in
                        toggleDockIcon(hidden: newValue)
                    }
            }

            Spacer()
        }
        .frame(width: 350, height: 200, alignment: .topLeading)
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 10)
        .onAppear {
            updateStatusAndToggle()
            // Initialize toggles from UserDefaults
            openOnLogin = UserDefaults.standard.bool(forKey: "openOnLoginUserChoice")
            hideDockIcon = UserDefaults.standard.bool(forKey: "hideDockIconUserChoice")
        }
    }

    private func updateStatusAndToggle() {
        serviceStatus = SMAppService.mainApp.status
        let isEnabled = (serviceStatus == .enabled)
        if openOnLogin != isEnabled { // Only update if different to avoid potential loop if called rapidly
             openOnLogin = isEnabled
        }
        UserDefaults.standard.set(isEnabled, forKey: "openOnLoginUserChoice")
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "openOnLoginUserChoice")

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                    print("Successfully registered login item.")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("Successfully unregistered login item.")
                }
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            // Revert UI and preference if operation failed
            self.openOnLogin = !enabled
            UserDefaults.standard.set(!enabled, forKey: "openOnLoginUserChoice")
        }
        // Refresh status from the service after attempting an operation
        self.updateStatusAndToggle()
    }

    private func toggleDockIcon(hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: "hideDockIconUserChoice")

        if hidden {
            NSApplication.shared.setActivationPolicy(.accessory)
        } else {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
