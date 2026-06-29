import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Struct representing a customizable Dropzone item
struct DropzoneItem: Identifiable, Codable, Equatable {
    var id = UUID()
    let type: String // "folder" or "action"
    let name: String
    var path: String? // for folders
    var actionType: String? // for actions: "airdrop", "email", "imgur", "shortenURL", "copyPath"
}

@MainActor
class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    @Published var shelvedFiles: [URL] = []
    @Published var hoveredActionKey: String? = nil
    @Published var customFolders: [DropzoneItem] = []
    @Published var enabledActions: [String] = ["airdrop", "email", "imgur", "shortenURL"]
    @Published var lastDropTime: Date? = nil
    @Published var registeredFrames: [String: NSRect] = [:]
    
    private let foldersKey = "frogdrop.customFolders"
    private let actionsKey = "frogdrop.enabledActions"
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([DropzoneItem].self, from: data) {
            self.customFolders = decoded
        } else {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            self.customFolders = [
                DropzoneItem(id: UUID(), type: "folder", name: "Downloads", path: downloadsURL.path)
            ]
        }
        
        if let actions = UserDefaults.standard.stringArray(forKey: actionsKey) {
            self.enabledActions = actions
        } else {
            self.enabledActions = ["airdrop", "email", "imgur", "shortenURL"]
        }
    }
    
    func saveSettings() {
        if let encoded = try? JSONEncoder().encode(customFolders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
        UserDefaults.standard.set(enabledActions, forKey: actionsKey)
    }
    
    func addFolder(name: String, path: String) {
        let newItem = DropzoneItem(id: UUID(), type: "folder", name: name, path: path)
        customFolders.append(newItem)
        saveSettings()
    }
    
    func removeFolder(id: UUID) {
        customFolders.removeAll(where: { $0.id == id })
        saveSettings()
    }
    
    func toggleAction(_ actionType: String, enabled: Bool) {
        if enabled {
            if !enabledActions.contains(actionType) {
                enabledActions.append(actionType)
            }
        } else {
            enabledActions.removeAll(where: { $0 == actionType })
        }
        saveSettings()
    }
    
    func registerFrame(_ rect: NSRect, for key: String) {
        registeredFrames[key] = rect
    }
    
    func clearFrames() {
        registeredFrames.removeAll()
    }
    
    func shelfFiles(_ urls: [URL]) {
        shelvedFiles.append(contentsOf: urls)
        lastDropTime = Date()
        HapticManager.shared.success()
    }
    
    func clearShelf() {
        shelvedFiles.removeAll()
        lastDropTime = nil
    }
    
    func deleteShelvedFile(at index: Int) {
        if index >= 0 && index < shelvedFiles.count {
            shelvedFiles.remove(at: index)
        }
        if shelvedFiles.isEmpty {
            lastDropTime = nil
        }
    }
    
    func handleDrop(urls: [URL], onKey key: String) {
        print("[DropzoneManager] handleDrop: key = \(key)")
        if key == "shelf" {
            shelfFiles(urls)
        } else if key.hasPrefix("folder_") {
            let path = String(key.dropFirst(7))
            moveToFolder(urls: urls, path: path)
        } else if key == "action_airdrop" {
            airdropFiles(urls)
        } else if key == "action_email" {
            emailFiles(urls)
        } else if key == "action_imgur" {
            uploadToImgur(urls)
        } else if key == "action_shortenURL" {
            shortenURL(urls)
        } else if key == "action_copyPath" {
            copyPaths(urls)
        }
    }
    
    // Actions implementation
    func copyPaths(_ urls: [URL]) {
        let paths = urls.map { $0.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(paths, forType: .string)
        HapticManager.shared.success()
    }
    
    func moveToFolder(urls: [URL], path: String) {
        let destFolder = URL(fileURLWithPath: path)
        var count = 0
        for url in urls {
            let dest = destFolder.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                count += 1
            } catch {
                print("Failed to copy file \(url.lastPathComponent) to \(path): \(error)")
            }
        }
        if count > 0 {
            HapticManager.shared.success()
        }
    }
    
    func airdropFiles(_ urls: [URL]) {
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .sendViaAirDrop)
        sharingService?.perform(withItems: urls)
    }
    
    func emailFiles(_ urls: [URL]) {
        HapticManager.shared.success()
        let sharingService = NSSharingService(named: .composeEmail)
        sharingService?.perform(withItems: urls)
    }
    
    func uploadToImgur(_ urls: [URL]) {
        HapticManager.shared.success()
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("https://imgur.com/mock_\(Int.random(in: 10000...99999))", forType: .string)
    }
    
    func shortenURL(_ urls: [URL]) {
        HapticManager.shared.success()
        guard let url = urls.first else { return }
        
        if url.scheme == "http" || url.scheme == "https" {
            let originalString = url.absoluteString
            let tinyURLString = "https://tinyurl.com/api-create?url=\(originalString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            
            guard let fetchURL = URL(string: tinyURLString) else { return }
            
            URLSession.shared.dataTask(with: fetchURL) { data, _, _ in
                if let data = data, let shortened = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    DispatchQueue.main.async {
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(shortened, forType: .string)
                        HapticManager.shared.success()
                    }
                }
            }
            .resume()
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(url.lastPathComponent, forType: .string)
        }
    }
}

