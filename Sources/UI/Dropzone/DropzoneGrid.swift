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
                    Text("FROG DROP")
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
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 260, height: 600)
            
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
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
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
                            Text("SHELF (\(manager.shelvedGroups.count) group\(manager.shelvedGroups.count == 1 ? "" : "s"), \(manager.shelvedFiles.count) file\(manager.shelvedFiles.count == 1 ? "" : "s"))")
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
                                        Text("Combine")
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
                                    Text("Clear")
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
                            title: "Drop here to Shelve",
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
                                panel.prompt = "Add to Grid"
                                panel.message = "Choose a folder to add to your Dropzone grid"
                                if panel.runModal() == .OK, let url = panel.url {
                                    let newItem = DropzoneItem(type: "folder", name: url.lastPathComponent, path: url.path)
                                    manager.customFolders.append(newItem)
                                    manager.saveSettings()
                                    HapticManager.shared.success()
                                }
                            }) {
                                DropzoneCoreTargetView(
                                    title: "Add to Grid",
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
                        Text("FOLDERS / APPS")
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
                    Text("ACTIONS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        if manager.enabledActions.contains("inspectEXIF") {
                            let actionKey = "action_inspectEXIF"
                            if isDraggingMode {
                                DropzoneTargetView(
                                    title: "Inspect EXIF",
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
                                        title: "Inspect EXIF",
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
                                    title: "Extract OCR",
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
                                                manager.setProgress(.success("Copied to Clipboard!"), for: actionKey)
                                            } else {
                                                selectFilesAndRun(actionKey: actionKey)
                                            }
                                        }
                                    }
                                }) {
                                    DropzoneTargetView(
                                        title: "Extract OCR",
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
                                    title: "To WebP",
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
                                        title: "To WebP",
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
                                    title: "Compress",
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
                                        title: "Compress",
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
                                    title: "Strip EXIF",
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
                                        title: "Strip EXIF",
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
                                    title: "Merge PDF",
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
                                        title: "Merge PDF",
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
                                    title: "Pick Color",
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
                                        title: "Pick Color",
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
                                    title: "AirDrop",
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
                                        title: "AirDrop",
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
                                    title: "Email",
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
                                        title: "Email",
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
                                    title: "Imgur",
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
                                        title: "Imgur",
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
                                    title: "Shorten URL",
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
                                        title: "Shorten URL",
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
                                    title: "Zip Files",
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
                                        title: "Zip Files",
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
                                    title: "Resize Image",
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
                                        title: "Resize Image",
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
                                    title: "Convert to PNG",
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
                                        title: "Convert to PNG",
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
                                    title: "Copy Path",
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
                                        title: "Copy Path",
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
                                    title: "Open Path",
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
                                        title: "Open Path",
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
        panel.prompt = "Run Action"
        panel.message = "Select files or folders to run this action"
        
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
                Text("\(group.files.count) Items")
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
            Button("QuickLook Preview") {
                QuickLookManager.shared.togglePreview(urls: group.files)
            }
            if group.files.count == 1, let url = group.files.first {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("Copy Path") {
                    NSPasteboard.general.declareTypes([.string], owner: nil)
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button("Open") { NSWorkspace.shared.open(url) }
                Divider()
                Button("Move to Trash") {
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
            Button("Remove from Shelf") { manager.deleteShelfGroup(at: groupIndex) }
            if manager.shelvedGroups.count > 1 {
                Divider()
                Button("Combine with Others") { manager.combineAllGroups() }
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
        
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isHovered ? iconColor.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(isHovered ? iconColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                    )
                
                switch progressState {
                case .idle:
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isHovered ? iconColor : .primary)
                case .running:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .bold))
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
        .frame(width: 60, height: 68)
    }
}

struct CombinePopoverView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @Binding var selectedIDs: Set<UUID>
    var onCombine: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMBINE GROUPS")
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
                                        Text("(+\(group.files.count - 1))")
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
                    Text("Cancel")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: onCombine) {
                    Text("Combine")
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
    case "inspectEXIF": return "Inspect EXIF Metadata"
    case "ocr": return "Extract Text (OCR)"
    case "webp": return "Convert to Web (AVIF)"
    case "compress": return "Compress Image"
    case "stripMetadata": return "Strip EXIF Metadata"
    case "mergePDF": return "Merge into PDF"
    case "pickColor": return "Pick Screen Color"
    case "airdrop": return "AirDrop"
    case "email": return "Email"
    case "imgur": return "Upload to Imgur"
    case "shortenURL": return "Shorten URL"
    case "zip": return "Zip Files"
    case "resizeImage": return "Resize Image (800px)"
    case "convertImage": return "Convert to PNG"
    case "copyPath": return "Copy Path"
    case "openPath": return "Open Path"
    default: return key.capitalized
    }
}
