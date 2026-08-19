import SwiftUI
import AppKit

@MainActor
class TongueOverlayWindow: NSWindow {
    private let hostingView: NSHostingView<TongueOverlayView>
    private let screenFrame: NSRect
    private let startPoint: NSPoint
    
    init(screenFrame: NSRect, startPoint: NSPoint, initialCurrentPoint: NSPoint) {
        self.screenFrame = screenFrame
        self.startPoint = startPoint
        
        let overlayView = TongueOverlayView(
            screenFrame: screenFrame,
            startPoint: startPoint,
            currentPoint: initialCurrentPoint
        )
        self.hostingView = NSHostingView(rootView: overlayView)
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.contentView = hostingView
    }
    
    func updatePoints(start: NSPoint, current: NSPoint) {
        hostingView.rootView = TongueOverlayView(
            screenFrame: screenFrame,
            startPoint: start,
            currentPoint: current
        )
    }
}

struct TongueOverlayView: View {
    let screenFrame: NSRect
    let startPoint: NSPoint
    let currentPoint: NSPoint
    
    // Screen coordinates to SwiftUI coordinates in a fullscreen window of size `screenFrame.size`
    private func toSwiftUI(_ point: NSPoint) -> CGPoint {
        CGPoint(
            x: point.x - screenFrame.minX,
            y: screenFrame.maxY - point.y
        )
    }
    
    var body: some View {
        let start = toSwiftUI(startPoint)
        let end = toSwiftUI(currentPoint)
        
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        
        let config = TimerDuration.fromDragDistance(distance)
        
        ZStack {
            // Full screen container to avoid cropping
            Canvas { context, size in
                // Draw tongue stem
                if distance > 10 {
                    var path = Path()
                    path.move(to: start)
                    // End point slightly short of the tip
                    let tipOffset = 8.0
                    let endX = start.x + (dx / distance) * (distance - tipOffset)
                    let endY = start.y + (dy / distance) * (distance - tipOffset)
                    path.addLine(to: CGPoint(x: endX, y: endY))
                    
                    let gradient = Gradient(colors: [Color(red: 1.0, green: 0.45, blue: 0.55), Color(red: 0.9, green: 0.25, blue: 0.35)])
                    let shader = GraphicsContext.Shading.linearGradient(
                        gradient,
                        startPoint: start,
                        endPoint: CGPoint(x: endX, y: endY)
                    )
                    
                    let progress = min(distance / 380.0, 1.0)
                    let dynamicWidth = 8.0 - (progress * 2.5)
                    
                    context.stroke(
                        path,
                        with: shader,
                        style: StrokeStyle(lineWidth: dynamicWidth, lineCap: .round)
                    )
                }
            }
            .ignoresSafeArea()
            
            // Cleft tongue tip (rotated and placed at the end point)
            if distance > 0 {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.65), Color(red: 0.9, green: 0.3, blue: 0.42)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 10
                            )
                        )
                        .frame(width: 12, height: 12)
                        .offset(x: -3.0)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 1.0, green: 0.55, blue: 0.65), Color(red: 0.9, green: 0.3, blue: 0.42)],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 10
                            )
                        )
                        .frame(width: 12, height: 12)
                        .offset(x: 3.0)
                }
                .frame(width: 19, height: 12)
                .shadow(color: Color.black.opacity(0.18), radius: 2.5, x: 0, y: 1.5)
                .rotationEffect(.radians(angle - .pi/2))
                .position(end)
            }
            
            // Timer Badge
            if distance > 15 {
                VStack(spacing: 2) {
                    Text(config.label)
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(config.seconds > 0 ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(config.seconds > 0 ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
                .transition(.scale.combined(with: .opacity))
                .position(x: end.x, y: end.y + 24)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }
}

// Timer Durations based on pull depth
enum TimerDuration: Int, CaseIterable {
    case cancel = 0
    case min5 = 1
    case min15 = 2
    case min30 = 3
    case hour1 = 4
    case hour2 = 5
    
    var threshold: CGFloat {
        switch self {
        case .cancel: return 0
        case .min5: return 40
        case .min15: return 120
        case .min30: return 200
        case .hour1: return 280
        case .hour2: return 360
        }
    }
    
    var label: String {
        switch self {
        case .cancel: return String(localized: "timer.duration.cancel", defaultValue: "Cancel", comment: "Label for cancelling timer selection in tongue overlay")
        case .min5: return String(localized: "timer.duration.minutes-5", defaultValue: "5m", comment: "Label for five-minute timer duration")
        case .min15: return String(localized: "timer.duration.minutes-15", defaultValue: "15m", comment: "Label for fifteen-minute timer duration")
        case .min30: return String(localized: "timer.duration.minutes-30", defaultValue: "30m", comment: "Label for thirty-minute timer duration")
        case .hour1: return String(localized: "timer.duration.hours-1", defaultValue: "1h", comment: "Label for one-hour timer duration")
        case .hour2: return String(localized: "timer.duration.hours-2", defaultValue: "2h", comment: "Label for two-hour timer duration")
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .cancel: return 0
        case .min5: return 5 * 60
        case .min15: return 15 * 60
        case .min30: return 30 * 60
        case .hour1: return 60 * 60
        case .hour2: return 120 * 60
        }
    }
    
    static func fromDragDistance(_ distance: CGFloat) -> TimerDuration {
        var selected = TimerDuration.cancel
        for item in TimerDuration.allCases {
            if distance >= item.threshold {
                selected = item
            }
        }
        return selected
    }
}

// macOS Visual Effect View for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

