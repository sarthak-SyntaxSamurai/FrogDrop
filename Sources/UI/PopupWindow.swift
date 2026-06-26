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
                .foregroundColor(.secondary)
                .opacity(0.8)
                
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
    
    init(statusItemFrame: NSRect) {
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

        let hostingView = NSHostingView(rootView: PopupView())
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
    
    func windowDidResignKey(_ notification: Notification) {
        hidePreview()
        self.orderOut(nil)
        if PopupWindow.activeInstance == self {
            PopupWindow.activeInstance = nil
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
        } else {
            let preview = ClipboardPreviewWindow(contentRect: rect, text: item.text)
            previewWindow = preview
            self.addChildWindow(preview, ordered: .above)
        }
    }
    
    func hidePreview() {
        if let preview = previewWindow {
            self.removeChildWindow(preview)
            preview.orderOut(nil)
            previewWindow = nil
        }
    }
}

fileprivate extension View {
    func wantsLayer(_ wants: Bool) -> some View { self }
    func cornerRadius(_ radius: CGFloat) -> some View { self }
}

struct PopupView: View {
    enum Tab {
        case timer
        case clipboard
        case dropzone
    }
    
    @State private var activeTab: Tab = TimerManager.shared.state != .idle ? .timer : .clipboard
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var dropzoneManager = DropzoneManager.shared
    
    // Clipboard Search
    @State private var clipboardSearchQuery = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Tab Bar
            HStack(spacing: 0) {
                TabButton(title: "Timer", icon: "timer", isActive: activeTab == .timer) {
                    activeTab = .timer
                }
                TabButton(title: "Clipboard", icon: "paperclip", isActive: activeTab == .clipboard) {
                    activeTab = .clipboard
                }
                TabButton(title: "Dropzone", icon: "square.and.arrow.down", isActive: activeTab == .dropzone) {
                    activeTab = .dropzone
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            
            // Tab Contents
            Group {
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
            
            // Footer Info
            HStack {
                Text("FrogDrop • Premium 3-in-1")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.black.opacity(0.12))
        }
        .frame(width: 340, height: 460)
        .onChange(of: activeTab) {
            PopupWindow.activeInstance?.hidePreview()
        }
    }
}

// Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(isActive ? .green : (isHovered ? .primary : .secondary))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.click()
            action()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// ==================== TIMER TAB ====================
struct TimerTabView: View {
    @ObservedObject var timerManager: TimerManager
    @ObservedObject var tracker = CursorTracker.shared
    
    let presets: [TimeInterval] = [
        5 * 60,
        15 * 60,
        30 * 60,
        60 * 60,
        120 * 60
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Interactive Frog Face Centerpiece
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 110, height: 110)
                
                // Outer Timer Ring
                if timerManager.state != .idle {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timerManager.secondsRemaining / max(timerManager.totalSeconds, 1)))
                        .stroke(
                            AngularGradient(
                                colors: [.green, .emeraldGreen, .green],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timerManager.secondsRemaining)
                }
                