class DropzoneDragOverlay: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDragTypes()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDragTypes()
    }
    
    private func registerDragTypes() {
        self.registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
            NSPasteboard.PasteboardType(rawValue: "public.file-url"),
            NSPasteboard.PasteboardType(rawValue: "public.url")
        ])
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        DropzoneManager.shared.hoveredActionKey = nil
        onDragExited?()
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        DropzoneManager.shared.hoveredActionKey = nil
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = sender.draggingLocation
        let localPoint = self.convert(location, from: nil)
        let key = getActionKey(at: localPoint)
        
        print("[DropzoneDragOverlay] performDragOperation: key = \(String(describing: key))")
        
        guard let key = key else { return false }
        
        let pasteboard = sender.draggingPasteboard
        var urls: [URL] = []
        if let nsurls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls = nsurls
        }
        
        if urls.isEmpty {
            if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String] {
                urls = filenames.map { URL(fileURLWithPath: $0) }
            }
        }
        
        guard !urls.isEmpty else { return false }
        
        DispatchQueue.main.async {
            DropzoneManager.shared.handleDrop(urls: urls, onKey: key)
        }
        
        return true
    }
    
    private func updateHoveredAction(for location: NSPoint) {
        let localPoint = self.convert(location, from: nil)
        let key = getActionKey(at: localPoint)
        if DropzoneManager.shared.hoveredActionKey != key {
            DropzoneManager.shared.hoveredActionKey = key
        }
    }
    
    private func getActionKey(at localPoint: NSPoint) -> String? {
        for (key, rect) in DropzoneManager.shared.registeredFrames {
            if rect.contains(localPoint) {
                return key
            }
        }
        return nil
    }
}

class DropzonePanelContentView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) {
            return hit
        }
        return self
    }
}

class DropzonePanelWindow: NSWindow {
    private var statusItemFrame: NSRect
    private let collapsedHostingView: NSHostingView<CollapsedPanelView>
    private let expandedContainer = NSView()
    private let expandedHostingView: NSHostingView<DropzonePanelView>
    private var isExpanded = false
    
