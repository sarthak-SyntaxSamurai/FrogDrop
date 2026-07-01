import AppKit
import SwiftUI
import UniformTypeIdentifiers

class PreviewModel: ObservableObject {
    @Published var text: String = ""
}

struct ClipboardPreviewView: View {
    @ObservedObject var model: PreviewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PREVIEW")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                
            Divider()
                .background(Color.white.opacity(0.1))
                
            ScrollView {
                Text(model.text)
                    .font(.system(.subheadline, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .frame(width: 280, height: 200)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

class ClipboardPreviewWindow: NSWindow {
    let model = PreviewModel()
    
    init(contentRect: NSRect, text: String) {
        model.text = text
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = true
        self.appearance = NSAppearance(named: .vibrantDark)
        
        let hostingView = NSHostingView(rootView: ClipboardPreviewView(model: model))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let nsView = NSView()
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = 14
        nsView.layer?.masksToBounds = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        
        self.contentView = nsView
        nsView.addSubview(effectView)
        nsView.addSubview(hostingView)
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: nsView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor),
            
            hostingView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: nsView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
        ])
    }
    
    func updateContent(text: String) {
        model.text = text
    }
}

class PopupWindow: NSWindow, NSWindowDelegate {
    static var activeInstance: PopupWindow?
    private var previewWindow: ClipboardPreviewWindow?
    
    private let statusItemFrame: NSRect
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    
    init(statusItemFrame: NSRect) {
        self.statusItemFrame = statusItemFrame
        let width: CGFloat = 340
        let height: CGFloat = 460
        
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height - 8,
            width: width,
            height: height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = true
        self.delegate = self
        self.appearance = NSAppearance(named: .vibrantDark)

        let hostingView = DropzoneHostingView(rootView: PopupView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let nsView = NSView()
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = 18
        nsView.layer?.masksToBounds = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        
        self.contentView = nsView
        nsView.addSubview(effectView)
        nsView.addSubview(hostingView)
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: nsView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor),
            
            hostingView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: nsView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
        ])
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    deinit {
        removeClickMonitors()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        hidePreview()
        self.orderOut(nil)
        self.removeClickMonitors()
        if PopupWindow.activeInstance == self {
            PopupWindow.activeInstance = nil
        }
    }
    
    private func setupClickMonitors() {
        // Monitor clicks inside our application
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            self.handleOuterClick(event: event)
            return event
        }
        
        // Monitor clicks outside our application
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            self.handleOuterClick(event: event)
        }
    }
    
    private func removeClickMonitors() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    private func handleOuterClick(event: NSEvent) {
        let mouseLoc = NSEvent.mouseLocation
        
        // Check if click was inside the popup window frame or the preview window frame
        if self.frame.contains(mouseLoc) { return }
        if let preview = previewWindow, preview.frame.contains(mouseLoc) { return }
        
        // Check if click was inside the menu bar status item frame (to prevent double-toggling)
        if statusItemFrame.contains(mouseLoc) { return }
        
        // Click was outside everything: dismiss!
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hidePreview()
            self.orderOut(nil)
            self.removeClickMonitors()
            if PopupWindow.activeInstance == self {
                PopupWindow.activeInstance = nil
            }
        }
    }
    
    func showPreview(for item: ClipboardItem, atRowMidY rowMidY: CGFloat) {
        let windowFrame = self.frame
        let screenY = windowFrame.maxY - rowMidY
        
        let previewWidth: CGFloat = 280
        let previewHeight: CGFloat = 200
        
        let previewX = windowFrame.minX - previewWidth - 8
        let previewY = screenY - (previewHeight / 2)
        
        let rect = NSRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight)
        
        if let preview = previewWindow {
            preview.updateContent(text: item.text)
            preview.setFrame(rect, display: true, animate: false)
            preview.orderFront(nil)
        } else {
            let preview = ClipboardPreviewWindow(contentRect: rect, text: item.text)
            previewWindow = preview
            self.addChildWindow(preview, ordered: .above)
            preview.orderFront(nil)
        }
    }
    
    func hidePreview() {
        if let preview = previewWindow {
            self.removeChildWindow(preview)
            preview.orderOut(nil)
            previewWindow = nil
        }
    }
    
    func animateIn() {
        setupClickMonitors()
        let finalFrame = self.frame
        let startFrame = NSRect(
            x: finalFrame.minX,
            y: finalFrame.minY + 25,
            width: finalFrame.width,
            height: finalFrame.height
        )
        self.setFrame(startFrame, display: true)
        self.alphaValue = 0.0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 0.85, 0.35, 1.15)
            self.animator().setFrame(finalFrame, display: true)
            self.animator().alphaValue = 1.0
        }
    }
}

    

