import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("openOnLoginUserChoice") private var openOnLogin = false
    @AppStorage("hideDockIconUserChoice") private var hideDockIcon = false
    @AppStorage("outputBufferLimit") private var outputBufferLimit = Configuration.outputBufferLimitDefault

    @State private var showingAlert = false
    @State private var alertMessage = ""

    private var outputMode: OutputMode {
        switch outputBufferLimit {
        case 0: return .disabled
        case -1: return .unlimited
        default: return .limited
        }
    }

    private var limitValue: Int {
        outputBufferLimit > 0 ? outputBufferLimit : Configuration.outputBufferLimitDefault
    }

    private func updateOutputSettings(mode: OutputMode, limit: Int) {
        switch mode {
        case .disabled:
            outputBufferLimit = 0
        case .unlimited:
            outputBufferLimit = -1
        case .limited:
            outputBufferLimit = max(1, limit) // Ensure at least 1 line
        }
    }

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
                    title: "Script output buffer",
                    mode: outputMode,
                    limitValue: limitValue,
                    onUpdate: updateOutputSettings
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

enum OutputMode: String, CaseIterable {
    case limited = "Limited"
    case unlimited = "Unlimited"
    case disabled = "Disabled"

    var description: String {
        switch self {
        case .limited: return "Memory ain't free"
        case .unlimited: return "You never know when you'll need it"
        case .disabled: return "Use the force, Luke!"
        }
    }
}

struct OutputLimitSettingRow: View {
    let icon: String
    let title: String
    let mode: OutputMode
    let limitValue: Int
    let onUpdate: (OutputMode, Int) -> Void

    @State private var selectedMode: OutputMode
    @State private var inputValue: Int

    init(icon: String, title: String, mode: OutputMode, limitValue: Int, onUpdate: @escaping (OutputMode, Int) -> Void) {
        self.icon = icon
        self.title = title
        self.mode = mode
        self.limitValue = limitValue
        self.onUpdate = onUpdate
        self._selectedMode = State(initialValue: mode)
        self._inputValue = State(initialValue: limitValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(selectedMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedMode == .limited {
                    TextField("Lines", value: $inputValue, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            onUpdate(selectedMode, inputValue)
                        }
                        .onChange(of: inputValue) { _, newValue in
                            // Debounce updates for better UX
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if inputValue == newValue {
                                    onUpdate(selectedMode, newValue)
                                }
                            }
                        }
                }
            }

            HStack {
                Spacer().frame(width: 32) // Align with title

                Picker("", selection: $selectedMode) {
                    ForEach(OutputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .onChange(of: selectedMode) { _, newMode in
                    onUpdate(newMode, inputValue)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
