import SwiftUI
import AppKit
import UniformTypeIdentifiers
struct AppSettingsView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    
    @Namespace private var settingsNamespace
    
    @State private var selectedSection = 0
    @AppStorage("uiDimOpacity") private var uiDimOpacity: Double = 0.0
    @State private var previousSection = 0
    
    @State private var hapticLevel: HapticManager.HapticLevel = HapticManager.shared.level
    @State private var newRuleAppName = ""
    @State private var newRuleType: ClipboardPreferenceRule.RuleType = .temporary
    @State private var runningApps: [String] = []
    @State private var selectedRunningApp = ""
    @State private var isManualAppEntry = false

    private let accent = Color(red: 0.22, green: 0.72, blue: 0.42)
    private let sections = ["General", "Grid", "Rules"]

    var body: some View {
        VStack(spacing: 0) {
            // ── Page Header ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Customize FrogDrop to your liking")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("v1.2.0")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 16)

            // ── Segmented Tab Picker ──────────────────────────────────────
            HStack(spacing: 4) {
                ForEach(sections.indices, id: \.self) { idx in
                    Text(sections[idx])
                        .font(.system(size: 12, weight: selectedSection == idx ? .semibold : .regular, design: .rounded))
                        .foregroundColor(selectedSection == idx ? accent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            ZStack {
                                if selectedSection == idx {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.08))
                                        .matchedGeometryEffect(id: "activeSettingsSection", in: settingsNamespace)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSection != idx {
                                previousSection = selectedSection
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedSection = idx
                                }
                                HapticManager.shared.click()
                            }
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.02))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5),
                alignment: .bottom
            )

            // ── Content with Directional Slide Transition ──────────────────
            ZStack {
                if selectedSection == 0 {
                    ScrollView {
                        GeneralSettingsContent(
                            hapticLevel: $hapticLevel,
                            clipboardManager: clipboardManager,
                            accent: accent
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .id("general")
                    .transition(slideTransition(for: 0))
                } else if selectedSection == 1 {
                    ScrollView {
                        GridSettingsContent(manager: manager, accent: accent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                    }
                    .id("grid")
                    .transition(slideTransition(for: 1))
                } else {
                    ScrollView {
                        RulesSettingsContent(
                            clipboardManager: clipboardManager,
                            runningApps: $runningApps,
                            selectedRunningApp: $selectedRunningApp,
                            newRuleAppName: $newRuleAppName,
                            newRuleType: $newRuleType,
                            isManualAppEntry: $isManualAppEntry,
                            accent: accent
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .id("rules")
                    .transition(slideTransition(for: 2))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(uiDimOpacity))
        .onAppear {
            hapticLevel = HapticManager.shared.level
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { $0.localizedName }
                .filter { !$0.isEmpty }
            let uniqueApps = Array(Set(apps)).sorted()
            self.runningApps = uniqueApps
            if let first = uniqueApps.first { self.selectedRunningApp = first }
        }
    }
    
    // Directional Slide Logic ("aaga picha wala smooth")
    private func slideTransition(for index: Int) -> AnyTransition {
        if previousSection < selectedSection {
            // Moving forward (left to right) -> Enter from trailing, exit to leading
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            // Moving backward (right to left) -> Enter from leading, exit to trailing
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
}

// MARK: - General Tab Content
private struct GeneralSettingsContent: View {
    @AppStorage("dailyFocusGoal") var dailyFocusGoal: Int = 120
    @AppStorage("uiDimOpacity") var uiDimOpacity: Double = 0.0
    @AppStorage("clipboardRetentionDays") var clipboardRetentionDays: Int = 0
    @AppStorage("autoCleanURLs") var autoCleanURLs: Bool = false
    @AppStorage("menuBarIconStyle") var menuBarIconStyle: String = "frog"
    @AppStorage("menuBarCustomImagePath") var menuBarCustomImagePath: String = ""
    @AppStorage("popupStyle") var popupStyle: String = "popover"
    @Binding var hapticLevel: HapticManager.HapticLevel
    @ObservedObject var clipboardManager: ClipboardManager
    let accent: Color

    private func selectCustomImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                let targetSize = NSSize(width: 48, height: 48)
                let newImage = NSImage(size: targetSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: targetSize))
                newImage.unlockFocus()
                
                if let tiff = newImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    
                    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("FrogDrop") ?? FileManager.default.temporaryDirectory
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let path = dir.appendingPathComponent("custom_icon.png")
                    
                    try? png.write(to: path)
                    menuBarCustomImagePath = path.path
                    menuBarIconStyle = "custom"
                    HapticManager.shared.success()
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Menu Bar Icon", icon: "face.smiling.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Icon Style", selection: $menuBarIconStyle) {
                        Text("Default Frog").tag("frog")
                        Text("Minimal White").tag("minimal")
                        Text("Custom Image").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: menuBarIconStyle) { _, _ in HapticManager.shared.click() }
                    
                    if menuBarIconStyle == "custom" {
                        HStack {
                            Button("Choose Image...", action: selectCustomImage)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.white.opacity(0.08)).cornerRadius(5)
                                .buttonStyle(.plain)
                            
                            if !menuBarCustomImagePath.isEmpty {
                                Button(action: {
                                    menuBarCustomImagePath = ""
                                    UserDefaults.standard.removeObject(forKey: "menuBarCustomImagePath")
                                    HapticManager.shared.click()
                                }) { Image(systemName: "trash").foregroundColor(.red) }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            SettingsSection(title: "Haptics", icon: "hand.tap.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Feedback intensity when interacting with FrogDrop.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        ForEach(HapticManager.HapticLevel.allCases, id: \.self) { val in
                            Button(action: {
                                hapticLevel = val
                                HapticManager.shared.level = val
                                HapticManager.shared.click()
                            }) {
                                Text(val.rawValue)
                                    .font(.system(size: 11, weight: hapticLevel == val ? .bold : .medium, design: .rounded))
                                    .foregroundColor(hapticLevel == val ? .black : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(hapticLevel == val ? accent : Color.white.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            SettingsSection(title: "URL Shortening", icon: "link.badge.plus") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Automatically shorten copied URLs by stripping tracking parameters locally.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Toggle("Shorten Copied Links Automatically", isOn: $autoCleanURLs)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                }
            }

            SettingsSection(title: "Clipboard Retention", icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Auto-delete old unpinned clipboard items.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Toggle("Enable Auto-delete", isOn: Binding(
                            get: { clipboardRetentionDays > 0 },
                            set: { isOn in
                                if isOn && clipboardRetentionDays == 0 {
                                    clipboardRetentionDays = 7
                                } else if !isOn {
                                    clipboardRetentionDays = 0
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))

                        if clipboardRetentionDays > 0 {
                            Spacer()
                            Picker("", selection: $clipboardRetentionDays) {
                                Text("1 Day").tag(1)
                                Text("7 Days").tag(7)
                                Text("14 Days").tag(14)
                                Text("30 Days").tag(30)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                }
            }

            SettingsSection(title: "Clipboard Expiry", icon: "clock.badge.xmark") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Auto-delete items copied from temporary applications.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Slider(value: $clipboardManager.tempDuration, in: 15...120, step: 5)
                            .accentColor(accent)
                            .onChange(of: clipboardManager.tempDuration) { _, _ in
                                clipboardManager.saveSettings()
                            }

                        Text("\(Int(clipboardManager.tempDuration))s")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 36)
                    }
                }
            }

            SettingsSection(title: "Daily Focus Goal", icon: "target") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Set your daily focus target (minimum 120 minutes).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Slider(value: Binding(
                            get: { Double(dailyFocusGoal) },
                            set: { newValue in
                                dailyFocusGoal = max(120, Int(newValue))
                            }
                        ), in: 120...480, step: 10)
                        .accentColor(accent)

                        Text("\(dailyFocusGoal)m")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            SettingsSection(title: "Appearance", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Adjust the darkness of the menu bar popup window.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Slider(value: $uiDimOpacity, in: 0.0...1.0, step: 0.05)
                                .accentColor(accent)
                            Image(systemName: "moon")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Text(uiDimOpacity < 0.15 ? "Fully Transparent" : uiDimOpacity < 0.45 ? "Light" : uiDimOpacity < 0.75 ? "Medium" : "Dark")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.06))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popup Window Style")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Picker("", selection: $popupStyle) {
                            Text("Popover (Classic)").tag("popover")
                            Text("Panel (WiFi Style)").tag("panel")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: popupStyle) { _, _ in HapticManager.shared.click() }
                        
                        Text(popupStyle == "popover" ? "Classic popover anchored with a pointer arrow to the status item." : "Floating window style directly below the status item, matching native system menus.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }

            SettingsSection(title: "Updates & About", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsInfoRow(label: "Current Version", value: UpdateManager.shared.currentVersion)
                    SettingsInfoRow(label: "Build", value: "Release (Open Source)")
                    SettingsInfoRow(label: "Platform", value: "macOS 14+ (Apple Silicon & Intel)")
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    DashboardUpdateView(accent: accent)
                }
            }
        }
    }
}

// MARK: - Dashboard Update View
private struct DashboardUpdateView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if updateManager.updateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(accent)
                            .font(.system(size: 14))
                        Text("\(updateManager.latestVersion) Available!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                        Spacer()
                    }
                    
                    if !updateManager.releaseNotes.isEmpty {
                        Text(updateManager.releaseNotes)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    if updateManager.isUpdating {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: updateManager.downloadProgress, total: 1.0)
                                .accentColor(accent)
                            Text(updateManager.statusMessage)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            updateManager.downloadAndInstallUpdate()
                            HapticManager.shared.click()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                Text("Update & Relaunch Now")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accent)
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(accent.opacity(0.12))
                .cornerRadius(10)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(updateManager.statusMessage.isEmpty ? "FrogDrop is up to date" : updateManager.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(updateManager.errorMessage != nil ? .red : .secondary)
                        
                        if let date = updateManager.lastCheckDate {
                            Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                    Spacer()
                    
                    if updateManager.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Button(action: {
                            updateManager.checkForUpdates()
                            HapticManager.shared.click()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                Text("Check for Updates")
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Grid Tab Content
private struct GridSettingsContent: View {
    @ObservedObject var manager: DropzoneManager
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Folders & Apps", icon: "folder.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    if manager.customFolders.isEmpty {
                        Text("No folders added yet.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(manager.customFolders) { folder in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue.opacity(0.8))
                                Text(folder.name)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                Spacer()
                                Button(action: { manager.removeFolder(id: folder.id) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }

                    Button(action: { selectFolder() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Folder...")
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            SettingsSection(title: "Built-in Actions", icon: "bolt.fill") {
                VStack(spacing: 8) {
                    ToggleActionRow(title: "Inspect EXIF", actionType: "inspectEXIF")
                    ToggleActionRow(title: "Extract Text (OCR)", actionType: "ocr")
                    ToggleActionRow(title: "Convert to Web (AVIF)", actionType: "webp")
                    ToggleActionRow(title: "Compress Image", actionType: "compress")
                    ToggleActionRow(title: "Strip EXIF Metadata", actionType: "stripMetadata")
                    ToggleActionRow(title: "Merge PDFs", actionType: "mergePDF")
                    ToggleActionRow(title: "Pick Screen Color", actionType: "pickColor")
                    ToggleActionRow(title: "AirDrop", actionType: "airdrop")
                    ToggleActionRow(title: "Send via Email", actionType: "email")
                    ToggleActionRow(title: "Upload to Imgur", actionType: "imgur")
                    ToggleActionRow(title: "Shorten URL", actionType: "shortenURL")
                    ToggleActionRow(title: "Zip Files", actionType: "zip")
                    ToggleActionRow(title: "Resize Image (800px)", actionType: "resizeImage")
                    ToggleActionRow(title: "Convert to PNG", actionType: "convertImage")
                    ToggleActionRow(title: "Copy File Path", actionType: "copyPath")
                    ToggleActionRow(title: "Open Path", actionType: "openPath")
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            manager.addFolder(name: url.lastPathComponent, path: url.path)
        }
    }
}

// MARK: - Rules Tab Content (Improved Add Rule UI)
private struct RulesSettingsContent: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var runningApps: [String]
    @Binding var selectedRunningApp: String
    @Binding var newRuleAppName: String
    @Binding var newRuleType: ClipboardPreferenceRule.RuleType
    @Binding var isManualAppEntry: Bool
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "App Preferences", icon: "app.badge.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    if clipboardManager.customRules.isEmpty {
                        Text("No rules yet. Add one below.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(clipboardManager.customRules) { rule in
                            HStack {
                                Text(rule.appName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                
                                Spacer()
                                
                                Menu {
                                    Button("Save (Permanent)") { clipboardManager.updateRule(id: rule.id, newType: .save) }
                                    Button("Temporary") { clipboardManager.updateRule(id: rule.id, newType: .temporary) }
                                    Button("Ignore (Don't Save)") { clipboardManager.updateRule(id: rule.id, newType: .ignore) }
                                    Divider()
                                    Button("Delete Rule", role: .destructive) { clipboardManager.removeRule(id: rule.id) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(rule.ruleType.rawValue.capitalized)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(ruleColor(rule.ruleType))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ruleColor(rule.ruleType).opacity(0.12))
                                    .cornerRadius(6)
                                }
                                .menuStyle(.borderlessButton)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Fixed and improved Add Rule UI
            SettingsSection(title: "Add Rule", icon: "plus.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    // Entry Mode Selector
                    HStack(spacing: 8) {
                        Text("Source:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button(action: { isManualAppEntry = false }) {
                            Text("Running Apps")
                                .font(.system(size: 10, weight: !isManualAppEntry ? .bold : .medium))
                                .foregroundColor(!isManualAppEntry ? accent : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(!isManualAppEntry ? Color.white.opacity(0.07) : Color.clear))
                        }
                        .buttonStyle(.plain)

                        Button(action: { isManualAppEntry = true }) {
                            Text("Manual Entry")
                                .font(.system(size: 10, weight: isManualAppEntry ? .bold : .medium))
                                .foregroundColor(isManualAppEntry ? accent : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(isManualAppEntry ? Color.white.opacity(0.07) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 2)

                    // Input Row
                    if isManualAppEntry {
                        TextField("Type application name (e.g. Xcode)", text: $newRuleAppName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    } else {
                        Picker("", selection: $selectedRunningApp) {
                            if runningApps.isEmpty {
                                Text("No active apps found").tag("")
                            } else {
                                ForEach(runningApps, id: \.self) { app in
                                    Text(app).tag(app)
                                }
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                    }

                    // Preference Row
                    HStack(spacing: 12) {
                        Picker("Behavior", selection: $newRuleType) {
                            Text("Temporary Expiry").tag(ClipboardPreferenceRule.RuleType.temporary)
                            Text("Ignore (Don't Save)").tag(ClipboardPreferenceRule.RuleType.ignore)
                            Text("Save Permanent").tag(ClipboardPreferenceRule.RuleType.save)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )

                        Button(action: {
                            let app = isManualAppEntry 
                                ? newRuleAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                                : selectedRunningApp
                            let finalApp = app.isEmpty && !isManualAppEntry ? runningApps.first ?? "" : app
                            guard !finalApp.isEmpty else { return }
                            clipboardManager.addRule(appName: finalApp, ruleType: newRuleType)
                            newRuleAppName = ""
                            HapticManager.shared.success()
                        }) {
                            Text("Add Rule")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(accent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func ruleColor(_ type: ClipboardPreferenceRule.RuleType) -> Color {
        switch type {
        case .temporary: return .orange
        case .save: return .green
        case .ignore: return .red
        }
    }
}

// MARK: - Reusable Settings Components
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.85))
            }
            content
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary.opacity(0.7))
        }
    }
}