    private static func getCollapsedRect(statusItemFrame: NSRect) -> NSRect {
        let width: CGFloat = 80
        let height: CGFloat = 28
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 2,
            width: width,
            height: height
        )
        return rect
    }
    
    private static func getExpandedRect(statusItemFrame: NSRect) -> NSRect {
        let width: CGFloat = 240
        let height: CGFloat = 380
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 2,
            width: width,
            height: height
        )
        return rect
    }
    
    init(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        self.collapsedHostingView = NSHostingView(rootView: CollapsedPanelView())
        self.expandedHostingView = NSHostingView(rootView: DropzonePanelView())
        
        super.init(
            contentRect: Self.getCollapsedRect(statusItemFrame: statusItemFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let contentView = DropzonePanelContentView()
        self.contentView = contentView
        
        collapsedHostingView.frame = contentView.bounds
        collapsedHostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(collapsedHostingView)
        
        expandedContainer.frame = contentView.bounds
        expandedContainer.autoresizingMask = [.width, .height]
        expandedContainer.wantsLayer = true
        expandedContainer.layer?.cornerRadius = 16
        expandedContainer.layer?.masksToBounds = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.frame = expandedContainer.bounds
        effectView.autoresizingMask = [.width, .height]
        
        expandedHostingView.frame = expandedContainer.bounds
        expandedHostingView.autoresizingMask = [.width, .height]
        
        expandedContainer.addSubview(effectView)
        expandedContainer.addSubview(expandedHostingView)
        contentView.addSubview(expandedContainer)
        
        let dragOverlay = DropzoneDragOverlay()
        dragOverlay.frame = contentView.bounds
        dragOverlay.autoresizingMask = [.width, .height]
        dragOverlay.onDragEntered = { [weak self] in
            self?.slideIn()
        }
        dragOverlay.onDragExited = { [weak self] in
            self?.slideOut()
        }
        contentView.addSubview(dragOverlay)
        
        collapsedHostingView.isHidden = false
        expandedContainer.isHidden = true
    }
    
    func slideIn() {
        guard !isExpanded else { return }
        isExpanded = true
        self.hasShadow = true
        self.orderFrontRegardless()
        
        collapsedHostingView.isHidden = true
        expandedContainer.isHidden = false
        
        let targetRect = Self.getExpandedRect(statusItemFrame: self.statusItemFrame)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 0.85, 0.35, 1.1)
            self.animator().setFrame(targetRect, display: true)
        }
        HapticManager.shared.tick()
    }
    
    func slideOut() {
        guard isExpanded else { return }
        isExpanded = false
        self.hasShadow = false
        
        let targetRect = Self.getCollapsedRect(statusItemFrame: self.statusItemFrame)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetRect, display: true)
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.collapsedHostingView.isHidden = false
            self.expandedContainer.isHidden = true
            self.orderOut(nil)
        }
    }
    
    func showCollapsedIndicator() {
        guard !isExpanded else { return }
        self.orderFrontRegardless()
    }
    
    func hideCollapsedIndicator() {
        guard !isExpanded else { return }
        self.orderOut(nil)
    }
    
    func updatePosition(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        let targetRect = isExpanded ? Self.getExpandedRect(statusItemFrame: statusItemFrame) : Self.getCollapsedRect(statusItemFrame: statusItemFrame)
        self.setFrame(targetRect, display: true)
    }
}

struct CollapsedPanelView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.green)
            Text("DROP")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(0.5)
        }
        .frame(width: 70, height: 20)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            Capsule()
                .stroke(Color.green.opacity(0.6), lineWidth: 1.0)
        )
        .shadow(color: Color.green.opacity(0.3), radius: 3)
        .frame(width: 80, height: 28)
    }
}

struct DropzonePanelView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isShowingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant Header bar
            HStack {
                Button(action: {
                    isShowingSettings = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isShowingSettings, arrowEdge: .top) {
                    DropzoneSettingsView()
                }
                
                Spacer()
                
                // Title
                Text("FROG DROP")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(1.0)
                
                Spacer()
                
                Button(action: {
                    isShowingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 38)
            .padding(.horizontal, 8)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            
            // Dropzone Grid (Dragging mode is true in the slide-in panel)
            ScrollView {
                DropzoneGrid(isDraggingMode: true, windowHeight: 380)
            }
        }
        .frame(width: 240, height: 380)
    }
}

struct DropzoneGrid: View {
    let isDraggingMode: Bool
    let windowHeight: CGFloat
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isShowingSettings = false
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Core Row: Add to Grid, Drop Bar, Shelved Files
            LazyVGrid(columns: columns, spacing: 12) {
                if isDraggingMode {
                    // Drop Bar
                    DropzoneCoreTargetView(
                        title: "Drop Bar",
                        icon: "arrow.down",
                        isHovered: manager.hoveredActionKey == "shelf",
                        isDashed: true
                    )
                    .background(FrameRegistrationHelper(key: "shelf", windowHeight: windowHeight))
                } else {
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
                    .background(FrameRegistrationHelper(key: "addGrid", windowHeight: windowHeight))
                }
                
                // Shelved Files
                ForEach(Array(manager.shelvedFiles.enumerated()), id: \.offset) { index, url in
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 32, height: 32)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                )
                            