struct PopupView: View {
    enum Tab {
        case timer
        case clipboard
        case dropzone
    }
    
    @State private var activeTab: Tab = {
        if TimerManager.shared.state != .idle {
            return .timer
        } else if let lastDrop = DropzoneManager.shared.lastDropTime,
                  Date().timeIntervalSince(lastDrop) < 5 * 60,
                  !DropzoneManager.shared.shelvedFiles.isEmpty {
            return .dropzone
        } else {
            return .clipboard
        }
    }()
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var dropzoneManager = DropzoneManager.shared
    
    // Clipboard Search
    @State private var clipboardSearchQuery = ""
    
    // Settings toggle
    @State private var isShowingSettings = false
    
    @Namespace private var tabNamespace
    
    private func switchToNextTab() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            switch activeTab {
            case .timer:
                activeTab = .clipboard
            case .clipboard:
                activeTab = .dropzone
            case .dropzone:
                break
            }
        }
        HapticManager.shared.tick()
    }
    
    private func switchToPrevTab() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            switch activeTab {
            case .timer:
                break
            case .clipboard:
                activeTab = .timer
            case .dropzone:
                activeTab = .clipboard
            }
        }
        HapticManager.shared.tick()
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header Tab Bar
                HStack(spacing: 2) {
                    TabButton(title: "Timer", icon: "timer", isActive: activeTab == .timer, namespace: tabNamespace) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeTab = .timer
                        }
                    }
                    TabButton(title: "Clipboard", icon: "paperclip", isActive: activeTab == .clipboard, namespace: tabNamespace) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeTab = .clipboard
                        }
                    }
                    TabButton(title: "Dropzone", icon: "square.and.arrow.down", isActive: activeTab == .dropzone, namespace: tabNamespace) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activeTab = .dropzone
                        }
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .padding(.top, 14)
                .padding(.horizontal, 14)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                // Tab Contents
                ZStack {
                    switch activeTab {
                    case .timer:
                        TimerTabView(timerManager: timerManager)
                    case .clipboard:
                        ClipboardTabView(clipboardManager: clipboardManager, searchQuery: $clipboardSearchQuery)
                    case .dropzone:
                        DropzoneTabView()
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onEnded { gesture in
                            let threshold: CGFloat = 40
                            let xDist = abs(gesture.translation.width)
                            let yDist = abs(gesture.translation.height)
                            
                            guard xDist > yDist * 1.5 else { return }
                            
                            if gesture.translation.width < -threshold {
                                switchToNextTab()
                            } else if gesture.translation.width > threshold {
                                switchToPrevTab()
                            }
                        }
                )
                
                // Footer Info
                HStack {
                    HStack(spacing: 6) {
                        Button(action: {
                            isShowingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isShowingSettings, arrowEdge: .top) {
                            DropzoneSettingsView()
                        }
                        
                        Text("FrogDrop • Premium 3-in-1")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    QuitButton()
                }
                .padding(12)
                .background(Color.black.opacity(0.12))
            }
            .frame(width: 340, height: 460)
            .background(
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.12), Color.clear]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 280
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            if dropzoneManager.isShowingCombinePopover {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            dropzoneManager.isShowingCombinePopover = false
                        }
                    }
                
                CombinePopoverView(
                    selectedIDs: $dropzoneManager.selectedGroupIDs,
                    onCombine: {
                        dropzoneManager.combineGroups(withIDs: dropzoneManager.selectedGroupIDs)
                        withAnimation {
                            dropzoneManager.isShowingCombinePopover = false
                        }
                    },
                    onCancel: {
                        withAnimation {
                            dropzoneManager.isShowingCombinePopover = false
                        }
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: activeTab) {
            PopupWindow.activeInstance?.hidePreview()
        }
        .onReceive(TimerManager.shared.$isShowingSetup) { showing in
            if showing {
                activeTab = .timer
            }
        }
    }
}

