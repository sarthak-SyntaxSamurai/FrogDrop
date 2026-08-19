import SwiftUI
import AppKit

struct DropzonePanelView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isShowingSettings = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Elegant Header bar
                HStack {
                    Spacer()
                    
                    // Title
                    Text(String(localized: "dropzone.grid.title", defaultValue: "FROG DROP", comment: "Primary title shown at top of dropzone grid view"))
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .tracking(1.2)
                    
                    Spacer()
                }
                .frame(height: 28)
                .padding(.horizontal, 8)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                
                // Dropzone Grid (Dragging mode is true in the slide-in panel)
                ScrollView(.vertical, showsIndicators: true) {
                    DropzoneGrid(isDraggingMode: true)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if manager.isShowingCombinePopover {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    }
                
                CombinePopoverView(
                    selectedIDs: $manager.selectedGroupIDs,
                    onCombine: {
                        manager.combineGroups(withIDs: manager.selectedGroupIDs)
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    },
                    onCancel: {
                        withAnimation {
                            manager.isShowingCombinePopover = false
                        }
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct DropzoneGrid: View {
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    
    let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    // Invisible buttons for keyboard shortcuts 1-9
                    ForEach(0..<min(manager.enabledActions.count, 9), id: \.self) { idx in
                        let actionKey = "action_" + manager.enabledActions[idx]
                        Button("") {
                            if !manager.shelvedFiles.isEmpty {
                                manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                manager.clearShelf()
                            } else {
                                selectFilesAndRun(actionKey: actionKey)
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(49 + idx)!)), modifiers: [])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                    }
                    
                    // Shelf Header (only shown when items are shelved)
                    if !manager.shelvedGroups.isEmpty {
                        HStack {
                            Text(String(format: String(
                                localized: "dropzone.grid.shelf.summary",
                                defaultValue: "SHELF (%#@groups@, %#@files@)",
                                comment: "Shelf summary showing counts of shelved groups and files"
                            ), manager.shelvedGroups.count, manager.shelvedGroups.count == 1 ? "group" : "groups"))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.7))
                            
                            Spacer()
                            
                            if manager.shelvedGroups.count > 1 {
                                Button(action: {
                                    manager.selectedGroupIDs = Set(manager.shelvedGroups.map { $0.id })
                                    withAnimation {
                                        manager.isShowingCombinePopover = true
                                    }
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "square.stack.3d.up")
                                            .font(.system(size: 8))
                                        Text(String(localized: "dropzone.grid.shelf.combine.button", defaultValue: "Combine", comment: "Button title to combine shelved items"))
                                            .font(.system(size: 8, weight: .semibold))
                                    }
                                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.12))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: { manager.clearShelf() }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                    Text(String(localized: "dropzone.grid.shelf.clear.button", defaultValue: "Clear", comment: "Button title to clear shelved items"))
                                        .font(.system(size: 8, weight: .semibold))
                                }
                                .foregroundColor(.red.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    }
                    
                    // Core Row: Add to Grid, Drop Bar, Shelved Files
                    if isDraggingMode {
                        // Wide Drop Bar spanning full width
                        DropzoneWideDropBarView(
                            title: String(localized: "dropzone.grid.shelf.drop-target", defaultValue: "Drop here to Shelve", comment: "Drop target hint text for shelving files"),
                            isHovered: manager.hoveredActionKey == "shelf"
                        )
                        .background(FrameRegistrationHelper(key: "shelf"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                        
                        if !manager.shelvedGroups.isEmpty {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(manager.shelvedGroups.enumerated()), id: \.element.id) { idx, group in
                                    ShelfGroupCard(group: group, groupIndex: idx, isDraggingMode: isDraggingMode)
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Add to Grid
                            Button(action: {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.prompt = String(localized: "dropzone.grid.add-folder.dialog.title", defaultValue: "Add to Grid", comment: "Dialog title for adding folder to dropzone grid")
                                panel.message = String(localized: "dropzone.grid.add-folder.dialog.message", defaultValue: "Choose a folder to add to your Dropzone grid", comment: "Dialog message prompting user to choose folder for dropzone grid")
                                if panel.runModal() == .OK, let url = panel.url {
                                    let newItem = DropzoneItem(type: "folder", name: url.lastPathComponent, path: url.path)
                                    manager.customFolders.append(newItem)
                                    manager.saveSettings()
                                    HapticManager.shared.success()
                                }
                            }) {
                                DropzoneCoreTargetView(
                                    title: String(localized: "dropzone.grid.add-folder.button", defaultValue: "Add to Grid", comment: "Button title to add selected folder to dropzone grid"),
                                    icon: "plus",
                                    isHovered: manager.hoveredActionKey == "addGrid",
                                    isDashed: true
                                )
                            }
                            .buttonStyle(.plain)
                            .background(FrameRegistrationHelper(key: "addGrid"))
                            
                            // Each ShelfGroup = one slot (single file or N Items fan card)
                            ForEach(Array(manager.shelvedGroups.enumerated()), id: \.element.id) { idx, group in
                                ShelfGroupCard(group: group, groupIndex: idx, isDraggingMode: isDraggingMode)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                
                // FOLDERS / APPS (Always shown, interactive when not dragging)
                if !manager.customFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "dropzone.grid.section.folders-apps", defaultValue: "FOLDERS / APPS", comment: "Section header for folders and apps in dropzone grid"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(manager.customFolders) { folder in
                                CustomFolderCellView(
                                    folder: folder,
                                    isDraggingMode: isDraggingMode
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                
                // ACTIONS (Always shown, interactive when not dragging)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "dropzone.grid.section.actions", defaultValue: "ACTIONS", comment: "Section header for action shortcuts in dropzone grid"))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                    
                    LazyVGrid(columns: columns, spacing: 6) {
                        if manager.enabledActions.contains("inspectEXIF") {
                            let actionKey = "action_inspectEXIF"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.inspect-exif.button", defaultValue: "Inspect EXIF", comment: "Action button title for inspecting EXIF metadata"),
                                    icon: "magnifyingglass.circle.fill",
                                    iconColor: .purple,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL, .image], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.inspect-exif.menu", defaultValue: "Inspect EXIF", comment: "Context menu item title for inspecting EXIF metadata"),
                                        icon: "magnifyingglass.circle.fill",
                                        iconColor: .purple,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL, .image], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("ocr") {
                            let actionKey = "action_ocr"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.extract-ocr.button", defaultValue: "Extract OCR", comment: "Action button title for extracting OCR text"),
                                    icon: "text.viewfinder",
                                    iconColor: .teal,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL, .image], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        Task {
                                            if let _ = await OCRManager.shared.extractTextFromClipboard() {
                                                manager.setProgress(.success(String(localized: "dropzone.grid.toast.copied-to-clipboard", defaultValue: "Copied to Clipboard!", comment: "Toast message shown after copying OCR result to clipboard")), for: actionKey)
                                            } else {
                                                selectFilesAndRun(actionKey: actionKey)
                                            }
                                        }
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.extract-ocr.menu", defaultValue: "Extract OCR", comment: "Context menu item title for extracting OCR text"),
                                        icon: "text.viewfinder",
                                        iconColor: .teal,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL, .image], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("webp") {
                            let actionKey = "action_webp"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.to-webp.button", defaultValue: "To WebP", comment: "Action button title for converting image to WebP"),
                                    icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.to-webp.menu", defaultValue: "To WebP", comment: "Context menu item title for converting image to WebP"),
                                        icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("compress") {
                            let actionKey = "action_compress"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.compress.button", defaultValue: "Compress", comment: "Action button title for compressing selected files"),
                                    icon: "arrow.down.right.and.arrow.up.left",
                                    iconColor: .orange,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.compress.menu", defaultValue: "Compress", comment: "Context menu item title for compress action"),
                                        icon: "arrow.down.right.and.arrow.up.left",
                                        iconColor: .orange,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("stripMetadata") {
                            let actionKey = "action_stripMetadata"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.strip-exif.button", defaultValue: "Strip EXIF", comment: "Action button title for stripping EXIF metadata"),
                                    icon: "shield.checkerboard",
                                    iconColor: .indigo,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.strip-exif.menu", defaultValue: "Strip EXIF", comment: "Context menu item title for stripping EXIF metadata"),
                                        icon: "shield.checkerboard",
                                        iconColor: .indigo,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("mergePDF") {
                            let actionKey = "action_mergePDF"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.merge-pdf.button", defaultValue: "Merge PDF", comment: "Action button title for merging PDF files"),
                                    icon: "doc.on.doc.fill",
                                    iconColor: .red,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.merge-pdf.menu", defaultValue: "Merge PDF", comment: "Context menu item title for merging PDF files"),
                                        icon: "doc.on.doc.fill",
                                        iconColor: .red,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("pickColor") {
                            let actionKey = "action_pickColor"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.pick-color.button", defaultValue: "Pick Color", comment: "Action button title for picking a screen color"),
                                    icon: "eyedropper.halffull",
                                    iconColor: .pink,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    Task {
                                        await manager.pickScreenColor()
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.pick-color.menu", defaultValue: "Pick Color", comment: "Context menu item title for picking a screen color"),
                                        icon: "eyedropper.halffull",
                                        iconColor: .pink,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if manager.enabledActions.contains("airdrop") {
                            let actionKey = "action_airdrop"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.airdrop.button", defaultValue: "AirDrop", comment: "Action button title for sharing via AirDrop"),
                                    icon: "antenna.radiowaves.left.and.right",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.airdrop.menu", defaultValue: "AirDrop", comment: "Context menu item title for sharing via AirDrop"),
                                        icon: "antenna.radiowaves.left.and.right",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("email") {
                            let actionKey = "action_email"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.email.button", defaultValue: "Email", comment: "Action button title for sharing via email"),
                                    icon: "envelope.fill",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.email.menu", defaultValue: "Email", comment: "Context menu item title for sharing via email"),
                                        icon: "envelope.fill",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("imgur") {
                            let actionKey = "action_imgur"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.imgur.button", defaultValue: "Imgur", comment: "Action button title for uploading to Imgur"),
                                    icon: "photo.fill",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.imgur.menu", defaultValue: "Imgur", comment: "Context menu item title for uploading to Imgur"),
                                        icon: "photo.fill",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("shortenURL") {
                            let actionKey = "action_shortenURL"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.shorten-url.button", defaultValue: "Shorten URL", comment: "Action button title for shortening URLs"),
                                    icon: "link",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else if let clipboardString = NSPasteboard.general.string(forType: .string),
                                              let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines) as String?,
                                              let url = URL(string: trimmed),
                                              url.scheme == "http" || url.scheme == "https" {
                                        Task {
                                            await manager.shortenURL([url])
                                        }
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.shorten-url.menu", defaultValue: "Shorten URL", comment: "Context menu item title for shortening URLs"),
                                        icon: "link",
                                        iconColor: .blue,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("zip") {
                            let actionKey = "action_zip"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.zip-files.button", defaultValue: "Zip Files", comment: "Action button title for creating a zip archive"),
                                    icon: "archivebox.fill",
                                    iconColor: .orange,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.zip-files.menu", defaultValue: "Zip Files", comment: "Context menu item title for creating a zip archive"),
                                        icon: "archivebox.fill",
                                        iconColor: .orange,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("resizeImage") {
                            let actionKey = "action_resizeImage"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.resize-image.button", defaultValue: "Resize Image", comment: "Action button title for resizing image files"),
                                    icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.resize-image.menu", defaultValue: "Resize Image", comment: "Context menu item title for resizing image files"),
                                        icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("convertImage") {
                            let actionKey = "action_convertImage"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.convert-to-png.button", defaultValue: "Convert to PNG", comment: "Action button title for converting files to PNG format"),
                                    icon: "photo.on.rectangle.angled",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.convert-to-png.menu", defaultValue: "Convert to PNG", comment: "Context menu item title for converting files to PNG format"),
                                        icon: "photo.on.rectangle.angled",
                                        iconColor: .green,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("copyPath") {
                            let actionKey = "action_copyPath"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.copy-path.button", defaultValue: "Copy Path", comment: "Action button title for copying selected file path"),
                                    icon: "doc.on.doc.fill",
                                    iconColor: .purple,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        selectFilesAndRun(actionKey: actionKey)
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.copy-path.menu", defaultValue: "Copy Path", comment: "Context menu item title for copying selected file path"),
                                        icon: "doc.on.doc.fill",
                                        iconColor: .purple,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                        
                        if manager.enabledActions.contains("openPath") {
                            let actionKey = "action_openPath"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: String(localized: "dropzone.grid.action.open-path.button", defaultValue: "Open Path", comment: "Action button title for opening selected file path"),
                                    icon: "arrow.up.right.square",
                                    iconColor: .orange,
                                    isHovered: manager.hoveredActionKey == actionKey,
                                    actionKey: actionKey
                                )
                                .background(FrameRegistrationHelper(key: actionKey))
                                .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            } else {
                                Button(action: {
                                    if !manager.shelvedFiles.isEmpty {
                                        manager.handleDrop(urls: manager.shelvedFiles, onKey: actionKey)
                                        manager.clearShelf()
                                    } else {
                                        manager.openPathFromClipboard()
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: String(localized: "dropzone.grid.action.open-path.menu", defaultValue: "Open Path", comment: "Context menu item title for opening selected file path"),
                                        icon: "arrow.up.right.square",
                                        iconColor: .orange,
                                        isHovered: manager.hoveredActionKey == actionKey,
                                        actionKey: actionKey
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL, .url, .utf8PlainText], isTargeted: Binding(
                                    get: { manager.hoveredActionKey == actionKey },
                                    set: { targeted in manager.hoveredActionKey = targeted ? actionKey : nil }
                                )) { providers in
                                    handleSwiftUIDrop(providers: providers, onKey: actionKey)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
    }

    private func selectFilesAndRun(actionKey: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "dropzone.grid.run-action.dialog.title", defaultValue: "Run Action", comment: "Dialog title for executing a selected action")
        panel.message = String(localized: "dropzone.grid.run-action.dialog.message", defaultValue: "Select files or folders to run this action", comment: "Dialog message prompting user to select input items before running action")
        
        let response = panel.runModal()
        if response == .OK {
            manager.handleDrop(urls: panel.urls, onKey: actionKey)
        }
    }

    private func handleSwiftUIDrop(providers: [NSItemProvider], onKey: String) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                    if let nsUrl = object as? NSURL {
                        let url = nsUrl as URL
                        urls.append(url)
                    }
                    group.leave()
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { object, error in
                    if let str = object,
                       let url = URL(string: str.trimmingCharacters(in: .whitespacesAndNewlines)),
                       url.scheme == "http" || url.scheme == "https" {
                        urls.append(url)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                manager.shelvedGroups.removeAll(where: { group in group.files.contains(where: { f in urls.contains(where: { $0.path == f.path }) }) })
                manager.handleDrop(urls: urls, onKey: onKey)
            }
            manager.hoveredActionKey = nil
        }
        return true
    }
}

struct ShelfGroupCard: View {
    let group: ShelfGroup
    let groupIndex: Int
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if group.files.count == 1, let url = group.files.first {
                    singleCard(url: url)
                } else {
                    fanCard()
                }
                if !isDraggingMode {
                    Button(action: { manager.deleteShelfGroup(at: groupIndex) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .background(Circle().fill(Color.black))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -4)
                }
            }
            if group.files.count == 1, let url = group.files.first {
                Text(url.lastPathComponent)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 62)
            } else {
                Text(String(format: String(localized: "dropzone.grid.shelf.group-item-count", defaultValue: "%d Items", comment: "Shelf group label showing number of files in the group"), group.files.count))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                    .frame(width: 62)
            }
        }
        .onTapGesture(count: 2) {
            QuickLookManager.shared.togglePreview(urls: group.files)
        }
        .overlay(CardDragTrackerView(group: group))
        .contextMenu {
            Button(String(localized: "dropzone.grid.shelf.context.quicklook-preview", defaultValue: "QuickLook Preview", comment: "Context menu item for opening QuickLook preview")) {
                QuickLookManager.shared.togglePreview(urls: group.files)
            }
            if group.files.count == 1, let url = group.files.first {
                Button(String(localized: "dropzone.grid.shelf.context.reveal-in-finder", defaultValue: "Reveal in Finder", comment: "Context menu item for revealing file in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button(String(localized: "dropzone.grid.shelf.context.copy-path", defaultValue: "Copy Path", comment: "Context menu item for copying file path from shelf")) {
                    NSPasteboard.general.declareTypes([.string], owner: nil)
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button(String(localized: "dropzone.grid.shelf.context.open", defaultValue: "Open", comment: "Context menu item for opening selected shelf file")) { NSWorkspace.shared.open(url) }
                Divider()
                Button(String(localized: "dropzone.grid.shelf.context.move-to-trash", defaultValue: "Move to Trash", comment: "Context menu item for moving selected shelf file to trash")) {
                    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    manager.deleteShelfGroup(at: groupIndex)
                }
            }
            Divider()
            ForEach(manager.enabledActions, id: \.self) { action in
                Button(actionDisplayName(action)) {
                    manager.handleDrop(urls: group.files, onKey: "action_\(action)")
                    manager.deleteShelfGroup(at: groupIndex)
                }
            }
            Divider()
            Button(String(localized: "dropzone.grid.shelf.context.remove-from-shelf", defaultValue: "Remove from Shelf", comment: "Context menu item for removing item from shelf without deleting file")) { manager.deleteShelfGroup(at: groupIndex) }
            if manager.shelvedGroups.count > 1 {
                Divider()
                Button(String(localized: "dropzone.grid.shelf.context.combine-with-others", defaultValue: "Combine with Others", comment: "Context menu item for combining selected shelf group with others")) { manager.combineAllGroups() }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
            var urls: [URL] = []
            let dispatchGroup = DispatchGroup()
            for provider in providers {
                dispatchGroup.enter()
                _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                    if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                        urls.append(url)
                    }
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.wait()
            guard !urls.isEmpty else { return false }
            
            DispatchQueue.main.async {
                manager.combineFiles(urls, intoGroupAt: groupIndex)
            }
            return true
        }
    }

    @ViewBuilder
    private func singleCard(url: URL) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.06))
            .frame(width: 54, height: 54)
            .overlay(
                Group {
                    if let img = group.thumbnails[url] {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable().aspectRatio(contentMode: .fit).frame(width: 34, height: 34)
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
    }

    @ViewBuilder
    private func fanCard() -> some View {
        let showing = min(3, group.files.count)
        ZStack {
            ForEach(0..<showing, id: \.self) { i in
                let url = group.files[i]
                let angle = Double(i - 1) * 12.0
                let xOff = CGFloat(i - 1) * 7
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.12, green: 0.18, blue: 0.14))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Group {
                            if let img = group.thumbnails[url] {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                            }
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.4), lineWidth: 0.8))
                    .rotationEffect(.degrees(angle))
                    .offset(x: xOff)
                    .zIndex(Double(i))
            }
        }
        .frame(width: 66, height: 54)
    }
}

struct CustomFolderCellView: View {
    let folder: DropzoneItem
    let isDraggingMode: Bool
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        let path = folder.path ?? ""
        let key = "folder_\(path)"
        
        if isDraggingMode {
            DropzoneTargetView(
                title: folder.name,
                icon: "folder.fill",
                iconColor: .blue,
                isHovered: manager.hoveredActionKey == key
            )
            .background(FrameRegistrationHelper(key: key))
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { manager.hoveredActionKey == key },
                set: { targeted in manager.hoveredActionKey = targeted ? key : nil }
            )) { providers in
                handleSwiftUIDrop(providers: providers, onKey: key)
            }
        } else {
            Button(action: {
                if !manager.shelvedFiles.isEmpty {
                    manager.handleDrop(urls: manager.shelvedFiles, onKey: key)
                    manager.clearShelf()
                } else {
                    if !path.isEmpty {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                }
            }) {
                DropzoneTargetView(
                    title: folder.name,
                    icon: "folder.fill",
                    iconColor: .blue,
                    isHovered: manager.hoveredActionKey == key
                )
            }
            .buttonStyle(.plain)
            .onDrop(of: [.fileURL], isTargeted: Binding(
                get: { manager.hoveredActionKey == key },
                set: { targeted in manager.hoveredActionKey = targeted ? key : nil }
            )) { providers in
                handleSwiftUIDrop(providers: providers, onKey: key)
            }
        }
    }
    
    private func handleSwiftUIDrop(providers: [NSItemProvider], onKey: String) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                manager.shelvedGroups.removeAll(where: { group in group.files.contains(where: { f in urls.contains(where: { $0.path == f.path }) }) })
                manager.handleDrop(urls: urls, onKey: onKey)
            }
            manager.hoveredActionKey = nil
        }
        return true
    }
}

struct DropzoneCoreTargetView: View {
    let title: String
    let icon: String
    let isHovered: Bool
    let isDashed: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isDashed {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isHovered ? Color.green : Color.white.opacity(0.18),
                            style: StrokeStyle(lineWidth: isHovered ? 1.5 : 1, dash: [4, 4])
                        )
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(12)
                        .frame(width: 50, height: 50)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovered ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isHovered ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 0.8)
                        )
                }
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isHovered ? .green : .primary)
            }
            
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? .green : .secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 68)
    }
}

struct DropzoneTargetView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isHovered: Bool
    var actionKey: String? = nil
    
    @ObservedObject var manager = DropzoneManager.shared
    
    var body: some View {
        let progressState = actionKey.flatMap { manager.actionProgress[$0] } ?? .idle
        
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(isHovered ? iconColor.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Circle()
                            .stroke(isHovered ? iconColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                    )
                
                switch progressState {
                case .idle:
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isHovered ? iconColor : .primary)
                case .running:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            
            let displayTitle: String = {
                switch progressState {
                case .idle:
                    return title
                case .running(let msg):
                    return msg
                case .success(let msg):
                    return msg
                case .failure(let msg):
                    return msg
                }
            }()
            
            Text(displayTitle)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? iconColor : .secondary)
                .lineLimit(1)
        }
        .frame(width: 62, height: 58)
    }
}

struct CombinePopoverView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @Binding var selectedIDs: Set<UUID>
    var onCombine: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "dropzone.grid.combine-groups.title", defaultValue: "COMBINE GROUPS", comment: "Title for sheet that combines multiple shelf groups"))
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 4)
            
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(manager.shelvedGroups) { group in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedIDs.contains(group.id) },
                                set: { selected in
                                    if selected {
                                        selectedIDs.insert(group.id)
                                    } else {
                                        selectedIDs.remove(group.id)
                                    }
                                }
                            )) {
                                HStack(spacing: 4) {
                                    if let firstURL = group.files.first {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue)
                                        Text(firstURL.lastPathComponent)
                                            .font(.system(size: 9, weight: .medium))
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                    }
                                    if group.files.count > 1 {
                                        Text(String(format: String(localized: "dropzone.grid.combine-groups.additional-files-count", defaultValue: "(+%d)", comment: "Compact count badge showing additional files in group beyond the first"), group.files.count - 1))
                                            .font(.system(size: 7))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxHeight: 120)
            
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text(String(localized: "dropzone.grid.combine-groups.cancel", defaultValue: "Cancel", comment: "Cancel button title in combine groups sheet"))
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onCombine) {
                    Text(String(localized: "dropzone.grid.combine-groups.confirm", defaultValue: "Combine", comment: "Confirmation button title in combine groups sheet"))
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .foregroundColor(.black)
                        .background(Color.green)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(selectedIDs.count < 2)
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(Color.clear)
    }
}

