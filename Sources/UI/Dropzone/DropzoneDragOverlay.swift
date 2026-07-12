import AppKit
import SwiftUI

class DropzoneDragOverlay: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDragEnded: (() -> Void)?
    
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
        onDragEnded?()
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

class DraggingSource: NSObject, NSDraggingSource {
    static let shared = DraggingSource()
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                if let group = DropzoneManager.shared.currentlyDraggingGroup {
                    DropzoneManager.shared.deleteShelfGroup(where: { $0.id == group.id })
                    DropzoneManager.shared.currentlyDraggingGroup = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared.closeAllPanels()
        }
    }
}

struct CardDragTrackerView: NSViewRepresentable {
    let group: ShelfGroup
    
    func makeNSView(context: Context) -> DragTrackerNSView {
        let view = DragTrackerNSView()
        view.group = group
        return view
    }
    
    func updateNSView(_ nsView: DragTrackerNSView, context: Context) {
        nsView.group = group
    }
}

class DragTrackerNSView: NSView {
    var group: ShelfGroup?
    private var mouseDownEvent: NSEvent?
    private var isDragging = false
    
    override func mouseDown(with event: NSEvent) {
        self.mouseDownEvent = event
        self.isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent = mouseDownEvent, !isDragging else {
            super.mouseDragged(with: event)
            return
        }
        
        let downPoint = mouseDownEvent.locationInWindow
        let currentPoint = event.locationInWindow
        let dx = currentPoint.x - downPoint.x
        let dy = currentPoint.y - downPoint.y
        let distance = sqrt(dx*dx + dy*dy)
        
        if distance > 5 {
            self.isDragging = true
            self.mouseDownEvent = nil
            
            guard let group = group else { return }
            
            DropzoneManager.shared.currentlyDraggingGroup = group
            
            let draggingItems = group.files.map { url -> NSDraggingItem in
                let item = NSDraggingItem(pasteboardWriter: url as NSURL)
                let dragImage = group.thumbnails[url] ?? NSWorkspace.shared.icon(forFile: url.path)
                
                let convertedLoc = self.convert(event.locationInWindow, from: nil)
                let frame = NSRect(
                    x: convertedLoc.x - 16,
                    y: convertedLoc.y - 16,
                    width: 32,
                    height: 32
                )
                item.setDraggingFrame(frame, contents: dragImage)
                return item
            }
            
            self.beginDraggingSession(with: draggingItems, event: event, source: DraggingSource.shared)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let mouseDownEvent = mouseDownEvent, !isDragging {
            self.isHidden = true
            if let parent = self.superview,
               let hitView = parent.hitTest(mouseDownEvent.locationInWindow) {
                self.isHidden = false
                hitView.mouseDown(with: mouseDownEvent)
                hitView.mouseUp(with: event)
            } else {
                self.isHidden = false
            }
        }
        self.mouseDownEvent = nil
        self.isDragging = false
    }
}
