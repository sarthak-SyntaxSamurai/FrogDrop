import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    private var tongueWindow: TongueOverlayWindow?
    private var lastSelectedDuration: TimerDuration = .cancel
    var dropzonePanel: DropzonePanelWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Run as accessory app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        
        // Initialize the DropzonePanel immediately on launch (Zero-Permission!)
        let statusItemFrame = statusItem?.button?.window?.frame ?? .zero
        dropzonePanel = DropzonePanelWindow(statusItemFrame: statusItemFrame)
        
        // Reposition dynamically once status bar layouts complete (approx 0.5s after event loop starts)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let statusItem = self.statusItem else { return }
            let frame = statusItem.button?.window?.frame ?? .zero
            print("[AppDelegate] Deferred StatusItem frame: \(frame)")
            self.dropzonePanel?.updatePosition(statusItemFrame: frame)
        }
        
        // Start monitoring global drag operations
        GlobalDragMonitor.shared.start()
        
        // Warm up managers
        _ = ClipboardManager.shared
        _ = CursorTracker.shared
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        
        if let button = statusItem?.button {
            button.registerForDraggedTypes([.fileURL, .URL])
            let frogView = MenuBarFrogView()
            let hostingView = InteractiveFrogView(rootView: frogView)
            
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(hostingView)
            
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: button.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            
            // Mouse & Drag callbacks
            hostingView.onClick = { [weak self] in
                self?.togglePopupWindow()
            }
            
            hostingView.onDragStart = { [weak self] _ in
                self?.startTongueDrag()
            }
            
            hostingView.onDragUpdate = { [weak self] dy in
                self?.updateTongueDrag(dy: dy)
            }
            
            hostingView.onDragEnd = { [weak self] dy in
                self?.endTongueDrag(dy: dy)
            }
        }
    }

    
    // MARK: - Popup Window Management
    
    private func togglePopupWindow() {
        guard let button = statusItem?.button, let window = button.window else { return }
        let statusItemFrame = window.frame
        
        if let active = PopupWindow.activeInstance {
            active.orderOut(nil)
            PopupWindow.activeInstance = nil
            HapticManager.shared.click()
        } else {
            let popup = PopupWindow(statusItemFrame: statusItemFrame)
            PopupWindow.activeInstance = popup
            popup.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            HapticManager.shared.click()
        }
    }
    
    // MARK: - Tongue Drag-Down Timer Setup
    
    private func startTongueDrag() {
        guard let button = statusItem?.button, let window = button.window else { return }
        let statusItemFrame = window.frame
        
        // Hide popup window if active
        if let active = PopupWindow.activeInstance {
            active.orderOut(nil)
            PopupWindow.activeInstance = nil
        }
        
        lastSelectedDuration = .cancel
        tongueWindow = TongueOverlayWindow(statusItemFrame: statusItemFrame, initialLength: 0.0)
        tongueWindow?.orderFrontRegardless()
        
        HapticManager.shared.tick()
    }
    
    private func updateTongueDrag(dy: CGFloat) {
        // Clamp and update length
        let clampedLength = max(0, min(dy, 380))
        tongueWindow?.updateLength(clampedLength)
        
        let currentDuration = TimerDuration.fromDragDistance(clampedLength)
        if currentDuration != lastSelectedDuration {
            HapticManager.shared.tick()
            lastSelectedDuration = currentDuration
        }
    }
    
    private func endTongueDrag(dy: CGFloat) {
        tongueWindow?.orderOut(nil)
        tongueWindow = nil
        
        let clampedLength = max(0, min(dy, 380))
        let finalDuration = TimerDuration.fromDragDistance(clampedLength)
        
        if finalDuration != .cancel {
            TimerManager.shared.startTimer(duration: finalDuration.seconds)
            HapticManager.shared.success()
        } else {
            HapticManager.shared.click()
        }
        
        lastSelectedDuration = .cancel
    }
}

// Custom view that sits inside NSButton to intercept click vs drag
@MainActor
class InteractiveFrogView: NSHostingView<MenuBarFrogView> {
    var onClick: (() -> Void)?
    var onDragStart: ((NSPoint) -> Void)?
    var onDragUpdate: ((CGFloat) -> Void)?
    var onDragEnd: ((CGFloat) -> Void)?
    
    private var startPoint: NSPoint?
    private var isDragging = false
    
    required init(rootView: MenuBarFrogView) {
        super.init(rootView: rootView)
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
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("[InteractiveFrogView] draggingEntered status bar button")
        AppDelegate.shared.dropzonePanel?.slideIn()
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("[InteractiveFrogView] draggingExited")
        checkAndSlideOut()
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        print("[InteractiveFrogView] draggingEnded")
        AppDelegate.shared.dropzonePanel?.slideOut()
    }
    
    private func checkAndSlideOut() {
        guard let panel = AppDelegate.shared.dropzonePanel else { return }
        let mouseLoc = NSEvent.mouseLocation
        if panel.frame.contains(mouseLoc) {
            print("[InteractiveFrogView] Cursor is inside panel, skipping slideOut")
            return
        }
        print("[InteractiveFrogView] Cursor is outside panel, sliding out")
        panel.slideOut()
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        isDragging = false
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = startPoint else { return }
        let currentPoint = event.locationInWindow
        let dy = startPoint.y - currentPoint.y // positive value means dragging downwards
        
        if !isDragging && dy > 12 {
            isDragging = true
            onDragStart?(NSEvent.mouseLocation)
        }
        
        if isDragging {
            onDragUpdate?(dy)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDragging {
            let currentPoint = event.locationInWindow
            let dy = startPoint!.y - currentPoint.y
            onDragEnd?(dy)
        } else {
            onClick?()
        }
        startPoint = nil
        isDragging = false
    }
}

@MainActor
class GlobalDragMonitor {
    static let shared = GlobalDragMonitor()
    
    private var dragMonitor: Any?
    private var upMonitor: Any?
    
    private init() {}
    
    func start() {
        // Monitor global drags
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
            DispatchQueue.main.async {
                AppDelegate.shared.dropzonePanel?.showCollapsedIndicator()
            }
        }
        
        // Monitor drag ends / mouse up
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            DispatchQueue.main.async {
                AppDelegate.shared.dropzonePanel?.hideCollapsedIndicator()
            }
        }
    }
    
    func stop() {
        if let dragMonitor = dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }
        if let upMonitor = upMonitor {
            NSEvent.removeMonitor(upMonitor)
            self.upMonitor = nil
        }
    }
}