                            if !isDraggingMode {
                                Button(action: {
                                    manager.deleteShelvedFile(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 12))
                                        .background(Circle().fill(Color.black))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                        
                        Text(url.lastPathComponent)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(width: 60)
                    }
                    .onDrag {
                        NSItemProvider(object: url as NSURL)
                    }
                }
            }
            .padding(.horizontal, 10)
            
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
                                isDraggingMode: isDraggingMode,
                                windowHeight: windowHeight
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
                    if manager.enabledActions.contains("airdrop") {
                        if isDraggingMode {
                            DropzoneTargetView(
                                title: "AirDrop",
                                icon: "antenna.radiowaves.left.and.right",
                                iconColor: .blue,
                                isHovered: manager.hoveredActionKey == "action_airdrop"
                            )
                            .background(FrameRegistrationHelper(key: "action_airdrop", windowHeight: windowHeight))
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_airdrop" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_airdrop" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_airdrop")
                            }
                        } else {
                            Button(action: {
                                if !manager.shelvedFiles.isEmpty {
                                    manager.handleDrop(urls: manager.shelvedFiles, onKey: "action_airdrop")
                                    manager.shelvedFiles.removeAll()
                                } else {
                                    selectFilesAndRun(actionKey: "action_airdrop")
                                }
                            }) {
                                DropzoneTargetView(
                                    title: "AirDrop",
                                    icon: "antenna.radiowaves.left.and.right",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == "action_airdrop"
                                )
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_airdrop" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_airdrop" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_airdrop")
                            }
                        }
                    }
                    
                    if manager.enabledActions.contains("email") {
                        if isDraggingMode {
                            DropzoneTargetView(
                                title: "Email",
                                icon: "envelope.fill",
                                iconColor: .blue,
                                isHovered: manager.hoveredActionKey == "action_email"
                            )
                            .background(FrameRegistrationHelper(key: "action_email", windowHeight: windowHeight))
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_email" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_email" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_email")
                            }
                        } else {
                            Button(action: {
                                if !manager.shelvedFiles.isEmpty {
                                    manager.handleDrop(urls: manager.shelvedFiles, onKey: "action_email")
                                    manager.shelvedFiles.removeAll()
                                } else {
                                    selectFilesAndRun(actionKey: "action_email")
                                }
                            }) {
                                DropzoneTargetView(
                                    title: "Email",
                                    icon: "envelope.fill",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == "action_email"
                                )
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_email" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_email" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_email")
                            }
                        }
                    }
                    
                    if manager.enabledActions.contains("imgur") {
                        if isDraggingMode {
                            DropzoneTargetView(
                                title: "Imgur",
                                icon: "photo.fill",
                                iconColor: .green,
                                isHovered: manager.hoveredActionKey == "action_imgur"
                            )
                            .background(FrameRegistrationHelper(key: "action_imgur", windowHeight: windowHeight))
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_imgur" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_imgur" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_imgur")
                            }
                        } else {
                            Button(action: {
                                if !manager.shelvedFiles.isEmpty {
                                    manager.handleDrop(urls: manager.shelvedFiles, onKey: "action_imgur")
                                    manager.shelvedFiles.removeAll()
                                } else {
                                    selectFilesAndRun(actionKey: "action_imgur")
                                }
                            }) {
                                DropzoneTargetView(
                                    title: "Imgur",
                                    icon: "photo.fill",
                                    iconColor: .green,
                                    isHovered: manager.hoveredActionKey == "action_imgur"
                                )
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_imgur" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_imgur" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_imgur")
                            }
                        }
                    }
                    
                    if manager.enabledActions.contains("shortenURL") {
                        if isDraggingMode {
                            DropzoneTargetView(
                                title: "Shorten URL",
                                icon: "link",
                                iconColor: .blue,
                                isHovered: manager.hoveredActionKey == "action_shortenURL"
                            )
                            .background(FrameRegistrationHelper(key: "action_shortenURL", windowHeight: windowHeight))
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_shortenURL" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_shortenURL" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_shortenURL")
                            }
                        } else {
                            Button(action: {
                                if !manager.shelvedFiles.isEmpty {
                                    manager.handleDrop(urls: manager.shelvedFiles, onKey: "action_shortenURL")
                                    manager.shelvedFiles.removeAll()
                                } else {
                                    selectFilesAndRun(actionKey: "action_shortenURL")
                                }
                            }) {
                                DropzoneTargetView(
                                    title: "Shorten URL",
                                    icon: "link",
                                    iconColor: .blue,
                                    isHovered: manager.hoveredActionKey == "action_shortenURL"
                                )
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_shortenURL" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_shortenURL" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_shortenURL")
                            }
                        }
                    }
                    
                    if manager.enabledActions.contains("copyPath") {
                        if isDraggingMode {
                            DropzoneTargetView(
                                title: "Copy Path",
                                icon: "doc.on.doc.fill",
                                iconColor: .purple,
                                isHovered: manager.hoveredActionKey == "action_copyPath"
                            )
                            .background(FrameRegistrationHelper(key: "action_copyPath", windowHeight: windowHeight))
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_copyPath" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_copyPath" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_copyPath")
                            }
                        } else {
                            Button(action: {
                                if !manager.shelvedFiles.isEmpty {
                                    manager.handleDrop(urls: manager.shelvedFiles, onKey: "action_copyPath")
                                    manager.shelvedFiles.removeAll()
                                } else {
                                    selectFilesAndRun(actionKey: "action_copyPath")
                                }
                            }) {
                                DropzoneTargetView(
                                    title: "Copy Path",
                                    icon: "doc.on.doc.fill",
                                    iconColor: .purple,
                                    isHovered: manager.hoveredActionKey == "action_copyPath"
                                )
                            }
                            .buttonStyle(.plain)
                            .onDrop(of: [.fileURL], isTargeted: Binding(
                                get: { manager.hoveredActionKey == "action_copyPath" },
                                set: { targeted in manager.hoveredActionKey = targeted ? "action_copyPath" : nil }
                            )) { providers in
                                handleSwiftUIDrop(providers: providers, onKey: "action_copyPath")
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
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
            _ = provider.loadObject(ofClass: NSURL.self) { object, error in
                if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                for url in urls {
                    if let idx = manager.shelvedFiles.firstIndex(where: { $0.path == url.path }) {
                        manager.shelvedFiles.remove(at: idx)
                    }
                }
                manager.handleDrop(urls: urls, onKey: onKey)
            }
            manager.hoveredActionKey = nil
        }
        return true
    }
}

