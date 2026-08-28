import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FloatingShelfManager

@MainActor
class FloatingShelfManager: ObservableObject {
    static let shared = FloatingShelfManager()
    
    @Published var activeShelves: [FloatingShelfWindow] = []
    @Published var shelfFiles: [URL] = []
    @Published var thumbnails: [URL: NSImage] = [:]
    @Published var currentShelfGroupId: UUID? = nil
    
    func spawnShelf(at screenPoint: NSPoint) {
        // Reset session on new spawn
        currentShelfGroupId = nil
        shelfFiles.removeAll()
        thumbnails.removeAll()
        
        let shelf = FloatingShelfWindow(position: screenPoint)
        activeShelves.append(shelf)
        shelf.makeKeyAndOrderFront(nil)
        HapticManager.shared.success()
    }
    
    func removeShelf(_ shelf: FloatingShelfWindow) {
        shelf.orderOut(nil)
        activeShelves.removeAll(where: { $0 === shelf })
        
        // Clear shelf session
        currentShelfGroupId = nil
        shelfFiles.removeAll()
        thumbnails.removeAll()
    }
    
    func addFilesToShelf(_ urls: [URL]) {
        let uniqueNewUrls = urls.filter { !shelfFiles.contains($0) }
        shelfFiles.append(contentsOf: uniqueNewUrls)
        
        let manager = DropzoneManager.shared
        
        if let groupId = currentShelfGroupId,
           let existingGroupIndex = manager.shelvedGroups.firstIndex(where: { $0.id == groupId }) {
            // Drop onto the SAME open shelf session -> combine
            manager.combineFiles(urls, intoGroupAt: existingGroupIndex)
        } else {
            // First drop in this shelf session -> create a fresh group
            let group = ShelfGroup(files: urls)
            currentShelfGroupId = group.id
            manager.shelvedGroups.append(group)
            manager.lastDropTime = Date()
            HapticManager.shared.success()
            
            let groupID = group.id
            for url in urls {
                Task {
                    if let img = await ShelfGroup.generateThumb(for: url) {
                        await MainActor.run {
                            if let index = manager.shelvedGroups.firstIndex(where: { $0.id == groupID }) {
                                manager.shelvedGroups[index].thumbnails[url] = img
                            }
                        }
                    }
                }
            }
        }
        
        // Generate thumbnails locally for shelf view
        for url in uniqueNewUrls {
            Task {
                if let img = await ShelfGroup.generateThumb(for: url) {
                    await MainActor.run {
                        self.thumbnails[url] = img
                    }
                }
            }
        }
    }
    
    func removeFileFromShelf(_ url: URL) {
        shelfFiles.removeAll(where: { $0 == url })
        thumbnails.removeValue(forKey: url)
        
        // Also remove from DropzoneManager
        DropzoneManager.shared.removeFileFromShelf(url, fromGroupId: currentShelfGroupId)
        
        // Close shelf windows if it becomes empty
        if shelfFiles.isEmpty {
            for shelf in activeShelves {
                shelf.orderOut(nil)
            }
            activeShelves.removeAll()
            currentShelfGroupId = nil
        }
    }

    func removeGroupFromShelf(groupId: UUID) {
        shelfFiles.removeAll()
        thumbnails.removeAll()
        
        // Remove from DropzoneManager!
        DropzoneManager.shared.deleteShelfGroup(where: { $0.id == groupId })
        
        // Close shelf windows
        for shelf in activeShelves {
            shelf.orderOut(nil)
        }
        activeShelves.removeAll()
        currentShelfGroupId = nil
    }
}

// MARK: - FloatingShelfWindow

class FloatingShelfWindow: NSPanel {
    init(position: NSPoint) {
        let size = NSSize(width: 150, height: 185)
        let rect = NSRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        
        let hostingView = NSHostingView(rootView: FloatingShelfView(window: self))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        
        self.contentView = hostingView
    }
}

// MARK: - WindowDragView

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DraggingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class DraggingView: NSView {
        override func mouseDown(with event: NSEvent) {
            self.window?.performDrag(with: event)
        }
    }
}

// MARK: - FloatingShelfView

struct FloatingShelfView: View {
    let window: FloatingShelfWindow
    @ObservedObject var shelfManager = FloatingShelfManager.shared
    @ObservedObject var manager = DropzoneManager.shared
    @State private var isTargeted = false
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .cornerRadius(16)
            
