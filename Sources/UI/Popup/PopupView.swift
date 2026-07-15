import SwiftUI

struct PopupView: View {
    enum Tab {
        case timer
        case clipboard
        case dropzone
    }
    
    @AppStorage("uiDimOpacity") private var uiDimOpacity: Double = 0.0
    
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
    
    private func evaluateActiveTab() {
        if !timerManager.activeTimers.isEmpty {
            activeTab = .timer
        } else if let lastDrop = dropzoneManager.lastDropTime,
                  Date().timeIntervalSince(lastDrop) < 5 * 60,
                  !dropzoneManager.shelvedGroups.isEmpty {
            activeTab = .dropzone
        } else {
            activeTab = .clipboard
        }
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
                            MenuBarSettingsView()
                        }
                        
                        Text("FrogDrop • Premium 3-in-1")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    QuitButton()
                }
                .padding(12)
                .background(Color.clear)
            }
            .frame(width: 340, height: 460)
            .background(Color.black.opacity(uiDimOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
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
                        .fill(Color.white.opacity(0.04))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .coordinateSpace(name: "PopupWindowSpace")
        .onAppear {
            evaluateActiveTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .popupWillOpen)) { _ in
            evaluateActiveTab()
        }
        .onReceive(TimerManager.shared.$isShowingSetup) { showing in
            if showing {
                activeTab = .timer
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.closeAllPanels()
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
        .foregroundColor(isActive ? Color(red: 0.22, green: 0.72, blue: 0.42) : (isHovered ? .primary : .secondary))
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

// Preset Button with Hover State (unused, kept for safety)
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
