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
    private let sections = [String(
        localized: "settings.app.tab.general",
        defaultValue: "General",
        comment: "Segment title for general settings tab"
    ), String(
        localized: "settings.app.tab.grid",
        defaultValue: "Grid",
        comment: "Segment title for grid settings tab"
    ), String(
        localized: "settings.app.tab.rules",
        defaultValue: "Rules",
        comment: "Segment title for rules settings tab"
    )]

    var body: some View {
        VStack(spacing: 0) {
            // ── Page Header ──────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(
                        localized: "settings.app.title",
                        defaultValue: "Settings",
                        comment: "Main title for app settings view"
                    ))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(String(
                        localized: "settings.app.subtitle.customize",
                        defaultValue: "Customize FrogDrop to your liking",
                        comment: "Subtitle text under settings title"
                    ))
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
            SettingsSection(title: String(
                localized: "settings.app.menu-bar-icon.section-title",
                defaultValue: "Menu Bar Icon",
                comment: "Section title for menu bar icon settings"
            ), icon: "face.smiling.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(String(
                        localized: "settings.app.menu-bar-icon.style.label",
                        defaultValue: "Icon Style",
                        comment: "Label for icon style picker"
                    ), selection: $menuBarIconStyle) {
                        Text(String(
                            localized: "settings.app.menu-bar-icon.style.default-frog",
                            defaultValue: "Default Frog",
                            comment: "Picker option for default frog icon style"
                        )).tag("frog")
                        Text(String(
                            localized: "settings.app.menu-bar-icon.style.minimal-white",
                            defaultValue: "Minimal White",
                            comment: "Picker option for minimal white icon style"
                        )).tag("minimal")
                        Text(String(
                            localized: "settings.app.menu-bar-icon.style.custom-image",
                            defaultValue: "Custom Image",
                            comment: "Picker option for custom image icon style"
                        )).tag("custom")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: menuBarIconStyle) { _, _ in HapticManager.shared.click() }
                    
                    if menuBarIconStyle == "custom" {
                        HStack {
                            Button(String(
                                localized: "settings.app.menu-bar-icon.choose-image",
                                defaultValue: "Choose Image...",
                                comment: "Button title to choose a custom menu bar icon image"
                            ), action: selectCustomImage)
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
            
            SettingsSection(title: String(
                localized: "settings.app.haptics.section-title",
                defaultValue: "Haptics",
                comment: "Section title for haptics settings"
            ), icon: "hand.tap.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(
                        localized: "settings.app.haptics.description",
                        defaultValue: "Feedback intensity when interacting with FrogDrop.",
                        comment: "Description text for haptics settings section"
                    ))
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

            SettingsSection(title: String(
                localized: "settings.app.url-shortening.section-title",
                defaultValue: "URL Shortening",
                comment: "Section title for URL shortening settings"
            ), icon: "link.badge.plus") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(
                        localized: "settings.app.url-shortening.description",
                        defaultValue: "Automatically shorten copied URLs by stripping tracking parameters locally.",
                        comment: "Description text for automatic URL shortening behavior"
                    ))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Toggle(String(
                        localized: "settings.app.url-shortening.toggle",
                        defaultValue: "Shorten Copied Links Automatically",
                        comment: "Toggle label to enable automatic shortening of copied links"
                    ), isOn: $autoCleanURLs)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12))
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.clipboard-retention.section-title",
                defaultValue: "Clipboard Retention",
                comment: "Section title for clipboard retention settings"
            ), icon: "clock.arrow.circlepath") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(
                        localized: "settings.app.clipboard-retention.description",
                        defaultValue: "Auto-delete old unpinned clipboard items.",
                        comment: "Description text for clipboard auto-delete setting"
                    ))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Toggle(String(
                            localized: "settings.app.clipboard-retention.enable-auto-delete",
                            defaultValue: "Enable Auto-delete",
                            comment: "Toggle label to enable clipboard auto-delete"
                        ), isOn: Binding(
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
                                Text(String(
                                    localized: "settings.app.clipboard-retention.duration.one-day",
                                    defaultValue: "1 Day",
                                    comment: "Picker option for one-day clipboard retention duration"
                                )).tag(1)
                                Text(String(
                                    localized: "settings.app.clipboard-retention.duration.seven-days",
                                    defaultValue: "7 Days",
                                    comment: "Picker option for seven-day clipboard retention duration"
                                )).tag(7)
                                Text(String(
                                    localized: "settings.app.clipboard-retention.duration.fourteen-days",
                                    defaultValue: "14 Days",
                                    comment: "Picker option for fourteen-day clipboard retention duration"
                                )).tag(14)
                                Text(String(
                                    localized: "settings.app.clipboard-retention.duration.thirty-days",
                                    defaultValue: "30 Days",
                                    comment: "Picker option for thirty-day clipboard retention duration"
                                )).tag(30)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.clipboard-expiry.section-title",
                defaultValue: "Clipboard Expiry",
                comment: "Section title for temporary clipboard item expiry settings"
            ), icon: "clock.badge.xmark") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(
                        localized: "settings.app.clipboard-expiry.description",
                        defaultValue: "Auto-delete items copied from temporary applications.",
                        comment: "Description for automatic deletion of clipboard items from temporary apps"
                    ))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack {
                        Slider(value: $clipboardManager.tempDuration, in: 15...120, step: 5)
                            .accentColor(accent)
                            .onChange(of: clipboardManager.tempDuration) { _, _ in
                                clipboardManager.saveSettings()
                            }

                        Text(String(format: String(
                            localized: "settings.app.clipboard-expiry.duration-seconds",
                            defaultValue: "%ds",
                            comment: "Label showing temporary clipboard expiry duration in seconds"
                        ), Int(clipboardManager.tempDuration)))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 36)
                    }
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.daily-focus-goal.section-title",
                defaultValue: "Daily Focus Goal",
                comment: "Section title for configuring daily focus goal"
            ), icon: "target") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(
                        localized: "settings.app.daily-focus-goal.description",
                        defaultValue: "Set your daily focus target (minimum 120 minutes).",
                        comment: "Description for daily focus goal setting"
                    ))
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

                        Text(String(format: String(
                            localized: "settings.app.daily-focus-goal.value-minutes",
                            defaultValue: "%dm",
                            comment: "Label showing configured daily focus goal in minutes"
                        ), dailyFocusGoal))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.appearance.section-title",
                defaultValue: "Appearance",
                comment: "Section title for appearance settings"
            ), icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(
                            localized: "settings.app.appearance.darkness.description",
                            defaultValue: "Adjust the darkness of the menu bar popup window.",
                            comment: "Description for menu bar popup darkness control"
                        ))
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

                        Text(uiDimOpacity < 0.15 ? String(
                            localized: "settings.app.appearance.darkness.fully-transparent",
                            defaultValue: "Fully Transparent",
                            comment: "Appearance option for fully transparent popup style"
                        ) : uiDimOpacity < 0.45 ? String(
                            localized: "settings.app.appearance.darkness.light",
                            defaultValue: "Light",
                            comment: "Appearance option for light popup darkness"
                        ) : uiDimOpacity < 0.75 ? String(
                            localized: "settings.app.appearance.darkness.medium",
                            defaultValue: "Medium",
                            comment: "Appearance option for medium popup darkness"
                        ) : String(
                            localized: "settings.app.appearance.darkness.dark",
                            defaultValue: "Dark",
                            comment: "Appearance option for dark popup darkness"
                        ))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.06))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(
                            localized: "settings.app.appearance.popup-window-style.label",
                            defaultValue: "Popup Window Style",
                            comment: "Label for selecting popup window style"
                        ))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Picker("", selection: $popupStyle) {
                            Text(String(
                                localized: "settings.app.appearance.popup-window-style.popover-classic",
                                defaultValue: "Popover (Classic)",
                                comment: "Option label for classic popover window style"
                            )).tag("popover")
                            Text(String(
                                localized: "settings.app.appearance.popup-window-style.panel-wifi-style",
                                defaultValue: "Panel (WiFi Style)",
                                comment: "Option label for panel style popup window"
                            )).tag("panel")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: popupStyle) { _, _ in HapticManager.shared.click() }
                        
                        Text(popupStyle == "popover" ? String(
                            localized: "settings.app.appearance.popup-window-style.popover-classic.description",
                            defaultValue: "Classic popover anchored with a pointer arrow to the status item.",
                            comment: "Description of classic popover style option"
                        ) : String(
                            localized: "settings.app.appearance.popup-window-style.panel-wifi-style.description",
                            defaultValue: "Floating window style directly below the status item, matching native system menus.",
                            comment: "Description of panel style popup option"
                        ))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.updates-about.section-title",
                defaultValue: "Updates & About",
                comment: "Section title for updates and about information in settings"
            ), icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsInfoRow(label: String(
                        localized: "settings.app.updates-about.current-version.label",
                        defaultValue: "Current Version",
                        comment: "Label for current app version row"
                    ), value: UpdateManager.shared.currentVersion)
                    SettingsInfoRow(label: String(
                        localized: "settings.app.updates-about.build.label",
                        defaultValue: "Build",
                        comment: "Label for build information row"
                    ), value: String(
                        localized: "settings.app.updates-about.build.value.release-open-source",
                        defaultValue: "Release (Open Source)",
                        comment: "Build type value shown in updates and about section"
                    ))
                    SettingsInfoRow(label: String(
                        localized: "settings.app.updates-about.platform.label",
                        defaultValue: "Platform",
                        comment: "Label for platform information row"
                    ), value: String(
                        localized: "settings.app.updates-about.platform.value.macos14-apple-silicon-intel",
                        defaultValue: "macOS 14+ (Apple Silicon & Intel)",
                        comment: "Platform requirement value shown in updates and about section"
                    ))
                    
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
                        Text(String(format: String(
                            localized: "settings.app.updates-about.update-available.version",
                            defaultValue: "%@ Available!",
                            comment: "Update availability message with latest version number"
                        ), "\(updateManager.latestVersion)"))
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
                                Text(String(
                                    localized: "settings.app.updates-about.update-relaunch-now.button",
                                    defaultValue: "Update & Relaunch Now",
                                    comment: "Primary action button title to install update and relaunch immediately"
                                ))
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
                        Text(updateManager.statusMessage.isEmpty ? String(
                            localized: "settings.app.updates-about.up-to-date.message",
                            defaultValue: "FrogDrop is up to date",
                            comment: "Status message when app is already on the latest version"
                        ) : updateManager.statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(updateManager.errorMessage != nil ? .red : .secondary)
                        
                        if let date = updateManager.lastCheckDate {
                            Text(String(format: String(
                                localized: "settings.app.updates-about.last-checked",
                                defaultValue: "Last checked: %@",
                                comment: "Status text showing last successful update check timestamp"
                            ), "\(date.formatted(date: .abbreviated, time: .shortened))"))
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
                                Text(String(
                                    localized: "settings.app.updates-about.check-for-updates.button",
                                    defaultValue: "Check for Updates",
                                    comment: "Button title to manually check for updates"
                                ))
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
            SettingsSection(title: String(
                localized: "settings.app.folders-apps.section-title",
                defaultValue: "Folders & Apps",
                comment: "Section title for folders and app integrations settings"
            ), icon: "folder.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    if manager.customFolders.isEmpty {
                        Text(String(
                            localized: "settings.app.folders-apps.empty-state",
                            defaultValue: "No folders added yet.",
                            comment: "Empty state message when no custom folders are configured"
                        ))
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
                            Text(String(
                                localized: "settings.app.folders-apps.add-folder.button",
                                defaultValue: "Add Folder...",
                                comment: "Button title to add a new folder to monitored list"
                            ))
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            SettingsSection(title: String(
                localized: "settings.app.builtin-actions.section-title",
                defaultValue: "Built-in Actions",
                comment: "Section title for built-in action toggles"
            ), icon: "bolt.fill") {
                VStack(spacing: 8) {
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.inspect-exif",
                        defaultValue: "Inspect EXIF",
                        comment: "Label for built-in action that inspects EXIF metadata"
                    ), actionType: "inspectEXIF")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.extract-text-ocr",
                        defaultValue: "Extract Text (OCR)",
                        comment: "Label for built-in action that extracts text via OCR"
                    ), actionType: "ocr")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.convert-to-web-avif",
                        defaultValue: "Convert to Web (AVIF)",
                        comment: "Label for built-in action that converts images to AVIF format"
                    ), actionType: "webp")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.compress-image",
                        defaultValue: "Compress Image",
                        comment: "Label for built-in action that compresses an image"
                    ), actionType: "compress")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.strip-exif-metadata",
                        defaultValue: "Strip EXIF Metadata",
                        comment: "Label for built-in action that removes EXIF metadata"
                    ), actionType: "stripMetadata")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.merge-pdfs",
                        defaultValue: "Merge PDFs",
                        comment: "Label for built-in action that merges PDF files"
                    ), actionType: "mergePDF")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.pick-screen-color",
                        defaultValue: "Pick Screen Color",
                        comment: "Label for built-in action that samples a color from the screen"
                    ), actionType: "pickColor")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.airdrop",
                        defaultValue: "AirDrop",
                        comment: "Label for built-in action that shares via AirDrop"
                    ), actionType: "airdrop")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.send-via-email",
                        defaultValue: "Send via Email",
                        comment: "Label for built-in action that sends content via email"
                    ), actionType: "email")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.upload-to-imgur",
                        defaultValue: "Upload to Imgur",
                        comment: "Label for built-in action that uploads content to Imgur"
                    ), actionType: "imgur")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.shorten-url",
                        defaultValue: "Shorten URL",
                        comment: "Label for built-in action that shortens a URL"
                    ), actionType: "shortenURL")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.zip-files",
                        defaultValue: "Zip Files",
                        comment: "Label for built-in action that zips selected files"
                    ), actionType: "zip")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.resize-image-800px",
                        defaultValue: "Resize Image (800px)",
                        comment: "Label for built-in action that resizes image to 800 pixels"
                    ), actionType: "resizeImage")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.convert-to-png",
                        defaultValue: "Convert to PNG",
                        comment: "Label for built-in action that converts content to PNG format"
                    ), actionType: "convertImage")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.copy-file-path",
                        defaultValue: "Copy File Path",
                        comment: "Label for built-in action that copies file path"
                    ), actionType: "copyPath")
                    ToggleActionRow(title: String(
                        localized: "settings.app.builtin-actions.open-path",
                        defaultValue: "Open Path",
                        comment: "Label for built-in action that opens a file path"
                    ), actionType: "openPath")
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
            SettingsSection(title: String(
                localized: "settings.app.rules.app-preferences.section-title",
                defaultValue: "App Preferences",
                comment: "Section title for app-specific rule preferences"
            ), icon: "app.badge.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    if clipboardManager.customRules.isEmpty {
                        Text(String(
                            localized: "settings.app.rules.empty-state",
                            defaultValue: "No rules yet. Add one below.",
                            comment: "Empty state message when no rules are configured"
                        ))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(clipboardManager.customRules) { rule in
                            HStack {
                                Text(rule.appName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                
                                Spacer()
                                
                                Menu {
                                    Button(String(
                                        localized: "settings.app.rules.action.save-permanent",
                                        defaultValue: "Save (Permanent)",
                                        comment: "Rule action option to save item permanently"
                                    )) { clipboardManager.updateRule(id: rule.id, newType: .save) }
                                    Button(String(
                                        localized: "settings.app.rules.action.temporary",
                                        defaultValue: "Temporary",
                                        comment: "Rule action option to save item temporarily"
                                    )) { clipboardManager.updateRule(id: rule.id, newType: .temporary) }
                                    Button(String(
                                        localized: "settings.app.rules.action.ignore-dont-save",
                                        defaultValue: "Ignore (Don't Save)",
                                        comment: "Rule action option to ignore item and not save it"
                                    )) { clipboardManager.updateRule(id: rule.id, newType: .ignore) }
                                    Divider()
                                    Button(String(
                                        localized: "settings.app.rules.delete-rule.button",
                                        defaultValue: "Delete Rule",
                                        comment: "Button title to delete an existing rule"
                                    ), role: .destructive) { clipboardManager.removeRule(id: rule.id) }
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
            SettingsSection(title: String(
                localized: "settings.app.rules.add-rule.button",
                defaultValue: "Add Rule",
                comment: "Button title to add a new rule"
            ), icon: "plus.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    // Entry Mode Selector
                    HStack(spacing: 8) {
                        Text(String(
                            localized: "settings.app.rules.source.label",
                            defaultValue: "Source:",
                            comment: "Label for rule source field"
                        ))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Button(action: { isManualAppEntry = false }) {
                            Text(String(
                                localized: "settings.app.rules.source.running-apps",
                                defaultValue: "Running Apps",
                                comment: "Source mode label for selecting currently running applications"
                            ))
                                .font(.system(size: 10, weight: !isManualAppEntry ? .bold : .medium))
                                .foregroundColor(!isManualAppEntry ? accent : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(!isManualAppEntry ? Color.white.opacity(0.07) : Color.clear))
                        }
                        .buttonStyle(.plain)

                        Button(action: { isManualAppEntry = true }) {
                            Text(String(
                                localized: "settings.app.rules.source.manual-entry",
                                defaultValue: "Manual Entry",
                                comment: "Source mode label for manually entering application name"
                            ))
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
                        TextField(String(
                            localized: "settings.app.rules.source.manual-entry.placeholder",
                            defaultValue: "Type application name (e.g. Xcode)",
                            comment: "Placeholder text for manual app name entry field"
                        ), text: $newRuleAppName)
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
                                Text(String(
                                    localized: "settings.app.rules.source.running-apps.empty-state",
                                    defaultValue: "No active apps found",
                                    comment: "Message shown when no running applications are detected"
                                )).tag("")
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
                        Picker(String(
                            localized: "settings.app.rules.behavior.label",
                            defaultValue: "Behavior",
                            comment: "Label for rule behavior selection control"
                        ), selection: $newRuleType) {
                            Text(String(
                                localized: "settings.app.rules.behavior.temporary-expiry",
                                defaultValue: "Temporary Expiry",
                                comment: "Behavior option label for temporary expiry action"
                            )).tag(ClipboardPreferenceRule.RuleType.temporary)
                            Text(String(
                                localized: "settings.app.rules.behavior.ignore-dont-save",
                                defaultValue: "Ignore (Don't Save)",
                                comment: "Behavior option label for ignoring and not saving items"
                            )).tag(ClipboardPreferenceRule.RuleType.ignore)
                            Text(String(
                                localized: "settings.app.rules.behavior.save-permanent",
                                defaultValue: "Save Permanent",
                                comment: "Behavior option label for permanently saving items"
                            )).tag(ClipboardPreferenceRule.RuleType.save)
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
                            Text(String(
                                localized: "settings.app.rules.add-rule.confirm-button",
                                defaultValue: "Add Rule",
                                comment: "Confirmation button title for adding a new app rule"
                            ))
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