struct CustomFolderCellView: View {
    let folder: DropzoneItem
    let isDraggingMode: Bool
    let windowHeight: CGFloat
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
            .background(FrameRegistrationHelper(key: key, windowHeight: windowHeight))
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
                    manager.shelvedFiles.removeAll()
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
                for url in urls {
                    if let idx = manager.shelvedFiles.firstIndex(where: { $0.path == url.path }) {
                        manager.shelvedFiles.remove(at: idx)
                    }
                }
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
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isHovered ? iconColor.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(isHovered ? iconColor.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isHovered ? iconColor : .primary)
            }
            
            Text(title)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? iconColor : .secondary)
                .lineLimit(1)
        }
        .frame(width: 60, height: 68)
    }
}

struct FrameRegistrationHelper: View {
    let key: String
    let windowHeight: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    register(geo: geo)
                }
                .onChange(of: geo.frame(in: .global)) { _ in
                    register(geo: geo)
                }
        }
    }
    
    private func register(geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let nsRect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        
        let appKitRect = NSRect(
            x: nsRect.origin.x,
            y: windowHeight - nsRect.origin.y - nsRect.size.height,
            width: nsRect.size.width,
            height: nsRect.size.height
        )
        
        DispatchQueue.main.async {
            DropzoneManager.shared.registerFrame(appKitRect, for: key)
        }
    }
}

struct DropzoneSettingsView: View {
    @ObservedObject var manager = DropzoneManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab = 0 // 0 = General, 1 = Grid, 2 = Rules
    @State private var newRuleAppName = ""
    @State private var newRuleType: ClipboardPreferenceRule.RuleType = .temporary
    @State private var runningApps: [String] = []
    @State private var selectedRunningApp = ""
    
    // Haptic level state
    @State private var hapticLevel: HapticManager.HapticLevel = HapticManager.shared.level
    
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
                    // General Options
                    VStack(alignment: .leading, spacing: 14) {
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
                                            .background(hapticLevel == val ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
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
                                .accentColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                                .onChange(of: clipboardManager.tempDuration) { _, _ in
                                    clipboardManager.saveSettings()
                                }
                            
                            Text("Auto-delete items copied from temporary applications.")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
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
                                
                                ToggleActionRow(title: "AirDrop", actionType: "airdrop")
                                ToggleActionRow(title: "Email", actionType: "email")
                                ToggleActionRow(title: "Imgur Upload", actionType: "imgur")
                                ToggleActionRow(title: "Shorten URL", actionType: "shortenURL")
                                ToggleActionRow(title: "Copy Path", actionType: "copyPath")
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
        .background(Color.black.opacity(0.85))
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
