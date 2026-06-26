import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Enum for all available Dropzone action slots
enum DropzoneAction: String, CaseIterable {
    case shelf = "Drop Bar"
    case downloads = "Downloads"
    case airdrop = "AirDrop"
    case email = "Email"
    case copyPath = "Copy Path"
    case shortenURL = "Shorten URL"
}

@MainActor
class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    @Published var shelvedFiles: [URL] = []
    @Published var hoveredAction: DropzoneAction? = nil
    
    private init() {}
    
    func shelfFiles(_ urls: [URL]) {
        shelvedFiles.append(contentsOf: urls)
        HapticManager.shared.success()
    }
    
    func copyPaths(_ urls: [URL]) {
        let paths = urls.map { $0.path }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(paths, forType: .string)
        HapticManager.shared.success()
    }
    
    func moveToDownloads(_ urls: [URL]) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var count = 0
        for url in urls {
            let dest = downloads.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: url, to: dest)
                count += 1
            } catch {
                print("Failed to move file \(url.lastPathComponent) to Downloads: \(error)")
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
            // File URL, copy its shortened display name
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(url.lastPathComponent, forType: .string)
        }
    }
}

// Custom overlay view placed on top of all hosting views to intercept 100% of dragging events
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
        // Force the overlay to catch dragging updates and mouse events
        return self
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("[DropzoneDragOverlay] draggingEntered")
        onDragEntered?()
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHoveredAction(for: sender.draggingLocation)
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("[DropzoneDragOverlay] draggingExited")
        DropzoneManager.shared.hoveredAction = nil
        onDragExited?()
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        print("[DropzoneDragOverlay] draggingEnded")
        DropzoneManager.shared.hoveredAction = nil
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = sender.draggingLocation
        let localPoint = self.convert(location, from: nil)
        let action = getAction(at: localPoint)
        
        print("[DropzoneDragOverlay] performDragOperation: action = \(String(describing: action))")
        
        guard let action = action else { return false }
        
        let pasteboard = sender.draggingPasteboard
        
        // Extract URLs
        var urls: [URL] = []
        if let nsurls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls = nsurls
        }
        
        if urls.isEmpty {
            // Check legacy filenames
            if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? [String] {
                urls = filenames.map { URL(fileURLWithPath: $0) }
            }
        }
        
        guard !urls.isEmpty else { return false }
        
        DispatchQueue.main.async {
            switch action {
            case .shelf:
                DropzoneManager.shared.shelfFiles(urls)
            case .downloads:
                DropzoneManager.shared.moveToDownloads(urls)
            case .airdrop:
                DropzoneManager.shared.airdropFiles(urls)
            case .email:
                DropzoneManager.shared.emailFiles(urls)
            case .copyPath:
                DropzoneManager.shared.copyPaths(urls)
            case .shortenURL:
                DropzoneManager.shared.shortenURL(urls)
            }
        }
        
        return true
    }
    
    private func updateHoveredAction(for location: NSPoint) {
        let localPoint = self.convert(location, from: nil)
        let action = getAction(at: localPoint)
        if DropzoneManager.shared.hoveredAction != action {
            DropzoneManager.shared.hoveredAction = action
        }
    }
    
    private func getAction(at localPoint: NSPoint) -> DropzoneAction? {
        let x = localPoint.x
        let y = localPoint.y
        
        // Bounds check: Grid is active between y = 40 and y = 335
        guard y >= 40 && y <= 335 else { return nil }
        
        // Left Column (0...90) vs Right Column (90...180)
        let isLeft = x < 90
        
        if y > 230 {
            // Row 1 (Drop Bar / Downloads)
            return isLeft ? .shelf : .downloads
        } else if y > 138 {
            // Row 2 (AirDrop / Email)
            return isLeft ? .airdrop : .email
        } else {
            // Row 3 (Copy Path / Shorten URL)
            return isLeft ? .copyPath : .shortenURL
        }
    }
}

