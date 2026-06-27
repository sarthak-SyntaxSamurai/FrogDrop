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
        statusItem = NSStatusBar.system.statusItem(withLength: 26) // Placeholder initial size
        
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
            
            hostingView.onDragStart = { [weak self] pt in
                self?.startTongueDrag(at: pt)
            }
            
            hostingView.onDragUpdate = { [weak self] pt in
                self?.updateTongueDrag(to: pt)
            }
            
            hostingView.onDragEnd = { [weak self] pt in
                self?.endTongueDrag(at: pt)
            }
            
            // Initial layout calculation
            updateMenuBarTitle()
        }
    }

    func updateMenuBarTitle() {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        for subview in button.subviews {
            if let hostingView = subview as? InteractiveFrogView {
                hostingView.invalidateIntrinsicContentSize()
                let width = hostingView.fittingSize.width
                statusItem.length = width
                
                // Reposition the dropzone panel when the status item width changes
                let frame = button.window?.frame ?? .zero
                self.dropzonePanel?.updatePosition(statusItemFrame: frame)
            }
        }
    }

    
    // MARK: - Popup Window Management
    
    func togglePopupWindow() {
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
    
    private var tongueAnchorPoint: NSPoint = .zero
    
    private func startTongueDrag(at mouseLocation: NSPoint) {
        guard let button = statusItem?.button, let window = button.window else { return }
        let statusItemFrame = window.frame
        
        // Center-bottom of status bar item in screen space
        tongueAnchorPoint = NSPoint(x: statusItemFrame.midX, y: statusItemFrame.minY + 2)
        
        // Hide popup window if active
        if let active = PopupWindow.activeInstance {
            active.orderOut(nil)
            PopupWindow.activeInstance = nil
        }
        
        lastSelectedDuration = .cancel
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        tongueWindow = TongueOverlayWindow(screenFrame: screen.frame, startPoint: tongueAnchorPoint, initialCurrentPoint: mouseLocation)
        tongueWindow?.orderFrontRegardless()
        
        HapticManager.shared.tick()
    }
    
    private func updateTongueDrag(to mouseLocation: NSPoint) {
        let dx = mouseLocation.x - tongueAnchorPoint.x
        let dy = mouseLocation.y - tongueAnchorPoint.y
        let distance = sqrt(dx*dx + dy*dy)
        let clampedDistance = max(0, min(distance, 380))
        
        let clampedEndPoint: NSPoint
        if distance > 0 {
            clampedEndPoint = NSPoint(
                x: tongueAnchorPoint.x + (dx / distance) * clampedDistance,
                y: tongueAnchorPoint.y + (dy / distance) * clampedDistance
            )
        } else {
            clampedEndPoint = tongueAnchorPoint
        }
        
        tongueWindow?.updatePoints(start: tongueAnchorPoint, current: clampedEndPoint)
        
        let currentDuration = TimerDuration.fromDragDistance(clampedDistance)
        if currentDuration != lastSelectedDuration {
            HapticManager.shared.tick()
            lastSelectedDuration = currentDuration
        }
    }
    
    private func endTongueDrag(at mouseLocation: NSPoint) {
        tongueWindow?.orderOut(nil)
        tongueWindow = nil
        
        let dx = mouseLocation.x - tongueAnchorPoint.x
        let dy = mouseLocation.y - tongueAnchorPoint.y
        let distance = sqrt(dx*dx + dy*dy)
        let clampedDistance = max(0, min(distance, 380))
        let finalDuration = TimerDuration.fromDragDistance(clampedDistance)
        
        if finalDuration != .cancel {
            // Check direction: if released to the right of status bar item center
            if mouseLocation.x > tongueAnchorPoint.x {
                // Drag Right: Setup Mode
                TimerManager.shared.setupSeconds = finalDuration.seconds
                TimerManager.shared.isShowingSetup = true
                TimerManager.shared.setupTaskName = ""
                TimerManager.shared.setupIsPomodoro = false
                
                // Show popover window
                togglePopupWindow()
                HapticManager.shared.success()
            } else {
                // Drag Left: Direct Start
                TimerManager.shared.startTimer(duration: finalDuration.seconds)
                HapticManager.shared.success()
            }
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
    var onDragUpdate: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    
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
        let dx = currentPoint.x - startPoint.x
        let dy = startPoint.y - currentPoint.y
        let dist = sqrt(dx*dx + dy*dy)
        
        if !isDragging && dist > 12 {
            isDragging = true
            onDragStart?(NSEvent.mouseLocation)
        }
        
        if isDragging {
            onDragUpdate?(NSEvent.mouseLocation)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDragging {
            onDragEnd?(NSEvent.mouseLocation)
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

