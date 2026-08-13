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
                TabButton(title: "General", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 0
                    }
                }
                TabButton(title: "Grid", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
                TabButton(title: "Rules", isSelected: selectedTab == 2) {
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
                                Text("MENU BAR ICON")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                HStack(spacing: 4) {
                                    let options = [
                                        ("frog", "Frog", "face.smiling"),
                                        ("minimal", "Minimal", "square.and.arrow.down.fill"),
                                        ("custom", "Custom", "photo")
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
                                        Button("Choose Image...", action: selectCustomImage)
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
                                Text("HAPTICS")
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
                                    Text("KEEP HISTORY")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Picker("", selection: $clipboardRetentionDays) {
                                        Text("Forever").tag(0)
                                        Text("1 Day").tag(1)
                                        Text("7 Days").tag(7)
                                        Text("14 Days").tag(14)
                                        Text("30 Days").tag(30)
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
                                    Text("SHORTEN URL")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Toggle("Auto", isOn: $autoCleanURLs)
                                        .toggleStyle(.checkbox)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("TEMP EXPIRATION")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .tracking(1.0)
                                    Spacer()
                                    Text("\(Int(clipboardManager.tempDuration))s")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.orange)
                                }
                                
                                Slider(value: $clipboardManager.tempDuration, in: 15...120, step: 5)
                                    .accentColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                    .onChange(of: clipboardManager.tempDuration) { _, _ in
                                        clipboardManager.saveSettings()
                                    }
                                
                                Text("Auto-delete items copied from temporary applications.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("STARTUP")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                Toggle(isOn: Binding(
                                    get: { isLaunchAtLoginEnabled },
                                    set: { newValue in
                                        toggleLaunchAtLogin(newValue)
                                    }
                                )) {
                                    Text("Launch automatically at login")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                .toggleStyle(.checkbox)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("APPEARANCE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                Text("Popup darkness")
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
                                
                                Text(uiDimOpacity < 0.15 ? "Glass (Fully Transparent)" : uiDimOpacity < 0.45 ? "Light" : uiDimOpacity < 0.75 ? "Medium" : "Dark")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 0.22, green: 0.72, blue: 0.42))
                                
                                Divider()
                                    .background(Color.white.opacity(0.04))
                                    .padding(.vertical, 4)
                                
                                Text("Popup window style")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Button(action: {
                                        popupStyle = "popover"
                                        HapticManager.shared.click()
                                    }) {
                                        Text("Popover")
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
                                        Text("Panel (WiFi)")
                                            .font(.system(size: 10, weight: popupStyle == "panel" ? .bold : .medium, design: .rounded))
                                            .foregroundColor(popupStyle == "panel" ? .black : .primary)
                                            .padding(.vertical, 5)
                                            .frame(maxWidth: .infinity)
                                            .background(popupStyle == "panel" ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(popupStyle == "popover" ? "Classic popover with pointer arrow." : "Floating window style like WiFi/Battery menus.")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.06))
                            
                            // FrogDrop Updates Section (General Tab Bottom)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("UPDATES")
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
                                            Text("\(updateManager.latestVersion) Available!")
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
                                                    Text("Update & Relaunch")
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
                                                Text("Checking GitHub for updates...")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    if let date = updateManager.lastCheckDate {
                                                        Text(updateManager.statusMessage.isEmpty ? "FrogDrop is up to date" : updateManager.statusMessage)
                                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                                            .foregroundColor(updateManager.errorMessage != nil ? .red : .secondary)
                                                        Text("Checked \(date.formatted(date: .omitted, time: .shortened))")
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.secondary.opacity(0.6))
                                                    } else {
                                                        Text("Check for new releases")
                                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                                            .foregroundColor(.secondary)
                                                        Text("Click button to query GitHub")
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
                                                        Text("Check")
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
                                Text("FOLDERS & APPS")
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
                                        Text("Add Folder...")
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
                                Text("BUILT-IN ACTIONS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1.0)
                                
                                ToggleActionRow(title: "Inspect EXIF", actionType: "inspectEXIF")
                                ToggleActionRow(title: "Extract Text (OCR)", actionType: "ocr")
                                ToggleActionRow(title: "Convert to Web (AVIF)", actionType: "webp")
                                ToggleActionRow(title: "Compress Image", actionType: "compress")
                                ToggleActionRow(title: "Strip EXIF Metadata", actionType: "stripMetadata")
                                ToggleActionRow(title: "Merge PDFs", actionType: "mergePDF")
                                ToggleActionRow(title: "Pick Screen Color", actionType: "pickColor")
                                ToggleActionRow(title: "AirDrop", actionType: "airdrop")
                                ToggleActionRow(title: "Email", actionType: "email")
                                ToggleActionRow(title: "Upload to Imgur", actionType: "imgur")
                                ToggleActionRow(title: "Shorten URL", actionType: "shortenURL")
                                ToggleActionRow(title: "Zip Files", actionType: "zip")
                                ToggleActionRow(title: "Resize Image (800px)", actionType: "resizeImage")
                                ToggleActionRow(title: "Convert to PNG", actionType: "convertImage")
                                ToggleActionRow(title: "Copy Path", actionType: "copyPath")
                                ToggleActionRow(title: "Open Path", actionType: "openPath")
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
                                Text("APP PREFERENCES")
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
                                            Button("Save (Permanent)") {
                                                clipboardManager.updateRule(id: rule.id, newType: .save)
                                            }
                                            Button("Temporary") {
                                                clipboardManager.updateRule(id: rule.id, newType: .temporary)
                                            }
                                            Button("Ignore (Don't Save)") {
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
                            Text("ADD NEW PREFERENCE")
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
                                    TextField("App Name...", text: $newRuleAppName)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, design: .rounded))
                                        .padding(5)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                
                                Picker("", selection: $newRuleType) {
                                    Text("Temp").tag(ClipboardPreferenceRule.RuleType.temporary)
                                    Text("Ignore").tag(ClipboardPreferenceRule.RuleType.ignore)
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
            
            Button("Done") {
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