struct DropzoneWideDropBarView: View {
    let title: String
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isHovered ? .green : .primary)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.green.opacity(0.12) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? Color.green : Color.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: isHovered ? 1.5 : 1, dash: [4, 4])
                )
        )
        .shadow(color: isHovered ? Color.green.opacity(0.1) : Color.clear, radius: 4)
    }
}

func actionDisplayName(_ key: String) -> String {
    switch key {
    case "inspectEXIF": return String(localized: "dropzone.grid.inspect-exif.sheet.title", defaultValue: "Inspect EXIF Metadata", comment: "Title for sheet displaying EXIF metadata details")
    case "ocr": return String(localized: "dropzone.grid.inspect-exif.metadata.extract-text-ocr", defaultValue: "Extract Text (OCR)", comment: "Metadata row label for OCR text extraction action")
    case "webp": return String(localized: "dropzone.grid.inspect-exif.metadata.convert-to-web-avif", defaultValue: "Convert to Web (AVIF)", comment: "Metadata row label for conversion to AVIF action")
    case "compress": return String(localized: "dropzone.grid.inspect-exif.metadata.compress-image", defaultValue: "Compress Image", comment: "Metadata row label for image compression action")
    case "stripMetadata": return String(localized: "dropzone.grid.inspect-exif.metadata.strip-exif-metadata", defaultValue: "Strip EXIF Metadata", comment: "Metadata row label for removing EXIF metadata action")
    case "mergePDF": return String(localized: "dropzone.grid.inspect-exif.metadata.merge-into-pdf", defaultValue: "Merge into PDF", comment: "Metadata row label for merge into PDF action")
    case "pickColor": return String(localized: "dropzone.grid.inspect-exif.metadata.pick-screen-color", defaultValue: "Pick Screen Color", comment: "Metadata row label for screen color picker action")
    case "airdrop": return String(localized: "dropzone.grid.inspect-exif.metadata.airdrop", defaultValue: "AirDrop", comment: "Metadata row label for AirDrop share action")
    case "email": return String(localized: "dropzone.grid.inspect-exif.metadata.email", defaultValue: "Email", comment: "Metadata row label for email share action")
    case "imgur": return String(localized: "dropzone.grid.inspect-exif.metadata.upload-to-imgur", defaultValue: "Upload to Imgur", comment: "Metadata row label for Imgur upload action")
    case "shortenURL": return String(localized: "dropzone.grid.inspect-exif.metadata.shorten-url", defaultValue: "Shorten URL", comment: "Metadata row label for URL shortening action")
    case "zip": return String(localized: "dropzone.grid.inspect-exif.metadata.zip-files", defaultValue: "Zip Files", comment: "Metadata row label for zip files action")
    case "resizeImage": return String(localized: "dropzone.grid.inspect-exif.metadata.resize-image-800px", defaultValue: "Resize Image (800px)", comment: "Metadata row label for image resize to 800 pixels action")
    case "convertImage": return String(localized: "dropzone.grid.inspect-exif.metadata.convert-to-png", defaultValue: "Convert to PNG", comment: "Metadata row label for conversion to PNG action")
    case "copyPath": return String(localized: "dropzone.grid.inspect-exif.metadata.copy-path", defaultValue: "Copy Path", comment: "Metadata row label for copy path action")
    case "openPath": return String(localized: "dropzone.grid.inspect-exif.metadata.open-path", defaultValue: "Open Path", comment: "Metadata row label for open path action")
    default: return key.capitalized
    }
}