// Quit Button with Hover State
struct QuitButton: View {
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            Text("Quit")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(isHovered ? .red : .red.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(isHovered ? 0.12 : 0.0))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundColor(isActive ? Color(red: 0.15, green: 0.85, blue: 0.45) : (isHovered ? .primary : .secondary))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .matchedGeometryEffect(id: "activeTabBackground", in: namespace)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.click()
            action()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Preset Button with Hover State
struct PresetButton: View {
    let seconds: TimeInterval
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text("\(Int(seconds / 60))m")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: isHovered ?
                            [Color.white.opacity(0.12), Color.white.opacity(0.04)] :
                            [Color.white.opacity(0.05), Color.white.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isHovered ?
                                LinearGradient(colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: isHovered ? Color.black.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
                .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// ==================== TIMER TAB ====================
struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var focusedDuration: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, focusedDuration
    }
    
    init(id: UUID, title: String, isCompleted: Bool, focusedDuration: TimeInterval = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.focusedDuration = focusedDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        focusedDuration = (try? container.decode(TimeInterval.self, forKey: .focusedDuration)) ?? 0
    }
}

class TodoManager: ObservableObject {
    static let shared = TodoManager()
    
    @Published var items: [TodoItem] = [] {
        didSet {
            save()
        }
    }
    
    private init() {
        load()
    }
    
    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TodoItem(id: UUID(), title: trimmed, isCompleted: false)
        items.append(newItem)
        HapticManager.shared.click()
    }
    
    func toggle(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            HapticManager.shared.click()
        }
    }
    
    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        HapticManager.shared.click()
    }
    
    func addDuration(id: UUID, seconds: TimeInterval) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].focusedDuration += seconds
            save()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "FrogDrop.TodoList")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "FrogDrop.TodoList"),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            self.items = decoded
        }
    }
}

struct TodoListView: View {
    @ObservedObject var todoManager = TodoManager.shared
    @State private var newTodoText = ""
    @State private var isInputHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("To-Do List")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Task input field
            HStack {
                Image(systemName: "plus")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11, weight: .bold))
                TextField("Add task...", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .onSubmit {
                        todoManager.add(title: newTodoText)
                        newTodoText = ""
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(isInputHovered ? 0.08 : 0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInputHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .onHover { hovering in
                isInputHovered = hovering
            }
            
            // To-do ScrollView
            if todoManager.items.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No tasks yet")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(height: 110)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(todoManager.items) { item in
                            TodoRow(item: item)
                        }
                    }
                }
                .frame(height: 110)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var todoManager = TodoManager.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                todoManager.toggle(id: item.id)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            
            Text(item.title)
                .font(.system(.subheadline, design: .rounded))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary.opacity(0.7) : .primary)
                .lineLimit(1)
            
            let durStr = formatFocusedDuration(item.focusedDuration)
            if !durStr.isEmpty {
                Text(durStr)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if isHovering {
                HStack(spacing: 8) {
                    // Play Timer Option
                    Button(action: {
                        TimerManager.shared.setupSeconds = 25 * 60 // 25m default
                        TimerManager.shared.setupTaskName = item.title
                        TimerManager.shared.setupTodoId = item.id
                        TimerManager.shared.isShowingSetup = true
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(5)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Start Focus Timer")
                    
                    // Stopwatch Option
                    Button(action: {
                        TimerManager.shared.startStopwatch(name: item.title, todoId: item.id)
                    }) {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.blue)
                            .padding(5)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Start Stopwatch")
                    
                    // Delete Option
                    Button(action: {
                        todoManager.delete(id: item.id)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red)
                            .padding(5)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Task")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovering ? 0.05 : 0.01))
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatFocusedDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "" }
        let hrs = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        if hrs > 0 {
            if mins > 0 {
                return "\(hrs)h \(mins)m"
            }
            return "\(hrs)h"
        } else {
            return "\(mins)m"
        }
    }
}

struct StopwatchControlView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var taskName: String = ""
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Stopwatch Controls")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TextField("Stopwatch description...", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(isHovered ? 0.08 : 0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .onHover { hovering in
                        isHovered = hovering
                    }
                
                Button(action: {
                    timerManager.startStopwatch(name: taskName)
                    taskName = ""
                }) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

struct TugTimerCard: View {
    let timer: TimerManager.ActiveTimer
    @ObservedObject var timerManager: TimerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !timer.isStopwatch {
                        let endTime = Date().addingTimeInterval(timer.secondsRemaining)
                        Text("Ends at \(formatEndTime(endTime))")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Stopwatch Mode")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Text(formatTime(timer.isStopwatch ? timer.secondsElapsed : timer.secondsRemaining))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(timer.isBreakActive ? .orange : .green)
            }
            
            HStack(spacing: 8) {
                if !timer.isStopwatch {
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 1)
                    }) {
                        Text("+ 1m")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        timerManager.addTime(timerId: timer.id, minutes: 5)
                    }) {
                        Text("+ 5m")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    timerManager.togglePause(timerId: timer.id)
                }) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    timerManager.stopTimer(timerId: timer.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mins, secs)
        } else {
            return String(format: "%02d:%02d", mins, secs)
        }
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Custom inline roller wheel picker mimicking iOS wheel picker layout
struct ScrollWheelPicker: View {
    let range: ClosedRange<Int>
    @Binding var selection: Int
    
