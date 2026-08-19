import SwiftUI
import AppKit
import ServiceManagement

struct MenuBarSettingsView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var updateManager = UpdateManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab = 0 // 0 = General, 1 = Grid, 2 = Rules
    @State private var newRuleAppName = ""
    @State private var newRuleType: ClipboardPreferenceRule.RuleType = .temporary
    @State private var runningApps: [String] = []
    @State private var selectedRunningApp = ""
    
    // Haptic level state
    @State private var hapticLevel: HapticManager.HapticLevel = HapticManager.shared.level
    @State private var isLaunchAtLoginEnabled = false
    @AppStorage("uiDimOpacity") private var uiDimOpacity: Double = 0.0
    @AppStorage("clipboardRetentionDays") var clipboardRetentionDays: Int = 0
    @AppStorage("autoCleanURLs") var autoCleanURLs: Bool = false
    
    // Icon Style state
    @AppStorage("menuBarIconStyle") var menuBarIconStyle: String = "frog"
    @AppStorage("menuBarCustomImagePath") var menuBarCustomImagePath: String = ""
    @AppStorage("popupStyle") var popupStyle: String = "popover"
    
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
        VStack(spacing: 0) {
            // Minimalist Tab Bar
            HStack(spacing: 16) {
                TabButton(title: String(localized: "settings.menu-bar.tab.general", defaultValue: "General", comment: "Tab title for general menu bar settings section"), isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 0
                    }
                }
                TabButton(title: String(localized: "settings.menu-bar.tab.grid", defaultValue: "Grid", comment: "Tab title for dropzone grid settings section"), isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
                TabButton(title: String(localized: "settings.menu-bar.tab.rules", defaultValue: "Rules", comment: "Tab title for app rules settings section"), isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 2
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Tab Contents
            ZStack {
                if selectedTab == 0 {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            
                            // Menu Bar Icon Section
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "settings.menu-bar.general.menu-bar-icon.section-title", defaultValue: "MENU BAR ICON", comment: "Section header for menu bar icon settings"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                HStack(spacing: 4) {
                                    let options = [
                                        ("frog", String(localized: "settings.menu-bar.general.menu-bar-icon.style.frog", defaultValue: "Frog", comment: "Picker option for frog icon style"), "face.smiling"),
                                        ("minimal", String(localized: "settings.menu-bar.general.menu-bar-icon.style.minimal", defaultValue: "Minimal", comment: "Picker option for minimal icon style"), "square.and.arrow.down.fill"),
                                        ("custom", String(localized: "settings.menu-bar.general.menu-bar-icon.style.custom", defaultValue: "Custom", comment: "Picker option for custom icon style"), "photo")
                                    ]
                                    ForEach(options, id: \.0) { opt in
                                        Button(action: {
                                            menuBarIconStyle = opt.0
                                            HapticManager.shared.click()
                                        }) {
                                            VStack(spacing: 4) {
                                                Image(systemName: opt.2)
                                                    .font(.system(size: 14))
                                                Text(opt.1)
                                                    .font(.system(size: 10, weight: menuBarIconStyle == opt.0 ? .bold : .medium, design: .rounded))
                                            }
                                            .foregroundColor(menuBarIconStyle == opt.0 ? .black : .primary)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(menuBarIconStyle == opt.0 ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if menuBarIconStyle == "custom" {
                                    HStack {
                                        Button(String(localized: "settings.menu-bar.general.menu-bar-icon.choose-image", defaultValue: "Choose Image...", comment: "Button title to choose a custom menu bar icon image"), action: selectCustomImage)
                                            .font(.system(size: 10, weight: .medium))
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.white.opacity(0.08)).cornerRadius(5)
                                            .buttonStyle(.plain)
                                        
                                        if !menuBarCustomImagePath.isEmpty {
                                            Button(action: {
                                                menuBarCustomImagePath = ""
                                                UserDefaults.standard.removeObject(forKey: "menuBarCustomImagePath")
                                                HapticManager.shared.click()
                                            }) {
                                                Image(systemName: "trash").foregroundColor(.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "settings.menu-bar.general.haptics.section-title", defaultValue: "HAPTICS", comment: "Section header for haptics settings"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                HStack(spacing: 4) {
                                    ForEach(HapticManager.HapticLevel.allCases, id: \.self) { val in
                                        Button(action: {
                                            hapticLevel = val
                                            HapticManager.shared.level = val
                                            HapticManager.shared.click()
                                        }) {
                                            Text(val.rawValue)
                                                .font(.system(size: 11, weight: hapticLevel == val ? .bold : .medium, design: .rounded))
                                                .foregroundColor(hapticLevel == val ? .black : .primary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .frame(maxWidth: .infinity)
                                                .background(hapticLevel == val ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "settings.menu-bar.general.keep-history.section-title", defaultValue: "KEEP HISTORY", comment: "Section header for clipboard history retention settings"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Picker("", selection: $clipboardRetentionDays) {
                                        Text(String(localized: "settings.menu-bar.general.keep-history.option.forever", defaultValue: "Forever", comment: "Retention option to keep history forever")).tag(0)
                                        Text(String(localized: "settings.menu-bar.general.keep-history.option.one-day", defaultValue: "1 Day", comment: "Retention option to keep history for one day")).tag(1)
                                        Text(String(localized: "settings.menu-bar.general.keep-history.option.seven-days", defaultValue: "7 Days", comment: "Retention option to keep history for seven days")).tag(7)
                                        Text(String(localized: "settings.menu-bar.general.keep-history.option.fourteen-days", defaultValue: "14 Days", comment: "Retention option to keep history for fourteen days")).tag(14)
                                        Text(String(localized: "settings.menu-bar.general.keep-history.option.thirty-days", defaultValue: "30 Days", comment: "Retention option to keep history for thirty days")).tag(30)
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .font(.system(size: 11, design: .rounded))
                                    .frame(width: 95)
                                }
                                
                                Spacer()
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 1, height: 28)
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "settings.menu-bar.general.shorten-url.section-title", defaultValue: "SHORTEN URL", comment: "Section header for automatic URL shortening settings"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Toggle(String(localized: "settings.menu-bar.general.shorten-url.option.auto", defaultValue: "Auto", comment: "Option label for automatic URL shortening mode"), isOn: $autoCleanURLs)
                                        .toggleStyle(.checkbox)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(String(localized: "settings.menu-bar.general.temp-expiration.section-title", defaultValue: "TEMP EXPIRATION", comment: "Section header for temporary clipboard expiration settings"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    Spacer()
                                    Text(String(format: String(localized: "settings.menu-bar.general.temp-expiration.duration-seconds", defaultValue: "%ds", comment: "Label showing temporary clipboard expiration duration in seconds"), Int(clipboardManager.tempDuration)))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.orange)
                                }
                                
                                Slider(value: $clipboardManager.tempDuration, in: 15...120, step: 5)
                                    .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                    .onChange(of: clipboardManager.tempDuration) { _, _ in
                                        clipboardManager.saveSettings()
                                    }
                                
                                Text(String(localized: "settings.menu-bar.general.temp-expiration.description", defaultValue: "Auto-delete items copied from temporary applications.", comment: "Description explaining temporary app clipboard auto-delete behavior"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "settings.menu-bar.general.startup.section-title", defaultValue: "STARTUP", comment: "Section header for startup behavior settings"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                Toggle(isOn: Binding(
                                    get: { isLaunchAtLoginEnabled },
                                    set: { newValue in
                                        toggleLaunchAtLogin(newValue)
                                    }
                                )) {
                                    Text(String(localized: "settings.menu-bar.general.startup.launch-at-login", defaultValue: "Launch automatically at login", comment: "Toggle label for launching the app automatically at login"))
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .toggleStyle(.checkbox)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "settings.menu-bar.general.appearance.section-title", defaultValue: "APPEARANCE", comment: "Section header for appearance settings"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                Text(String(localized: "settings.menu-bar.general.appearance.popup-darkness.label", defaultValue: "Popup darkness", comment: "Label for popup darkness selection control"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Slider(value: $uiDimOpacity, in: 0.0...1.0, step: 0.05)
                                        .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                    Image(systemName: "moon")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(uiDimOpacity < 0.15 ? String(localized: "settings.menu-bar.general.appearance.popup-darkness.glass-fully-transparent", defaultValue: "Glass (Fully Transparent)", comment: "Appearance option for fully transparent glass popup style") : uiDimOpacity < 0.45 ? String(localized: "settings.menu-bar.general.appearance.popup-darkness.light", defaultValue: "Light", comment: "Appearance option for light popup darkness") : uiDimOpacity < 0.75 ? String(localized: "settings.menu-bar.general.appearance.popup-darkness.medium", defaultValue: "Medium", comment: "Appearance option for medium popup darkness") : String(localized: "settings.menu-bar.general.appearance.popup-darkness.dark", defaultValue: "Dark", comment: "Appearance option for dark popup darkness"))
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                
                                Divider()
                                    .background(Color.white.opacity(0.04))
                                    .padding(.vertical, 4)
                                
                                Text(String(localized: "settings.menu-bar.general.appearance.popup-window-style.label", defaultValue: "Popup window style", comment: "Label for selecting popup window style"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Button(action: {
                                        popupStyle = "popover"
                                        HapticManager.shared.click()
                                    }) {
                                        Text(String(localized: "settings.menu-bar.general.appearance.popup-window-style.popover", defaultValue: "Popover", comment: "Option label for classic popover window style"))
                                            .font(.system(size: 10, weight: popupStyle == "popover" ? .bold : .medium, design: .rounded))
                                            .foregroundColor(popupStyle == "popover" ? .black : .primary)
                                            .padding(.vertical, 5)
                                            .frame(maxWidth: .infinity)
                                            .background(popupStyle == "popover" ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        popupStyle = "panel"
                                        HapticManager.shared.click()
                                    }) {
                                        Text(String(localized: "settings.menu-bar.general.appearance.popup-window-style.panel-wifi", defaultValue: "Panel (WiFi)", comment: "Option label for panel style popup window"))
                                            .font(.system(size: 10, weight: popupStyle == "panel" ? .bold : .medium, design: .rounded))
                                            .foregroundColor(popupStyle == "panel" ? .black : .primary)
                                            .padding(.vertical, 5)
                                            .frame(maxWidth: .infinity)
                                            .background(popupStyle == "panel" ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(popupStyle == "popover" ? String(localized: "settings.menu-bar.general.appearance.popup-window-style.popover.description", defaultValue: "Classic popover with pointer arrow.", comment: "Description text for classic popover style option") : String(localized: "settings.menu-bar.general.appearance.popup-window-style.panel-wifi.description", defaultValue: "Floating window style like WiFi/Battery menus.", comment: "Description text for floating panel style option"))
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            // FrogDrop Updates Section (General Tab Bottom)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(String(localized: "settings.menu-bar.general.updates.section-title", defaultValue: "UPDATES", comment: "Section header for update status and actions"))
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    Spacer()
                                    Text(updateManager.currentVersion)
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(4)
                                }
                                
                                if updateManager.updateAvailable {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                                .font(.system(size: 11))
                                            Text(String(format: String(localized: "settings.menu-bar.general.updates.available-version", defaultValue: "%@ Available!", comment: "Update status message showing available version number"), "\(updateManager.latestVersion)"))
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                        }
                                        
                                        if !updateManager.releaseNotes.isEmpty {
                                            Text(updateManager.releaseNotes)
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        
                                        if updateManager.isUpdating {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ProgressView(value: updateManager.downloadProgress, total: 1.0)
                                                    .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                                Text(updateManager.statusMessage)
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Button(action: {
                                                updateManager.downloadAndInstallUpdate()
                                                HapticManager.shared.click()
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                                    Text(String(localized: "settings.menu-bar.general.updates.update-relaunch.button", defaultValue: "Update & Relaunch", comment: "Primary action button title to update and relaunch app"))
                                                }
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                                .padding(.vertical, 6)
                                                .frame(maxWidth: .infinity)
                                                .background(Color(red: 0.22, green: 0.72, blue: 0.42))
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(red: 0.22, green: 0.72, blue: 0.42).opacity(0.12))
                                    .cornerRadius(8)
                                } else {
                                    VStack(alignment: .leading, spacing: 6) {
                                        if updateManager.isChecking {
                                            HStack(spacing: 6) {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                                    .frame(width: 12, height: 12)
                                                Text(String(localized: "settings.menu-bar.general.updates.checking-github", defaultValue: "Checking GitHub for updates...", comment: "Status text displayed while checking GitHub for updates"))
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    if let date = updateManager.lastCheckDate {
                                                        Text(updateManager.statusMessage.isEmpty ? String(localized: "settings.menu-bar.general.updates.up-to-date", defaultValue: "FrogDrop is up to date", comment: "Status text shown when app is already on latest version") : updateManager.statusMessage)
                                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                                            .foregroundColor(updateManager.errorMessage != nil ? .red : .secondary)
                                                        Text(String(format: String(localized: "settings.menu-bar.general.updates.last-checked", defaultValue: "Checked %@", comment: "Status text showing last update check time"), "\(date.formatted(date: .omitted, time: .shortened))"))
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.secondary.opacity(0.6))
                                                    } else {
                                                        Text(String(localized: "settings.menu-bar.general.updates.check-for-new-releases.title", defaultValue: "Check for new releases", comment: "Title text prompting user to check for new releases"))
                                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                                            .foregroundColor(.secondary)
                                                        Text(String(localized: "settings.menu-bar.general.updates.check-for-new-releases.subtitle", defaultValue: "Click button to query GitHub", comment: "Subtitle text explaining update check action against GitHub"))
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.secondary.opacity(0.5))
                                                    }
                                                }
                                                Spacer()
                                                Button(action: {
                                                    updateManager.checkForUpdates()
                                                    HapticManager.shared.click()
                                                }) {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "arrow.clockwise")
                                                            .font(.system(size: 9))
                                                        Text(String(localized: "settings.menu-bar.general.updates.check.button", defaultValue: "Check", comment: "Button title to manually check for updates"))
                                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    }
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.white.opacity(0.08))
                                                    .cornerRadius(5)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .transition(.opacity)
                    
                } else if selectedTab == 1 {
                    // Grid Folders & Actions
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "settings.menu-bar.grid.folders-apps.section-title", defaultValue: "FOLDERS & APPS", comment: "Section header for folders and apps configuration in grid tab"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ForEach(manager.customFolders) { folder in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue.opacity(0.8))
                                            .font(.system(size: 11))
                                        Text(folder.name)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Button(action: {
                                            manager.removeFolder(id: folder.id)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.7))
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                                
                                Button(action: {
                                    selectFolder()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text(String(localized: "settings.menu-bar.grid.folders-apps.add-folder.button", defaultValue: "Add Folder...", comment: "Button title to add a folder to grid settings"))
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "settings.menu-bar.grid.builtin-actions.section-title", defaultValue: "BUILT-IN ACTIONS", comment: "Section header for built-in grid actions"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.inspect-exif", defaultValue: "Inspect EXIF", comment: "Built-in action label for inspecting EXIF metadata"), actionType: "inspectEXIF")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.extract-text-ocr", defaultValue: "Extract Text (OCR)", comment: "Built-in action label for extracting text using OCR"), actionType: "ocr")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.convert-to-web-avif", defaultValue: "Convert to Web (AVIF)", comment: "Built-in action label for converting images to AVIF"), actionType: "webp")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.compress-image", defaultValue: "Compress Image", comment: "Built-in action label for image compression"), actionType: "compress")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.strip-exif-metadata", defaultValue: "Strip EXIF Metadata", comment: "Built-in action label for removing EXIF metadata"), actionType: "stripMetadata")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.merge-pdfs", defaultValue: "Merge PDFs", comment: "Built-in action label for merging PDF files"), actionType: "mergePDF")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.pick-screen-color", defaultValue: "Pick Screen Color", comment: "Built-in action label for picking a screen color"), actionType: "pickColor")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.airdrop", defaultValue: "AirDrop", comment: "Built-in action label for sharing via AirDrop"), actionType: "airdrop")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.email", defaultValue: "Email", comment: "Built-in action label for sharing via email"), actionType: "email")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.upload-to-imgur", defaultValue: "Upload to Imgur", comment: "Built-in action label for uploading to Imgur"), actionType: "imgur")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.shorten-url", defaultValue: "Shorten URL", comment: "Built-in action label for shortening URLs"), actionType: "shortenURL")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.zip-files", defaultValue: "Zip Files", comment: "Built-in action label for zipping files"), actionType: "zip")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.resize-image-800px", defaultValue: "Resize Image (800px)", comment: "Built-in action label for resizing image to 800 pixels"), actionType: "resizeImage")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.convert-to-png", defaultValue: "Convert to PNG", comment: "Built-in action label for converting to PNG format"), actionType: "convertImage")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.copy-path", defaultValue: "Copy Path", comment: "Built-in action label for copying file path"), actionType: "copyPath")
                                ToggleActionRow(title: String(localized: "settings.menu-bar.grid.builtin-actions.open-path", defaultValue: "Open Path", comment: "Built-in action label for opening file path"), actionType: "openPath")
                            }
                        }
                        .padding(16)
                    }
                    .transition(.opacity)
                } else {
                    // Application Rules
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "settings.menu-bar.rules.app-preferences.section-title", defaultValue: "APP PREFERENCES", comment: "Section header for app-specific preference rules"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ForEach(clipboardManager.customRules) { rule in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(rule.appName)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.primary)
                                            Text(rule.ruleType.rawValue.capitalized)
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(rule.ruleType == .temporary ? .orange : (rule.ruleType == .save ? .green : .red))
                                        }
                                        
                                        Spacer()
                                        
                                        Menu {
                                            Button(String(localized: "settings.menu-bar.rules.behavior.save-permanent", defaultValue: "Save (Permanent)", comment: "Rule behavior option to save items permanently")) {
                                                clipboardManager.updateRule(id: rule.id, newType: .save)
                                            }
                                            Button(String(localized: "settings.menu-bar.rules.behavior.temporary", defaultValue: "Temporary", comment: "Rule behavior option to keep items temporarily")) {
                                                clipboardManager.updateRule(id: rule.id, newType: .temporary)
                                            }
                                            Button(String(localized: "settings.menu-bar.rules.behavior.ignore-dont-save", defaultValue: "Ignore (Don't Save)", comment: "Rule behavior option to ignore items and not save them")) {
                                                clipboardManager.updateRule(id: rule.id, newType: .ignore)
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle.fill")
                                                .foregroundColor(.secondary.opacity(0.8))
                                                .font(.system(size: 14))
                                        }
                                        .menuStyle(.borderlessButton)
                                        .frame(width: 20)
                                        
                                        Button(action: {
                                            clipboardManager.removeRule(id: rule.id)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                                .font(.system(size: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.03))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(16)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        // Add rule block
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "settings.menu-bar.rules.add-new-preference.section-title", defaultValue: "ADD NEW PREFERENCE", comment: "Section header for creating a new app preference rule"))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 6) {
                                if !runningApps.isEmpty {
                                    Picker("", selection: $selectedRunningApp) {
                                        ForEach(runningApps, id: \.self) { app in
                                            Text(app).tag(app)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                } else {
                                    TextField(String(localized: "settings.menu-bar.rules.add-new-preference.app-name.placeholder", defaultValue: "App Name...", comment: "Placeholder text for entering app name when creating new preference"), text: $newRuleAppName)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, design: .rounded))
                                        .padding(5)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                
                                Picker("", selection: $newRuleType) {
                                    Text(String(localized: "settings.menu-bar.rules.add-new-preference.behavior.temp", defaultValue: "Temp", comment: "Short behavior option label for temporary save in new preference form")).tag(ClipboardPreferenceRule.RuleType.temporary)
                                    Text(String(localized: "settings.menu-bar.rules.add-new-preference.behavior.ignore", defaultValue: "Ignore", comment: "Short behavior option label for ignore action in new preference form")).tag(ClipboardPreferenceRule.RuleType.ignore)
                                }
                                .labelsHidden()
                                .frame(width: 60)
                                
                                Button(action: {
                                    let appToSave = runningApps.isEmpty ? newRuleAppName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedRunningApp
                                    if !appToSave.isEmpty {
                                        clipboardManager.addRule(appName: appToSave, ruleType: newRuleType)
                                        newRuleAppName = ""
                                        HapticManager.shared.success()
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.015))
                    }
                    .transition(.opacity)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            Button(String(localized: "settings.menu-bar.rules.add-new-preference.done.button", defaultValue: "Done", comment: "Button title to complete adding a new app preference")) {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.15, green: 0.85, blue: 0.45))
            .padding(.vertical, 8)
        }
        .frame(width: 260, height: 330)
        .background(Color.black.opacity(uiDimOpacity))
        .onAppear {
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { $0.localizedName }
                .filter { !$0.isEmpty }
            let uniqueApps = Array(Set(apps)).sorted()
            self.runningApps = uniqueApps
            if let first = uniqueApps.first {
                self.selectedRunningApp = first
            }
            isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                isLaunchAtLoginEnabled = true
            } catch {
                print("Failed to register Launch at Login: \(error)")
                isLaunchAtLoginEnabled = false
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                isLaunchAtLoginEnabled = false
            } catch {
                print("Failed to unregister Launch at Login: \(error)")
                isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
    
    // TabButton helper component
    struct TabButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary)
                    
                    Circle()
                        .fill(isSelected ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let folderName = url.lastPathComponent
            manager.addFolder(name: folderName, path: url.path)
        }
    }
}

struct ToggleActionRow: View {
    let title: String
    let actionType: String
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
            Spacer()
            Toggle("", isOn: Binding(
                get: { manager.enabledActions.contains(actionType) },
                set: { enabled in manager.toggleAction(actionType, enabled: enabled) }
            ))
            .toggleStyle(.switch)
        }
    }
}
