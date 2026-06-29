import SwiftUI

struct MainSidebarView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case timer = "Focus Timer"
        case clipboard = "Clipboard"
        case dropzone = "Dropzone"
        case settings = "Settings"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .timer: return "timer"
            case .clipboard: return "paperclip"
            case .dropzone: return "square.and.arrow.down"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    @State private var activeTab: Tab = .dashboard
    @State private var isSidebarVisible: Bool = true
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @ObservedObject var dropzoneManager = DropzoneManager.shared
    
    @State private var clipboardSearchQuery = ""
    @Namespace private var sidebarNamespace
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main App Layout
            HStack(spacing: 0) {
                // Collapsible Sidebar
                if isSidebarVisible {
                    VStack(alignment: .leading, spacing: 16) {
                        // Logo text pushed down cleanly below the traffic lights and toggle button
                        HStack(spacing: 8) {
                            Image(systemName: "circle.grid.3x3.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.brandGreenEnd)
                            Text("FrogDrop")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 56) // Clean gap to avoid overlap with toggle button
                        
                        // Nav items
                        VStack(spacing: 6) {
                            ForEach(Tab.allCases) { tab in
                                SidebarButton(
                                    title: tab.rawValue,
                                    icon: tab.icon,
                                    isActive: activeTab == tab,
                                    namespace: sidebarNamespace
                                ) {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        activeTab = tab
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        
                        Spacer()
                        
                        // Active timer badge
                        if timerManager.state == .running, let _ = timerManager.getFirstActiveTimer() {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text(timerManager.getFormattedMenuBarTime())
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(width: 170)
                    .background(Color.brandDarkBg.opacity(0.4))
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Content View
                ZStack(alignment: .topLeading) {
                    switch activeTab {
                    case .dashboard:
                        DashboardView(activeTab: $activeTab)
                    case .timer:
                        TimerTabView()
                    case .clipboard:
                        ClipboardTabView(clipboardManager: clipboardManager, searchQuery: $clipboardSearchQuery)
                            .padding(16)
                    case .dropzone:
                        DropzoneTabView()
                            .padding(16)
                    case .settings:
                        AppSettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
            .edgesIgnoringSafeArea(.all)
            
            // Fixed Apple-style Sidebar Toggle Button (next to traffic lights)
            // It remains in the exact same spot regardless of sidebar open/close state!
            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isSidebarVisible.toggle()
                }
                HapticManager.shared.click()
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, isSidebarVisible ? 130 : 78)
            .padding(.top, 8)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20, alignment: .center)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(isActive ? .semibold : .medium)
                
                Spacer()
            }
            .foregroundColor(isActive ? Color.brandGreenEnd : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.055))
                            .matchedGeometryEffect(id: "activeTabPill", in: namespace)
                        
                        Capsule()
                            .fill(Color.brandGradient)
                            .frame(width: 3.5, height: 16)
                            .padding(.leading, 1)
                            .matchedGeometryEffect(id: "activeTabIndicator", in: namespace)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.02))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