    @State private var scrollSelection: Int?
    
    var body: some View {
        ZStack {
            // Highlight bands in center for selected item
            VStack(spacing: 0) {
                Divider()
                    .background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
                Spacer()
                Divider()
                    .background(Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.15))
            }
            .frame(height: 24)
            .background(Color.white.opacity(0.03))
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { val in
                        Text(String(format: "%02d", val))
                            .font(.system(size: selection == val ? 15 : 12, weight: selection == val ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == val ? Color(red: 0.15, green: 0.85, blue: 0.45) : .secondary.opacity(0.35))
                            .frame(height: 24)
                            .frame(maxWidth: .infinity)
                            .id(val)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                    scrollSelection = val
                                }
                                HapticManager.shared.click()
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollSelection)
            .safeAreaPadding(.vertical, 24)
            .frame(height: 72)
            .onAppear {
                scrollSelection = selection
            }
            .onChange(of: selection) { _, newValue in
                if scrollSelection != newValue {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        scrollSelection = newValue
                    }
                }
            }
            .onChange(of: scrollSelection) { _, newValue in
                if let newVal = newValue, selection != newVal {
                    selection = newVal
                    HapticManager.shared.tick()
                }
            }
        }
        .frame(width: 48, height: 72)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

struct TimerSetupView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var taskName: String = ""
    @State private var isPomodoro: Bool = false
    @State private var breakMinutes: Int = 5
    @State private var cycles: Int = 4
    @State private var isTaskHovered = false
    @State private var focusMinutes: Int = 25
    
    // Inline roller selection states
    @State private var setupHours: Int = 0
    @State private var setupMinutes: Int = 25
    
    private var totalDuration: TimeInterval {
        if isPomodoro {
            let focusTotal = timerManager.setupSeconds * Double(cycles)
            let breakTotal = Double(breakMinutes * 60) * Double(cycles - 1)
            return focusTotal + breakTotal
        } else {
            return timerManager.setupSeconds
        }
    }
    
    private var endTime: Date {
        Date().addingTimeInterval(totalDuration)
    }
    
    private func updateFromWheel() {
        var totalSecs = Double(setupHours * 3600 + setupMinutes * 60)
        if totalSecs < 60 {
            totalSecs = 60 // Minimum 1 minute
            setupMinutes = 1
        }
        timerManager.setupSeconds = totalSecs
        focusMinutes = Int(totalSecs / 60)
    }
    
    private func formatSummaryMinutes(_ totalMins: Int) -> String {
        let hrs = totalMins / 60
        let mins = totalMins % 60
        if hrs > 0 {
            if mins > 0 {
                return "\(hrs)h \(mins)m"
            } else {
                return "\(hrs)h"
            }
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                // Inline Hours & Minutes iOS Clock style roller wheel selectors
                HStack(spacing: 0) {
                    Spacer()
                    
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...6, selection: $setupHours)
                        Text("hours")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer().frame(width: 16)
                    
                    HStack(spacing: 6) {
                        ScrollWheelPicker(range: 0...59, selection: $setupMinutes)
                        Text("min")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(height: 74)
                .padding(.top, 4)
                
                Text("Ends at \(formatEndTime(endTime))")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
            .onChange(of: setupHours) { _, _ in
                updateFromWheel()
            }
            .onChange(of: setupMinutes) { _, _ in
                updateFromWheel()
            }
            .onAppear {
                let totalSecs = timerManager.setupSeconds
                self.setupHours = Int(totalSecs) / 3600
                self.setupMinutes = (Int(totalSecs) % 3600) / 60
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("TASK NAME")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.0)
                
                TextField("What are you working on?", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(isTaskHovered ? 0.08 : 0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isTaskHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .onHover { hovering in
                        isTaskHovered = hovering
                    }
            }
            .padding(.horizontal, 4)
            
            Toggle(isOn: $isPomodoro.animation(.spring(response: 0.3, dampingFraction: 0.7))) {
                Text("Pomodoro Mode")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.15, green: 0.85, blue: 0.45)))
            .padding(.horizontal, 4)
            
            if isPomodoro {
                VStack(spacing: 8) {
                    HStack {
                        Text("Break Duration")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $breakMinutes, in: 1...60) {
                            Text("\(breakMinutes) min")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                    
                    HStack {
                        Text("Cycles")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Stepper(value: $cycles, in: 2...12) {
                            Text("\(cycles)")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.bold)
                        }
                    }
                    
                    // Self-calibrating cycle dots using dynamic width calculations to prevent window overflow
                    GeometryReader { geo in
                        let containerWidth = geo.size.width
                        let totalDots = cycles * 2 - 1
                        let spacing: CGFloat = 3
                        let totalSpacersWidth = CGFloat(totalDots - 1) * spacing
                        let remainingWidth = max(20, containerWidth - totalSpacersWidth)
                        let workCount = CGFloat(cycles)
                        let breakCount = CGFloat(cycles - 1)
                        let unitWidth = remainingWidth / (2 * workCount + breakCount)
                        let breakWidth = max(2, unitWidth)
                        let workWidth = max(4, unitWidth * 2)
                        
                        HStack(spacing: spacing) {
                            ForEach(0..<totalDots, id: \.self) { idx in
                                Capsule()
                                    .fill(idx % 2 == 0 ? Color(red: 0.15, green: 0.85, blue: 0.45) : Color.red.opacity(0.6))
                                    .frame(width: idx % 2 == 0 ? workWidth : breakWidth, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 6)
                    .padding(.top, 4)
                    
                    // Summary of total work and break times
                    HStack {
                        let totalWorkMins = (Int(timerManager.setupSeconds) / 60) * cycles
                        let totalBreakMins = breakMinutes * (cycles - 1)
                        
                        Text("Total Work: \(formatSummaryMinutes(totalWorkMins))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
                        
                        Spacer()
                        
                        Text("Total Break: \(formatSummaryMinutes(totalBreakMins))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                    .padding(.horizontal, 2)
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    cancelSetup()
                }) {
                    Text("Cancel")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    startTimer()
                }) {
                    Text("Start")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.05, green: 0.7, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 4)
            
            Text("Enter to start • Esc to cancel")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .onAppear {
            self.taskName = timerManager.setupTaskName
            self.focusMinutes = max(1, Int(timerManager.setupSeconds / 60))
        }
    }
    
    private func cancelSetup() {
        timerManager.isShowingSetup = false
        timerManager.setupTodoId = nil
    }
    
    private func startTimer() {
        if isPomodoro {
            timerManager.startPomodoro(
                taskName: taskName,
                focusDuration: timerManager.setupSeconds,
                breakDuration: TimeInterval(breakMinutes * 60),
                cycles: cycles,
                todoId: timerManager.setupTodoId
            )
        } else {
            timerManager.startTimer(
                duration: timerManager.setupSeconds,
                name: taskName,
                todoId: timerManager.setupTodoId
            )
        }
        timerManager.isShowingSetup = false
        timerManager.setupTodoId = nil
        PopupWindow.activeInstance?.orderOut(nil)
        PopupWindow.activeInstance = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private func formatEndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TimerHistoryListView: View {
    @ObservedObject var historyStore = HistoryStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Focus History")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                if !historyStore.history.isEmpty {
                    Button(action: {
                        historyStore.clearHistory()
                    }) {
                        Text("Clear")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            if historyStore.history.isEmpty {
                Text("No sessions logged yet")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 5) {
                    ForEach(historyStore.history.prefix(5)) { session in
                        HStack {
                            Image(systemName: session.isPomodoro ? "flame.fill" : "timer")
                                .font(.system(size: 9))
                                .foregroundColor(session.isPomodoro ? .orange : .green)
                            
                            Text(session.name)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatDuration(session.duration))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(session.date))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct TimerTabView: View {
    @ObservedObject var timerManager = TimerManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if timerManager.isShowingSetup {
                TimerSetupView(timerManager: timerManager)
            } else {
                TodoListView()
                    .frame(maxHeight: 180)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.vertical, 2)
                
                ScrollView {
                    VStack(spacing: 12) {
                        if timerManager.activeTimers.isEmpty {
                            StopwatchControlView(timerManager: timerManager)
                        } else {
                            ForEach(timerManager.activeTimers) { timer in
                                TugTimerCard(timer: timer, timerManager: timerManager)
                            }
                        }
                        
                        TimerHistoryListView()
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 4)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct LargeEyeView: View {
    let mouseLocation: NSPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.85)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            
            Circle()
                .fill(Color.black)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 1.5, height: 1.5)
                        .offset(x: -1, y: -1)
                )
                .offset(pupilOffset())
        }
    }
    
    private func pupilOffset() -> CGSize {
        guard let window = PopupWindow.activeInstance else {
            return .zero
        }
        
        let windowFrame = window.frame
        let absoluteCenter = NSPoint(
            x: windowFrame.midX,
            y: windowFrame.midY
        )
        
        let dx = mouseLocation.x - absoluteCenter.x
        let dy = mouseLocation.y - absoluteCenter.y
        let distance = sqrt(dx*dx + dy*dy)
        
        guard distance > 0 else { return .zero }
        
        let maxOffset: CGFloat = 3.2
        let scale = min(distance / 250.0, 1.0) * maxOffset
        
        return CGSize(
            width: (dx / distance) * scale,
            height: -(dy / distance) * scale // Flip y-axis to match top-down layout coordinate space
        )
    }
}

fileprivate extension Color {
    static let emeraldGreen = Color(red: 0.05, green: 0.62, blue: 0.4)
}

// Clear Button with Hover State
struct ClearButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .foregroundColor(.red.opacity(isHovered ? 1.0 : 0.7))
                .padding(7)
                .background(Color.red.opacity(isHovered ? 0.15 : 0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(isHovered ? 0.25 : 0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// ==================== CLIPBOARD TAB ====================
struct ClipboardTabView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var searchQuery: String
    @State private var isSearchHovered = false
    
    var filteredItems: [ClipboardItem] {
        let baseItems: [ClipboardItem]
        if searchQuery.isEmpty {
            baseItems = clipboardManager.items
        } else {
            baseItems = clipboardManager.items.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
        }
        return baseItems.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned && !b.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Search & Clear Header
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search history...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(.subheadline, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(isSearchHovered ? 0.08 : 0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchHovered ? Color.white.opacity(0.16) : Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .onHover { hovering in
                    isSearchHovered = hovering
                }
                
                // Clear all
                ClearButton {
                    clipboardManager.clearAll()
                    HapticManager.shared.success()
                }
                .help("Clear History")
            }
            .padding(.horizontal, 14)
            
            // Clipboard List
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.bottom, 6)
                    Text("Clipboard is empty")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            ClipboardRow(item: item, searchQuery: searchQuery) {
                                clipboardManager.copyToPasteboard(item)
                            } onDelete: {
                                clipboardManager.deleteItem(item)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

extension String {
    func ranges(of searchString: String, options: CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var start = startIndex
        while start < endIndex,
              let range = range(of: searchString, options: options, range: start..<endIndex) {
            result.append(range)
            start = range.upperBound
        }
        return result
    }
}

struct ClipboardRow: View {
    let item: ClipboardItem
    let searchQuery: String
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    @State private var hoverWorkItem: DispatchWorkItem? = nil
    // No timer properties - kept static for minimal CPU footprint
    
    private var isTruncated: Bool {
        item.text.count > 38 || item.text.contains("\n") || item.text.contains("\r")
    }
    
    private var displayPreviewText: String {
        item.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var remainingSeconds: Int {
        guard let expiry = item.expiresAt else { return 0 }
        return max(0, Int(expiry.timeIntervalSince(Date())))
    }
    
    private func highlightedText(_ fullText: String, query: String) -> Text {
        guard !query.isEmpty else {
            return Text(fullText)
        }
        
        let ranges = fullText.ranges(of: query, options: .caseInsensitive)
        guard !ranges.isEmpty else {
            return Text(fullText)
        }
        
        var result = Text("")
        var currentIndex = fullText.startIndex
        
        for range in ranges {
            let preMatch = String(fullText[currentIndex..<range.lowerBound])
            result = result + Text(preMatch)
            
            let match = String(fullText[range])
            result = result + Text(match).bold().foregroundColor(Color(red: 0.15, green: 0.85, blue: 0.45))
            
            currentIndex = range.upperBound
        }
        
        let postMatch = String(fullText[currentIndex...])
        result = result + Text(postMatch)
        
        return result
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(.trailing, 2)
                    }
                    
                    highlightedText(displayPreviewText, query: searchQuery)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if item.isTemporary {
                    Button(action: {
                        ClipboardManager.shared.makePermanent(item)
                        HapticManager.shared.success()
                    }) {
                        Text("Stay")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(red: 0.15, green: 0.85, blue: 0.45))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                if isHovering {
                    HStack(spacing: 4) {
                        if isURL {
                            Button(action: {
                                shortenItemLink()
                            }) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                    .padding(5)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .help("Shorten Link")
                        }
                        
                        Button(action: {
                            ClipboardManager.shared.togglePin(item)
                            HapticManager.shared.click()
                        }) {
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(item.isPinned ? .orange : .green)
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin Item" : "Pin Item")
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                                .padding(5)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Item")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: isHovering ?
                                [Color.white.opacity(0.08), Color.white.opacity(0.02)] :
                                [Color.white.opacity(0.02), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isHovering ?
                            LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.white.opacity(0.05), Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: isHovering ? Color.black.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
            .scaleEffect(isHovering ? 1.015 : 1.0)
            .offset(y: isHovering ? -1 : 0)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
                
                hoverWorkItem?.cancel()
                
                if hovering {
                    guard isTruncated else { return }
                    
                    let workItem = DispatchWorkItem {
                        if isHovering {
                            let frame = geometry.frame(in: .global)
                            let midY = frame.midY
                            PopupWindow.activeInstance?.showPreview(for: item, atRowMidY: midY)
                        }
                    }
                    hoverWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
                } else {
                    hoverWorkItem = nil
                    PopupWindow.activeInstance?.hidePreview()
                }
            }
            .onTapGesture {
                onCopy()
                hoverWorkItem?.cancel()
                hoverWorkItem = nil
                PopupWindow.activeInstance?.hidePreview()
                PopupWindow.activeInstance?.orderOut(nil)
                PopupWindow.activeInstance = nil
            }
        }
        .frame(height: 34)
    }
    
    private var isURL: Bool {
        if let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url.scheme == "http" || url.scheme == "https"
        }
        return false
    }
    
    private func shortenItemLink() {
        let originalString = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tinyURLString = "https://tinyurl.com/api-create?url=\(originalString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let fetchURL = URL(string: tinyURLString) else { return }
        
        HapticManager.shared.click()
        
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
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// ==================== DROPZONE TAB ====================
struct DropzoneTabView: View {
    @ObservedObject var dropzoneManager = DropzoneManager.shared
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("FROG DROP")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(1.0)
                Spacer()
            }
            .frame(height: 16)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 10)
            
            // Compact drop zone — always visible at top
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isTargeted ? Color.green : Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: [4, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isTargeted ? Color.green.opacity(0.04) : Color.black.opacity(0.05))
                    )
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 12))
                        .foregroundColor(isTargeted ? .green : .secondary)
                    Text(isTargeted ? "Drop files here" : "Drag files here to store")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(isTargeted ? .green : .secondary)
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 0)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                var urls: [URL] = []
                let group = DispatchGroup()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url { urls.append(url) }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    if !urls.isEmpty { dropzoneManager.shelfFiles(urls) }
                }
                return true
            }
            
            // Scrollable grid — always shows shelf + folders + ACTIONS
            ScrollView {
                DropzoneGrid(isDraggingMode: false)
            }
        }
    }
}
