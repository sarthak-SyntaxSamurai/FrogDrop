import AppKit
import SwiftUI
import Foundation
import Combine

extension Notification.Name {
    static let popupWillOpen = Notification.Name("popupWillOpen")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    private var tongueWindow: TongueOverlayWindow?
    private var lastSelectedDuration: TimerDuration = .cancel
    var dropzonePanel: DropzonePanelWindow?
    var popupPanel: PopupPanelWindow?
    private var panelCloseMonitor: Any?
    private var localCloseMonitor: Any?
    private var activity: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Prevent AppKit from automatically terminating the application when idle (TAL)
        ProcessInfo.processInfo.disableAutomaticTermination("Keep FrogDrop running in the Menu Bar permanently")
        
        // Prevent App Nap from suspending the background services
        self.activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Keep FrogDrop services responsive"
        )
        
        // Run as accessory app (only in Menu Bar, hides from Dock)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        
        // Initialize Main Window (do not show on startup)
        let mainWindow = MainWindow()
        MainWindow.shared = mainWindow
        
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
        
        // Start monitoring global clipboard hotkeys (Cmd+0 to Cmd+9)
        GlobalHotkeyManager.shared.setup()
        
        // Warm up managers
        _ = ClipboardManager.shared
        _ = CursorTracker.shared
        
        // Listen for clipboard toast notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowClipboardToast"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self, let item = notification.object as? ClipboardItem else { return }
                let frame = self.statusItem?.button?.window?.frame ?? .zero
                ClipboardToastPanelWindow.shared.show(
                    statusItemFrame: frame,
                    text: item.text,
                    appName: item.sourceApp ?? "Unknown",
                    isTemporary: item.isTemporary
                )
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindow.shared?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
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
            
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMenuBarTitle()
                }
            }
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
    
    var popupPopover: NSPopover?
    
    var activePopupWindow: NSWindow? {
        let style = UserDefaults.standard.string(forKey: "popupStyle") ?? "popover"
        if style == "panel" {
            return popupPanel
        } else {
            return popupPopover?.contentViewController?.view.window
        }
    }
    
    func togglePopupWindow() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        
        // Convert button bounds to screen coordinates
        let rectInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = buttonWindow.convertToScreen(rectInWindow)
        
        let style = UserDefaults.standard.string(forKey: "popupStyle") ?? "popover"
        
        if style == "panel" {
            // Close popover if shown
            if let popover = popupPopover, popover.isShown {
                popover.performClose(nil)
            }
            
            if popupPanel == nil {
                let hostingController = NSHostingController(rootView: PopupView())
                popupPanel = PopupPanelWindow(contentView: hostingController.view)
            }
            
            if let panel = popupPanel {
                if panel.isVisible {
                    closePanel()
                    HapticManager.shared.click()
                } else {
                    NotificationCenter.default.post(name: .popupWillOpen, object: nil)
                    panel.updatePosition(relativeTo: buttonFrame)
                    NSApp.activate(ignoringOtherApps: true)
                    panel.makeKeyAndOrderFront(nil)
                    HapticManager.shared.click()
                    startPanelCloseMonitor()
                }
            }
        } else {
            // Close panel if visible
            closePanel()
            
            if popupPopover == nil {
                let popover = NSPopover()
                popover.contentSize = NSSize(width: 340, height: 460)
                popover.behavior = .transient
                popover.contentViewController = NSHostingController(rootView: PopupView())
                popover.delegate = self
                self.popupPopover = popover
            }
            
            if let popover = popupPopover {
                if popover.isShown {
                    popover.performClose(nil)
                    HapticManager.shared.click()
                } else {
                    NotificationCenter.default.post(name: .popupWillOpen, object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    HapticManager.shared.click()
                }
            }
        }
    }
    
    func closePanel() {
        popupPanel?.orderOut(nil)
        stopPanelCloseMonitor()
    }
    
    private func startPanelCloseMonitor() {
        stopPanelCloseMonitor()
        
        // Monitor clicks in other apps
        panelCloseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePanel()
            }
        }
        
        // Monitor clicks within our own app (like dashboard, settings, or menu bar clicks)
        localCloseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.popupPanel, panel.isVisible else { return event }
            
            let mouseLocationInScreen = NSEvent.mouseLocation
            if !panel.frame.contains(mouseLocationInScreen) {
                // If it's a click on the status item button, let it be handled by the button's toggle action (which closes it)
                if let buttonWindow = self.statusItem?.button?.window, buttonWindow.frame.contains(mouseLocationInScreen) {
                    return event
                }
                
                // Otherwise close the panel immediately
                DispatchQueue.main.async {
                    self.closePanel()
                }
            }
            return event
        }
    }
    
    private func stopPanelCloseMonitor() {
        if let monitor = panelCloseMonitor {
            NSEvent.removeMonitor(monitor)
            panelCloseMonitor = nil
        }
        if let monitor = localCloseMonitor {
            NSEvent.removeMonitor(monitor)
            localCloseMonitor = nil
        }
    }
    
    func closeAllPanels() {
        dropzonePanel?.slideOut(force: true)
        popupPopover?.performClose(nil)
        closePanel()
        ClipboardPreviewManager.shared.hidePreview()
    }
    
    // NSPopoverDelegate
    
    func popoverWillClose(_ notification: Notification) {
        ClipboardPreviewManager.shared.hidePreview()
    }
    
    @objc func openDashboard() {
        MainWindow.shared?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func setIconStyleFrog() {
        UserDefaults.standard.set("frog", forKey: "menuBarIconStyle")
    }
    
    @objc func setIconStyleMinimal() {
        UserDefaults.standard.set("minimal", forKey: "menuBarIconStyle")
    }
    
    @objc func setIconStyleCustom() {
        UserDefaults.standard.set("custom", forKey: "menuBarIconStyle")
    }
    
    @objc func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }
    
    // Tongue Drag-Down Timer Setup
    
    private var tongueAnchorPoint: NSPoint = .zero
    
    private func startTongueDrag(at mouseLocation: NSPoint) {
        guard let button = statusItem?.button, let window = button.window else { return }
        let statusItemFrame = window.frame
        
        // Center-bottom of status bar item in screen space
        tongueAnchorPoint = NSPoint(x: statusItemFrame.midX, y: statusItemFrame.minY + 2)
        
        // Hide popup window if active
        popupPopover?.performClose(nil)
        
        lastSelectedDuration = .cancel
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        tongueWindow = TongueOverlayWindow(screenFrame: screenFrame, startPoint: tongueAnchorPoint, initialCurrentPoint: mouseLocation)
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
        AppDelegate.shared.dropzonePanel?.isDraggingActive = true
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
        AppDelegate.shared.dropzonePanel?.isDraggingActive = false
        AppDelegate.shared.dropzonePanel?.slideOut(force: true)
    }
    
    private func checkAndSlideOut() {
        // Delay checking to allow the cursor to move from status item to panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            guard let panel = AppDelegate.shared.dropzonePanel else { return }
            
            // If the drag is over the panel, don't slide out
            if panel.isDragOverPanel {
                print("[InteractiveFrogView] Drag is over panel, skipping slideOut")
                return
            }
            
            let mouseLoc = NSEvent.mouseLocation
            if panel.frame.contains(mouseLoc) {
                print("[InteractiveFrogView] Cursor is inside panel frame, skipping slideOut")
                return
            }
            if let window = self.window, window.frame.contains(mouseLoc) {
                print("[InteractiveFrogView] Cursor is inside status bar button window, skipping slideOut")
                return
            }
            
            print("[InteractiveFrogView] Cursor is outside, sliding out")
            panel.slideOut(force: false)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        isDragging = false
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        
        let iconStyleItem = NSMenuItem(title: "Icon Style", action: nil, keyEquivalent: "")
        let iconStyleMenu = NSMenu()
        
        let currentStyle = UserDefaults.standard.string(forKey: "menuBarIconStyle") ?? "frog"
        
        let frogItem = NSMenuItem(title: "Default Frog", action: #selector(AppDelegate.setIconStyleFrog), keyEquivalent: "")
        frogItem.state = currentStyle == "frog" ? .on : .off
        
        let minimalItem = NSMenuItem(title: "Minimal White", action: #selector(AppDelegate.setIconStyleMinimal), keyEquivalent: "")
        minimalItem.state = currentStyle == "minimal" ? .on : .off
        
        let customItem = NSMenuItem(title: "Custom Image", action: #selector(AppDelegate.setIconStyleCustom), keyEquivalent: "")
        customItem.state = currentStyle == "custom" ? .on : .off
        
        iconStyleMenu.addItem(frogItem)
        iconStyleMenu.addItem(minimalItem)
        iconStyleMenu.addItem(customItem)
        iconStyleItem.submenu = iconStyleMenu
        
        menu.addItem(iconStyleItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(AppDelegate.checkForUpdates), keyEquivalent: "u"))
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(AppDelegate.openDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Quit FrogDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
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
    private var downMonitor: Any?
    
    private var startPoint: NSPoint?
    private var isDragTriggered = false
    private var initialDragChangeCount = 0
    
    // Shake detection state variables
    private var lastMouseLocation: NSPoint?
    private var lastDirectionX: CGFloat = 0
    private var directionChangeCount = 0
    private var lastDirectionChangeTime = Date()
    private var isShelfTriggered = false
    
    private init() {}
    
    func start() {
        // Monitor global mouse down to record start location and pasteboard change count
        downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            DispatchQueue.main.async {
                self.startPoint = NSEvent.mouseLocation
                self.lastMouseLocation = NSEvent.mouseLocation
                self.lastDirectionX = 0
                self.directionChangeCount = 0
                self.isDragTriggered = false
                self.isShelfTriggered = false
                self.initialDragChangeCount = NSPasteboard(name: .drag).changeCount
            }
        }
        
        // Monitor global drags
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
            DispatchQueue.main.async {
                // Check if the pasteboard change count has actually changed since mouseDown.
                // If it has not changed, then no system drag-and-drop session has been initiated
                // (e.g. the user is just selecting text, drawing, or moving windows).
                let pasteboard = NSPasteboard(name: .drag)
                guard pasteboard.changeCount != self.initialDragChangeCount else { return }
                guard let types = pasteboard.types, !types.isEmpty else { return }
                
                guard let start = self.startPoint else { return }
                let current = NSEvent.mouseLocation
                let dx = current.x - start.x
                let dy = current.y - start.y
                let dist = sqrt(dx*dx + dy*dy)
                
                // Only show collapsed indicator if the drag distance exceeds 15 pixels
                // This prevents clicks & double-clicks from triggering it
                if dist > 15 && !self.isDragTriggered {
                    self.isDragTriggered = true
                    AppDelegate.shared.closeAllPanels()
                    AppDelegate.shared.dropzonePanel?.showCollapsedIndicator()
                }
                
                // Shake/wiggle gesture detection during active drag session
                if let prev = self.lastMouseLocation {
                    let moveX = current.x - prev.x
                    // Threshold to ignore tiny micro-movements
                    if abs(moveX) > 4.0 {
                        let currentDirX = moveX > 0 ? 1.0 : -1.0
                        if self.lastDirectionX != 0 && currentDirX != self.lastDirectionX {
                            let now = Date()
                            // Shaking requires rapid direction reversals
                            if now.timeIntervalSince(self.lastDirectionChangeTime) < 0.35 {
                                self.directionChangeCount += 1
                            } else {
                                self.directionChangeCount = 1
                            }
                            self.lastDirectionChangeTime = now
                            
                            if self.directionChangeCount >= 4 && !self.isShelfTriggered {
                                self.isShelfTriggered = true
                                
                                // Spawn shelf empty — user manually drops files into it
                                if FloatingShelfManager.shared.activeShelves.isEmpty {
                                    FloatingShelfManager.shared.spawnShelf(at: current)
                                } else {
                                    HapticManager.shared.success()
                                }
                            }
                        }
                        self.lastDirectionX = currentDirX
                    }
                }
                self.lastMouseLocation = current
            }
        }
        
        // Monitor drag ends / mouse up
        upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            DispatchQueue.main.async {
                self.startPoint = nil
                self.lastMouseLocation = nil
                self.lastDirectionX = 0
                self.directionChangeCount = 0
                self.isDragTriggered = false
                self.isShelfTriggered = false
                AppDelegate.shared.dropzonePanel?.hideCollapsedIndicator()
                AppDelegate.shared.dropzonePanel?.slideOut(force: true)
            }
        }
    }
}