                // Frog Head with Tracking Eyes
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 60, height: 60)
                    
                    // Large Eyes (Moved to top of face)
                    HStack(spacing: 6) {
                        LargeEyeView(mouseLocation: tracker.mouseLocation)
                        LargeEyeView(mouseLocation: tracker.mouseLocation)
                    }
                    .position(x: 30, y: 22)
                    
                    // Cute blushing cheeks (Moved below eyes)
                    Circle()
                        .fill(Color.pink.opacity(0.4))
                        .frame(width: 6, height: 4)
                        .position(x: 14, y: 34)
                    Circle()
                        .fill(Color.pink.opacity(0.4))
                        .frame(width: 6, height: 4)
                        .position(x: 46, y: 34)
                    
                    // Smiling mouth (Curving down, moved to bottom of face)
                    Path { path in
                        path.move(to: CGPoint(x: 21, y: 38))
                        path.addQuadCurve(
                            to: CGPoint(x: 39, y: 38),
                            control: CGPoint(x: 30, y: 46)
                        )
                    }
                    .stroke(Color.black, lineWidth: 1.5)
                }
                .frame(width: 60, height: 60)
            }
            .frame(height: 120)
            
            // Timer Display or Presets
            if timerManager.state != .idle {
                VStack(spacing: 8) {
                    Text(formatTime(timerManager.secondsRemaining))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            timerManager.togglePause()
                        }) {
                            Text(timerManager.state == .running ? "Pause" : "Resume")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            timerManager.stopTimer()
                        }) {
                            Text("Cancel")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Text("Select Preset or Drag Tongue Down")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    // Preset buttons
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { seconds in
                            Button(action: {
                                timerManager.startTimer(duration: seconds)
                            }) {
                                Text("\(Int(seconds / 60))m")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
}

struct LargeEyeView: View {
    let mouseLocation: NSPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            Circle()
                .fill(Color.black)
                .frame(width: 7, height: 7)
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

// ==================== CLIPBOARD TAB ====================
struct ClipboardTabView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Binding var searchQuery: String
    
    var filteredItems: [ClipboardItem] {
        if searchQuery.isEmpty {
            return clipboardManager.items
        } else {
            return clipboardManager.items.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
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
                .background(Color.black.opacity(0.12))
                .cornerRadius(8)
                
                // Clear all
                Button(action: {
                    clipboardManager.clearAll()
                    HapticManager.shared.success()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(7)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
                            ClipboardRow(item: item) {
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

struct ClipboardRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false
    
    private var displayPreviewText: String {
        item.text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayPreviewText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatTimestamp(item.timestamp))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
                if hovering {
                    let frame = geometry.frame(in: .global)
                    let midY = frame.midY
                    PopupWindow.activeInstance?.showPreview(for: item, atRowMidY: midY)
                } else {
                    PopupWindow.activeInstance?.hidePreview()
                }
            }
            .onTapGesture {
                onCopy()
                PopupWindow.activeInstance?.hidePreview()
                PopupWindow.activeInstance?.orderOut(nil)
                PopupWindow.activeInstance = nil
            }
        }
        .frame(height: 50)
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
        VStack(spacing: 12) {
            // Drop target slot
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isTargeted ? Color.green : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [4, 4])
                        )
                        .background(isTargeted ? Color.green.opacity(0.05) : Color.black.opacity(0.08))
                        .cornerRadius(12)
                    
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 24))
                            .foregroundColor(isTargeted ? .green : .secondary)
                        
                        Text("Drag files here to store")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(isTargeted ? .green : .primary)
                        
                        if !dropzoneManager.shelvedFiles.isEmpty {
                            Text("\(dropzoneManager.shelvedFiles.count) shelved files")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(height: 110)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    // Retrieve URL representation from providers
                    let fileURLType = UTType.fileURL.identifier
                    for provider in providers {
                        if provider.hasItemConformingToTypeIdentifier(fileURLType) {
                            _ = provider.loadObject(ofClass: URL.self) { url, error in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        dropzoneManager.shelfFiles([url])
                                    }
                                }
                            }
                        }
                    }
                    return true
                }
            }
            .padding(.horizontal, 14)
            
            // Shelved items list (if any) or Actions list
            if !dropzoneManager.shelvedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Shelved Files")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            dropzoneManager.shelvedFiles.removeAll()
                            HapticManager.shared.click()
                        }) {
                            Text("Clear")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(dropzoneManager.shelvedFiles, id: \.self) { url in
                                ShelvedFileRow(url: url) {
                                    // Remove file
                                    dropzoneManager.shelvedFiles.removeAll { $0 == url }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            } else {
                // Dropzone Actions Grid
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actions Grid")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ActionCard(title: "Downloads", subtitle: "Move items to Downloads", icon: "folder")
                        ActionCard(title: "AirDrop", subtitle: "Share files quickly", icon: "airplayaudio")
                        ActionCard(title: "Copy Path", subtitle: "Copy raw path string", icon: "doc.on.doc")
                        ActionCard(title: "Drop Bar", subtitle: "Saves to temp bar", icon: "square.and.arrow.down")
                    }
                    .padding(.horizontal, 14)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct ShelvedFileRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 16, height: 16)
            
            Text(url.lastPathComponent)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(isHovering ? 0.08 : 0.03))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onDrag {
            // Drag out of Dropzone to move elsewhere!
            return NSItemProvider(object: url as NSURL)
        }
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                Spacer()
            }
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}