            WindowDragView()
                .cornerRadius(16)
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(isTargeted ? Color.green.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
            
            VStack {
                if shelfManager.shelfFiles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("Drop Files")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(10)
                    )
                } else {
                    ShelfCardStack(window: window)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 18)
                }
            }
            
            // Window close button (removes local shelf reference, preserves Dropzone files)
            VStack {
                HStack {
                    Button(action: {
                        FloatingShelfManager.shared.removeShelf(window)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: 150, height: 185)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            let group = DispatchGroup()
            let lock = NSLock()
            var urls: [URL] = []
            
            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    if let nsUrl = object as? NSURL, let url = nsUrl as URL? {
                        lock.lock()
                        urls.append(url)
                        lock.unlock()
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if !urls.isEmpty {
                    FloatingShelfManager.shared.addFilesToShelf(urls)
                }
            }
            return true
        }
        .onChange(of: manager.shelvedGroups.isEmpty) { _, isEmpty in
            if isEmpty {
                FloatingShelfManager.shared.shelfFiles.removeAll()
                FloatingShelfManager.shared.thumbnails.removeAll()
                FloatingShelfManager.shared.removeShelf(window)
            }
        }
    }
}

// MARK: - ShelfCardStack

struct ShelfCardStack: View {
    @ObservedObject var shelfManager = FloatingShelfManager.shared
    @ObservedObject var manager = DropzoneManager.shared
    let window: FloatingShelfWindow
    @State private var currentIndex: Int = 0
    @State private var isExpanded = false
    
