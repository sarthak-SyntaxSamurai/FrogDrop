import AppKit
import SwiftUI

class DropzonePanelWindow: NSWindow {
    private var statusItemFrame: NSRect
    private let collapsedHostingView: NSHostingView<CollapsedPanelView>
    private let expandedContainer = NSView()
    private let expandedHostingView: DropzoneHostingView<DropzonePanelView>
    private var isExpanded = false
    
    // Drag state tracking
    var isDragOverPanel = false
    var isDraggingActive = false {
        didSet {
            dragOverlay.isHidden = !isDraggingActive
        }
    }
    private let dragOverlay = DropzoneDragOverlay()
    
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
        let height: CGFloat = 520
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
        self.expandedHostingView = DropzoneHostingView(rootView: DropzonePanelView())
        
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
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.frame = expandedContainer.bounds
        effectView.autoresizingMask = [.width, .height]
        
        expandedHostingView.frame = expandedContainer.bounds
        expandedHostingView.autoresizingMask = [.width, .height]
        
        expandedContainer.addSubview(effectView)
        expandedContainer.addSubview(expandedHostingView)
        contentView.addSubview(expandedContainer)
        
        dragOverlay.frame = contentView.bounds
        dragOverlay.autoresizingMask = [.width, .height]
        dragOverlay.onDragEntered = { [weak self] in
            self?.isDragOverPanel = true
            self?.slideIn()
        }
        dragOverlay.onDragExited = { [weak self] in
            self?.isDragOverPanel = false
            self?.slideOut()
        }
        dragOverlay.onDragEnded = { [weak self] in
            self?.isDragOverPanel = false
            self?.slideOut(force: true)
        }
        dragOverlay.isHidden = true
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
    
    func slideOut(force: Bool = false) {
        guard isExpanded else { return }
        
        if !force {
            let mouseLoc = NSEvent.mouseLocation
            if self.frame.contains(mouseLoc) {
                print("[DropzonePanelWindow] slideOut skipped: Mouse is inside panel frame")
                return
            }
            if let statusItemWindow = AppDelegate.shared.statusItem?.button?.window,
               statusItemWindow.frame.contains(mouseLoc) {
                print("[DropzonePanelWindow] slideOut skipped: Mouse is inside status bar button")
                return
            }
        }
        
        isExpanded = false
        self.hasShadow = false
        self.isDragOverPanel = false
        
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
        isDraggingActive = true
        self.orderFrontRegardless()
    }
    
    func hideCollapsedIndicator() {
        guard !isExpanded else { return }
        isDraggingActive = false
        self.orderOut(nil)
    }
    
    func updatePosition(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        let targetRect = isExpanded ? Self.getExpandedRect(statusItemFrame: statusItemFrame) : Self.getCollapsedRect(statusItemFrame: statusItemFrame)
        self.setFrame(targetRect, display: true)
    }
}
