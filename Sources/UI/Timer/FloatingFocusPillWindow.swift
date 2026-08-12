import SwiftUI
import AppKit

@MainActor
final class FloatingFocusPillManager: ObservableObject {
    static let shared = FloatingFocusPillManager()
    
    @Published var isVisible = false
    private var window: FloatingFocusPillPanel?
    
    private init() {}
    
    func show() {
        if window == nil {
            let panel = FloatingFocusPillPanel()
            let hosting = NSHostingView(rootView: FloatingFocusPillView())
            panel.contentView = hosting
            self.window = panel
        }
        
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 240
            let y = screenRect.maxY - 70
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        window?.orderFrontRegardless()
        isVisible = true
    }
    
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
}

final class FloatingFocusPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.animationBehavior = .utilityWindow
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct FloatingFocusPillView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @ObservedObject var pillManager = FloatingFocusPillManager.shared
    @State private var isHovered = false
    
    var activeTimer: TimerManager.ActiveTimer? {
        timerManager.activeTimers.first
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Frog Focus Avatar
            ZStack {
                Circle()
                    .fill(activeTimer?.isBreakActive == true ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Text(activeTimer?.isBreakActive == true ? "☕" : "🐸")
                    .font(.system(size: 16))
            }
            
            // Timer details
            VStack(alignment: .leading, spacing: 1) {
                if let timer = activeTimer {
                    Text(formatTime(timer.isStopwatch ? timer.secondsElapsed : timer.secondsRemaining))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(timer.name.isEmpty ? "Focusing" : timer.name)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text("Ready to Focus")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons on hover
            if let timer = activeTimer {
                HStack(spacing: 4) {
                    Button(action: {
                        timerManager.togglePause(timerId: timer.id)
                        HapticManager.shared.click()
                    }) {
                        Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        timerManager.stopTimer(timerId: timer.id)
                        HapticManager.shared.click()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.red.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: {
                    pillManager.hide()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 220, height: 44)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.1, green: 0.12, blue: 0.14).opacity(0.85))
                
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: [
                                activeTimer?.isBreakActive == true ? Color.orange.opacity(0.5) : Color.green.opacity(0.5),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
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