    var body: some View {
        let files = shelfManager.shelfFiles
        let count = files.count
        guard count > 0 else { return AnyView(EmptyView()) }
        
        let safeIndex = min(currentIndex, count - 1)
        
        return AnyView(
            VStack(spacing: 8) {
                if isExpanded {
                    // Expanded Scrollable list view of files
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(files, id: \.self) { url in
                                let thumb = shelfManager.thumbnails[url]
                                ShelfListRow(url: url, thumbnail: thumb) {
                                    withAnimation(.spring()) {
                                        shelfManager.removeFileFromShelf(url)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .frame(height: 105)
                    
                    // Collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("Collapse")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                } else {
                    // Stack View (ZStack)
                    ZStack {
                        let showing = min(3, count)
                        ForEach(0..<showing, id: \.self) { offset in
                            let fileIdx = (safeIndex + offset) % count
                            let url = files[fileIdx]
                            let isTop = offset == 0
                            let thumb = shelfManager.thumbnails[url]
                            
                            ShelfCardView(
                                url: url,
                                thumbnail: thumb,
                                isTop: isTop,
                                files: files
                            ) {
                                withAnimation(.spring()) {
                                    shelfManager.removeFileFromShelf(url)
                                    if currentIndex > 0 { currentIndex -= 1 }
                                }
                            } onDragSuccess: {
                                withAnimation(.spring()) {
                                    if let groupId = shelfManager.currentShelfGroupId {
                                        shelfManager.removeGroupFromShelf(groupId: groupId)
                                    } else {
                                        shelfManager.shelfFiles.removeAll()
                                    }
                                }
                            }
                            .offset(
                                x: CGFloat(showing - 1 - offset) * 3,
                                y: CGFloat(showing - 1 - offset) * -5
                            )
                            .rotationEffect(.degrees(Double(showing - 1 - offset) * -1.5))
                            .scaleEffect(isTop ? 1.0 : 1.0 - CGFloat(showing - 1 - offset) * 0.03)
                            .zIndex(Double(showing - offset))
                        }
                    }
                    .frame(width: 110, height: 115)
                    
                    // Bottom navigation controls & Expand button
                    HStack(spacing: 6) {
                        Button(action: {
                            QuickLookManager.shared.togglePreview(urls: files, initialIndex: safeIndex)
                        }) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .help("QuickLook Preview (Space)")
                        
                        if count > 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    currentIndex = (safeIndex - 1 + count) % count
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            
                            // Expand button (chevron.down)
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isExpanded = true
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text("\(safeIndex + 1)/\(count)")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    currentIndex = (safeIndex + 1) % count
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .foregroundColor(.white.opacity(0.18))
            )
            .onChange(of: count) { _, newCount in
                if newCount == 0 { currentIndex = 0 }
                else if currentIndex >= newCount { currentIndex = newCount - 1 }
            }
            .contextMenu {
                if !files.isEmpty {
                    Button("QuickLook Preview") {
                        QuickLookManager.shared.togglePreview(urls: files, initialIndex: safeIndex)
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(files)
                    }
                    Button("Copy Path(s)") {
                        let paths = files.map { $0.path }.joined(separator: "\n")
                        let pb = NSPasteboard.general
                        pb.declareTypes([.string], owner: nil)
                        pb.setString(paths, forType: .string)
                        HapticManager.shared.success()
                    }
                    Divider()
                    ForEach(manager.enabledActions, id: \.self) { action in
                        Button(actionDisplayName(action)) {
                            manager.handleDrop(urls: files, onKey: "action_\(action)")
                            shelfManager.shelfFiles.removeAll()
                        }
                    }
                    if !manager.customFolders.isEmpty {
                        Divider()
                        Menu("Move to Folder") {
                            ForEach(manager.customFolders) { folder in
                                Button(folder.name) {
                                    if let path = folder.path {
                                        manager.handleDrop(urls: files, onKey: "folder_\(path)")
                                        shelfManager.shelfFiles.removeAll()
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Clear All") { shelfManager.shelfFiles.removeAll() }
                }
            }
        )
    }
    
    private func actionDisplayName(_ key: String) -> String {
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
}

// MARK: - ShelfCardView

struct ShelfCardView: View {
    let url: URL
    let thumbnail: NSImage?
    let isTop: Bool
    let files: [URL]
    let onRemove: () -> Void
    let onDragSuccess: () -> Void
    
    var body: some View {
        SingleCardView(url: url, thumbnail: thumbnail, isTop: isTop)
            .overlay(
                Group {
                    if isTop {
                        ShelfDragTrackerView(
                            urls: files,
                            thumbnail: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path)
                        ) { success in
                            if success {
                                onDragSuccess()
                            }
                        }
                    }
                }
            )
            .overlay(
                Group {
                    if isTop {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.red.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                    }
                },
                alignment: .topTrailing
            )
    }
}

// MARK: - ShelfListRow

struct ShelfListRow: View {
    let url: URL
    let thumbnail: NSImage?
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Group {
                            if let img = thumbnail {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    )
                
                // Individual item drag-out tracker
                ShelfDragTrackerView(
                    urls: [url],
                    thumbnail: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path)
                ) { success in
                    if success {
                        onRemove()
                    }
                }
            }
            
            Text(url.lastPathComponent)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                QuickLookManager.shared.togglePreview(urls: [url])
            }) {
                Image(systemName: "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 2)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }
}

// MARK: - SingleCardView

struct SingleCardView: View {
    let url: URL
    let thumbnail: NSImage?
    let isTop: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .frame(width: 86, height: 86)
                .overlay(
                    Group {
                        if let img = thumbnail {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 54, height: 54)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(isTop ? 0.2 : 0.08), lineWidth: 1.0)
                )
                .onTapGesture(count: 2) {
                    QuickLookManager.shared.togglePreview(urls: [url])
                }
            
            if isTop {
                Text(url.lastPathComponent)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineLimit(1)
                    .frame(width: 100)
            }
        }
    }
}

// MARK: - ShelfDragTrackerView

struct ShelfDragTrackerView: NSViewRepresentable {
    let urls: [URL]
    let thumbnail: NSImage
    let onDragEnded: (Bool) -> Void
    
    func makeNSView(context: Context) -> ShelfDragTrackerNSView {
        let view = ShelfDragTrackerNSView()
        view.urls = urls
        view.thumbnail = thumbnail
        view.onDragEnded = onDragEnded
        return view
    }
    
    func updateNSView(_ nsView: ShelfDragTrackerNSView, context: Context) {
        nsView.urls = urls
        nsView.thumbnail = thumbnail
        nsView.onDragEnded = onDragEnded
    }
}

// MARK: - ShelfDragTrackerNSView

class ShelfDragTrackerNSView: NSView {
    var urls: [URL] = []
    var thumbnail: NSImage = NSImage()
    var onDragEnded: ((Bool) -> Void)?
    
    private var mouseDownEvent: NSEvent?
    private var isDragging = false
    
    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let downEvent = mouseDownEvent, !isDragging else { return }
        
        let down = downEvent.locationInWindow
        let cur = event.locationInWindow
        let dist = sqrt(pow(cur.x - down.x, 2) + pow(cur.y - down.y, 2))
        
        guard dist > 5 else { return }
        
        isDragging = true
        mouseDownEvent = nil
        
        let draggingItems = urls.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let loc = convert(event.locationInWindow, from: nil)
            let dragImage = NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(x: loc.x - 27, y: loc.y - 27, width: 54, height: 54),
                                  contents: dragImage)
            return item
        }
        
        guard !draggingItems.isEmpty else { return }
        
        beginDraggingSession(with: draggingItems, event: event,
                             source: ShelfDraggingSource { [weak self] success in
            self?.onDragEnded?(success)
        })
    }
    
    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        isDragging = false
    }
}

// MARK: - ShelfDraggingSource

class ShelfDraggingSource: NSObject, NSDraggingSource {
    let onDragEnded: (Bool) -> Void
    
    init(onDragEnded: @escaping (Bool) -> Void) {
        self.onDragEnded = onDragEnded
    }
    
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        let success = operation != []
        let droppedOnShelf = FloatingShelfManager.shared.activeShelves.contains { window in
            window.frame.contains(screenPoint)
        }
        
        DispatchQueue.main.async {
            if success && !droppedOnShelf {
                self.onDragEnded(true)
            } else {
                self.onDragEnded(false)
            }
        }
    }
}
