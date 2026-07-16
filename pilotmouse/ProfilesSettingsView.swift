import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfilesSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var mouseDeviceMonitor: MouseDeviceMonitor

    @State private var selectedKind: ProfileKind = .applications
    @State private var manualName = ""
    @State private var manualBundleIdentifier = ""
    @State private var transferErrorMessage: String?

    private enum ProfileKind: String, CaseIterable, Identifiable {
        case applications
        case devices

        var id: String { rawValue }
        var title: String {
            switch self {
            case .applications: "Applications"
            case .devices: "Devices"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Picker("Profile type", selection: $selectedKind) {
                    ForEach(ProfileKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)

                switch selectedKind {
                case .applications:
                    applicationProfiles
                case .devices:
                    deviceProfiles
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
        .background(AppColors.windowBackground)
        .alert(
            "Settings Transfer Failed",
            isPresented: Binding(
                get: { transferErrorMessage != nil },
                set: { if !$0 { transferErrorMessage = nil } }
            )
        ) {
            Button("OK") { transferErrorMessage = nil }
        } message: {
            Text(transferErrorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profiles")
                    .font(.headline)
                Text("Application profiles override device profiles; device profiles override global settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                importSettings()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button {
                exportSettings()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var applicationProfiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            applicationAddControls

            if settingsStore.settings.applicationProfiles.isEmpty {
                emptyState("No application profiles")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(settingsStore.settings.applicationProfiles) { profile in
                        applicationProfileCard(profile)
                    }
                }
            }
        }
    }

    private var applicationAddControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    chooseApplication()
                } label: {
                    Label("Choose App", systemImage: "app.badge.plus")
                }

                Button {
                    settingsStore.addLastActiveApplicationProfile()
                } label: {
                    Label("Add Frontmost App", systemImage: "macwindow.badge.plus")
                }
                .disabled(settingsStore.lastExternalApplicationBundleIdentifier == nil)

                if let name = settingsStore.lastExternalApplicationName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                TextField("Profile name", text: $manualName)
                    .textFieldStyle(.roundedBorder)
                TextField("Bundle identifier", text: $manualBundleIdentifier)
                    .textFieldStyle(.roundedBorder)
                Button {
                    settingsStore.addApplicationProfile(
                        name: manualName,
                        bundleIdentifier: manualBundleIdentifier
                    )
                    manualName = ""
                    manualBundleIdentifier = ""
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add application profile")
                .disabled(
                    manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || manualBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(.vertical, 4)
    }

    private var deviceProfiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            connectedDevices

            if settingsStore.settings.deviceProfiles.isEmpty {
                emptyState("No device profiles")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(settingsStore.settings.deviceProfiles) { profile in
                        deviceProfileCard(profile)
                    }
                }
            }
        }
    }

    private var connectedDevices: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected Mice")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label(
                    mouseDeviceMonitor.isMonitoring ? "HID active" : "HID unavailable",
                    systemImage: mouseDeviceMonitor.isMonitoring ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(mouseDeviceMonitor.isMonitoring ? Color.secondary : Color.red)
            }

            if mouseDeviceMonitor.devices.isEmpty {
                Text("No external mouse detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(mouseDeviceMonitor.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "computermouse")
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.callout.weight(.medium))
                            Text(deviceDescription(device))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        let configured = settingsStore.settings.deviceProfiles.contains {
                            $0.deviceIdentifier == device.identifier
                        }
                        Button {
                            settingsStore.addDeviceProfile(
                                name: device.name,
                                deviceIdentifier: device.identifier
                            )
                        } label: {
                            Image(systemName: configured ? "checkmark" : "plus")
                        }
                        .help(configured ? "Device profile configured" : "Add device profile")
                        .disabled(configured)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if let error = mouseDeviceMonitor.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func applicationProfileCard(_ profile: ApplicationProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    CommittingProfileTextField(
                        title: "Name",
                        value: currentApplicationProfile(profile.id)?.name ?? profile.name,
                        onCommit: { updateApplicationName(profile.id, value: $0) }
                    )
                        .font(.body.weight(.medium))
                    CommittingProfileTextField(
                        title: "Bundle identifier",
                        value: currentApplicationProfile(profile.id)?.bundleIdentifier ?? profile.bundleIdentifier,
                        onCommit: { updateApplicationBundleIdentifier(profile.id, value: $0) }
                    )
                        .font(.caption.monospaced())
                }

                Toggle("Enabled", isOn: applicationEnabledBinding(profile.id))
                    .toggleStyle(.switch)

                Button(role: .destructive) {
                    settingsStore.removeApplicationProfile(id: profile.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove application profile")
            }

            ProfileSettingsEditorView(
                profile: currentApplicationProfile(profile.id) ?? profile,
                onChange: settingsStore.updateApplicationProfile
            )

            refreshButton {
                guard var updated = currentApplicationProfile(profile.id) else { return }
                applyGlobalSettings(to: &updated)
                settingsStore.updateApplicationProfile(updated)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func deviceProfileCard(_ profile: MouseDeviceProfile) -> some View {
        let connected = mouseDeviceMonitor.devices.contains { $0.identifier == profile.deviceIdentifier }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    CommittingProfileTextField(
                        title: "Name",
                        value: currentDeviceProfile(profile.id)?.name ?? profile.name,
                        onCommit: { updateDeviceName(profile.id, value: $0) }
                    )
                        .font(.body.weight(.medium))
                    HStack(spacing: 6) {
                        Image(systemName: connected ? "circle.fill" : "circle")
                            .font(.system(size: 7))
                            .foregroundStyle(connected ? Color.green : Color.secondary)
                        Text(connected ? "Connected" : "Disconnected")
                        Text(profile.deviceIdentifier)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                }

                Toggle("Enabled", isOn: deviceEnabledBinding(profile.id))
                    .toggleStyle(.switch)

                Button(role: .destructive) {
                    settingsStore.removeDeviceProfile(id: profile.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove device profile")
            }

            ProfileSettingsEditorView(
                profile: currentDeviceProfile(profile.id) ?? profile,
                onChange: settingsStore.updateDeviceProfile
            )

            refreshButton {
                guard var updated = currentDeviceProfile(profile.id) else { return }
                applyGlobalSettings(to: &updated)
                settingsStore.updateDeviceProfile(updated)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func refreshButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label("Refresh From Global", systemImage: "arrow.clockwise")
            }
        }
    }

    private func emptyState(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }

    private func currentApplicationProfile(_ id: UUID) -> ApplicationProfile? {
        settingsStore.settings.applicationProfiles.first { $0.id == id }
    }

    private func currentDeviceProfile(_ id: UUID) -> MouseDeviceProfile? {
        settingsStore.settings.deviceProfiles.first { $0.id == id }
    }

    private func updateApplicationName(_ id: UUID, value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, var profile = currentApplicationProfile(id) else {
            return false
        }
        profile.name = value
        settingsStore.updateApplicationProfile(profile)
        return currentApplicationProfile(id)?.name == value
    }

    private func updateApplicationBundleIdentifier(_ id: UUID, value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !value.isEmpty,
            !settingsStore.settings.applicationProfiles.contains(where: {
                $0.id != id && $0.bundleIdentifier.caseInsensitiveCompare(value) == .orderedSame
            }),
            var profile = currentApplicationProfile(id)
        else {
            return false
        }
        profile.bundleIdentifier = value
        settingsStore.updateApplicationProfile(profile)
        return currentApplicationProfile(id)?.bundleIdentifier == value
    }

    private func applicationEnabledBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { currentApplicationProfile(id)?.isEnabled ?? false },
            set: { value in
                guard var profile = currentApplicationProfile(id) else { return }
                profile.isEnabled = value
                settingsStore.updateApplicationProfile(profile)
            }
        )
    }

    private func updateDeviceName(_ id: UUID, value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, var profile = currentDeviceProfile(id) else {
            return false
        }
        profile.name = value
        settingsStore.updateDeviceProfile(profile)
        return currentDeviceProfile(id)?.name == value
    }

    private func deviceEnabledBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { currentDeviceProfile(id)?.isEnabled ?? false },
            set: { value in
                guard var profile = currentDeviceProfile(id) else { return }
                profile.isEnabled = value
                settingsStore.updateDeviceProfile(profile)
            }
        )
    }

    private func applyGlobalSettings<Profile: ConfigurableMouseProfile>(to profile: inout Profile) {
        let settings = settingsStore.settings
        profile.buttonMappings = settings.buttonMappings
        profile.buttonChords = settings.buttonChords
        profile.buttonWheelChords = settings.buttonWheelChords
        profile.wheelMappings = settings.wheelMappings
        profile.middleClickBehavior = settings.middleClickBehavior
        profile.scrollDirection = settings.scrollDirection
        profile.verticalScrollSpeed = settings.verticalScrollSpeed
        profile.horizontalScrollSpeed = settings.horizontalScrollSpeed
        profile.scrollAccelerationEnabled = settings.scrollAccelerationEnabled
        profile.scrollAcceleration = settings.scrollAcceleration
        profile.verticalScrollSensitivity = settings.verticalScrollSensitivity
        profile.horizontalScrollSensitivity = settings.horizontalScrollSensitivity
        profile.smoothScrollingEnabled = settings.smoothScrollingEnabled
        profile.cursorControlEnabled = settings.cursorControlEnabled
        profile.accelerationEnabled = settings.accelerationEnabled
        profile.accelerationLevel = settings.accelerationLevel
        profile.sensitivityLevel = settings.sensitivityLevel
        profile.cursorAutoSnapDestination = settings.cursorAutoSnapDestination
        profile.cursorAutoSnapReturnsToOriginal = settings.cursorAutoSnapReturnsToOriginal
        profile.cursorAutoSnapMovesInstantly = settings.cursorAutoSnapMovesInstantly
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }

        settingsStore.addApplicationProfile(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: bundleIdentifier
        )
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "MousePilot Settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settingsStore.exportSettings(to: url)
        } catch {
            transferErrorMessage = error.localizedDescription
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try settingsStore.importSettings(from: url)
        } catch {
            transferErrorMessage = error.localizedDescription
        }
    }

    private func deviceDescription(_ device: MouseDeviceDescriptor) -> String {
        let vendorProduct = String(format: "%04X:%04X", device.vendorID, device.productID)
        if let transport = device.transport, !transport.isEmpty {
            return "\(transport)  \(vendorProduct)"
        }
        return vendorProduct
    }
}

private struct CommittingProfileTextField: View {
    let title: String
    let value: String
    let onCommit: (String) -> Bool

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(title: String, value: String, onCommit: @escaping (String) -> Bool) {
        self.title = title
        self.value = value
        self.onCommit = onCommit
        _draft = State(initialValue: value)
    }

    var body: some View {
        TextField(title, text: $draft)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { wasFocused, isFocused in
                if wasFocused && !isFocused {
                    commit()
                }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    draft = newValue
                }
            }
    }

    private func commit() {
        let candidate = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if onCommit(candidate) {
            draft = candidate
        } else {
            draft = value
        }
    }
}

#Preview {
    ProfilesSettingsView(
        settingsStore: SettingsStore(),
        mouseDeviceMonitor: MouseDeviceMonitor()
    )
}
