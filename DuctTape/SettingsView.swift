import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var openOnLogin = false
    @State private var serviceStatus: SMAppService.Status = .notRegistered // To reflect actual status

    var body: some View {
        VStack {
            Toggle("Open on login", isOn: $openOnLogin)
                .onChange(of: openOnLogin) { _, newValue in
                    toggleLaunchAtLogin(enabled: newValue)
                }
                .padding()
            Spacer() // Pushes the toggle to the top
        }
        .padding()
        .frame(width: 300, height: 150) // Give the window a reasonable size
        .onAppear {
            updateStatusAndToggle()
            // Initialize toggle from UserDefaults, will be quickly updated by SMAppService status
            openOnLogin = UserDefaults.standard.bool(forKey: "openOnLoginUserChoice")
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