// Custom content view for standard hit testing
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
            y: statusItemFrame.minY - height - 2, // 2px below the menu bar
            width: width,
            height: height
        )
        print("[DropzonePanel] getCollapsedRect: \(rect)")
        return rect
    }
    
    private static func getExpandedRect(statusItemFrame: NSRect) -> NSRect {
        let width: CGFloat = 180
        let height: CGFloat = 380
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 2, // 2px below the menu bar
            width: width,
            height: height
        )
        print("[DropzonePanel] getExpandedRect: \(rect)")
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
        self.level = .statusBar // Float at status bar level (below dragging image)
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let contentView = DropzonePanelContentView()
        self.contentView = contentView
        
        // Setup Collapsed Hosting View
        collapsedHostingView.frame = contentView.bounds
        collapsedHostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(collapsedHostingView)
        
        // Setup Expanded Container
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
        
        // Setup Drag Overlay on top of everything!
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
        
        // Initial state
        collapsedHostingView.isHidden = false
        expandedContainer.isHidden = true
    }
    
    func slideIn() {
        print("[DropzonePanel] slideIn() called. Current isExpanded: \(isExpanded)")
        guard !isExpanded else { return }
        isExpanded = true
        self.hasShadow = true
        
        // Order window to the very front to ensure it intercepts drag updates
        self.orderFrontRegardless()
        
        // Hide collapsed view, show expanded container
        collapsedHostingView.isHidden = true
        expandedContainer.isHidden = false
        
        self.setFrame(Self.getExpandedRect(statusItemFrame: self.statusItemFrame), display: true)
        HapticManager.shared.tick()
    }
    
    func slideOut() {
        print("[DropzonePanel] slideOut() called. Current isExpanded: \(isExpanded)")
        guard isExpanded else { return }
        isExpanded = false
        self.hasShadow = false
        
        self.setFrame(Self.getCollapsedRect(statusItemFrame: self.statusItemFrame), display: true)
        self.collapsedHostingView.isHidden = false
        self.expandedContainer.isHidden = true
        
        // Hide the window completely after sliding out!
        self.orderOut(nil)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant Frog Logo and Title
            HStack(spacing: 4) {
                Image(systemName: "laurel.leading")
                    .font(.system(size: 8))
                    .foregroundColor(.green.opacity(0.8))
                Text("FROG DROP")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(1.0)
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 8))
                    .foregroundColor(.green.opacity(0.8))
            }
            .frame(height: 38)
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            
            // Group 1: Folders / Storage
            VStack(alignment: .leading, spacing: 4) {
                Text("FOLDERS & APPS")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                HStack(spacing: 8) {
                    DropzoneTargetView(title: "Drop Bar", icon: "square.and.arrow.down", isHovered: manager.hoveredAction == .shelf)
                    DropzoneTargetView(title: "Downloads", icon: "folder", isHovered: manager.hoveredAction == .downloads)
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 12)
            
            // Group 2: Actions
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIONS")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        DropzoneTargetView(title: "AirDrop", icon: "airplayaudio", isHovered: manager.hoveredAction == .airdrop)
                        DropzoneTargetView(title: "Email", icon: "envelope", isHovered: manager.hoveredAction == .email)
                    }
                    HStack(spacing: 8) {
                        DropzoneTargetView(title: "Copy Path", icon: "doc.on.doc", isHovered: manager.hoveredAction == .copyPath)
                        DropzoneTargetView(title: "Shorten URL", icon: "link", isHovered: manager.hoveredAction == .shortenURL)
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer()
        }
        .frame(width: 180, height: 380)
    }
}

struct DropzoneTargetView: View {
    let title: String
    let icon: String
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color.green.opacity(0.15) : Color.white.opacity(0.04))
                    .frame(width: 38, height: 38)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isHovered ? .green : .primary)
            }
            
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? .green : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.green.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }
}
