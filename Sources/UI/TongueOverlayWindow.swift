import SwiftUI
import AppKit

@MainActor
class TongueOverlayWindow: NSWindow {
    private let hostingView: NSHostingView<TongueOverlayView>
    
    init(statusItemFrame: NSRect, initialLength: CGFloat = 0.0) {
        let width: CGFloat = 100
        let height: CGFloat = 450
        // Position window directly under the menu bar item, centered
        let rect = NSRect(
            x: statusItemFrame.midX - (width / 2),
            y: statusItemFrame.minY - height + 2, // Slight overlap for continuous visual flow
            width: width,
            height: height
        )
        
        let overlayView = TongueOverlayView(tongueLength: initialLength)
        self.hostingView = NSHostingView(rootView: overlayView)
        
        super.init(
            contentRect: rect,
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
    
    func updateLength(_ length: CGFloat) {
        hostingView.rootView = TongueOverlayView(tongueLength: length)
    }
}

struct TongueOverlayView: View {
    let tongueLength: CGFloat
    
    var body: some View {
        let config = TimerDuration.fromDragDistance(tongueLength)
        
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background reference line (optional, but a guide is nice)
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 0))
                    path.addLine(to: CGPoint(x: 50, y: min(tongueLength, 400)))
                }
                .stroke(Color.black.opacity(0.08), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4]))
                
                // Tongue Stem
                if tongueLength > 10 {
                    Path { path in
                        path.move(to: CGPoint(x: 50, y: 0))
                        path.addLine(to: CGPoint(x: 50, y: tongueLength - 8))
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.8), Color.pink],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                }
                
                // Tongue Tip (pull handle)
                if tongueLength > 0 {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.pink.opacity(0.4), radius: 2, x: 0, y: 1)
                        .position(x: 50, y: tongueLength - 2)
                }
            }
            .frame(height: 400)
            
            // Timer Badge
            if tongueLength > 15 {
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
            }
            
            Spacer()
        }
        .frame(width: 100, height: 450)
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
        case .cancel: return "Cancel"
        case .min5: return "5m"
        case .min15: return "15m"
        case .min30: return "30m"
        case .hour1: return "1h"
        case .hour2: return "2h"
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
