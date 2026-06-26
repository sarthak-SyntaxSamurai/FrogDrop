import SwiftUI
import AppKit

struct MenuBarFrogView: View {
    @ObservedObject var tracker = CursorTracker.shared
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            ZStack {
                // Left Eye Socket Bump
                Circle()
                    .fill(Color.green)
                    .frame(width: 7.5, height: 7.5)
                    .position(x: center.x - 3.5, y: center.y - 3.5)
                
                // Right Eye Socket Bump
                Circle()
                    .fill(Color.green)
                    .frame(width: 7.5, height: 7.5)
                    .position(x: center.x + 3.5, y: center.y - 3.5)
                
                // Wide Head Body (Ellipse instead of Circle for a real frog head shape!)
                Ellipse()
                    .fill(Color.green)
                    .frame(width: 18, height: 12)
                    .position(x: center.x, y: center.y + 1.5)
                
                // Big Eyes Structure (Moved to top of face)
                HStack(spacing: 1.0) {
                    EyeView(mouseLocation: tracker.mouseLocation, eyeCenter: CGPoint(x: center.x - 3.5, y: center.y - 3.5))
                    EyeView(mouseLocation: tracker.mouseLocation, eyeCenter: CGPoint(x: center.x + 3.5, y: center.y - 3.5))
                }
                .position(x: center.x, y: center.y - 3.5)
                
                // Smile (Curving down, moved to bottom of face)
                Path { path in
                    path.move(to: CGPoint(x: center.x - 4, y: center.y + 1.2))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + 4, y: center.y + 1.2),
                        control: CGPoint(x: center.x, y: center.y + 3.2)
                    )
                }
                .stroke(Color.black, lineWidth: 1.2)
                
                // Pink tongue sticking out a tiny bit (Chibi cleft style)
                ZStack {
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.55))
                        .frame(width: 1.5, height: 3.5)
                        .offset(x: -0.6)
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.55))
                        .frame(width: 1.5, height: 3.5)
                        .offset(x: 0.6)
                }
                .frame(width: 3.5, height: 3.5)
                .position(x: center.x, y: center.y + 4.2)
            }
        }
    }
}

struct EyeView: View {
    let mouseLocation: NSPoint
    let eyeCenter: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.9)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 6.5, height: 6.5)
            
            Circle()
                .fill(Color.black)
                .frame(width: 3.2, height: 3.2)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 0.8, height: 0.8)
                        .offset(x: -0.6, y: -0.6)
                )
                .offset(pupilOffset())
        }
    }
    
    private func pupilOffset() -> CGSize {
        // Retrieve the status item window frame to compute screen-space offsets
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
              let statusItem = appDelegate.statusItem,
              let window = statusItem.button?.window else {
            return .zero
        }
        
        let windowFrame = window.frame
        let eyeScreenPosition = NSPoint(
            x: windowFrame.minX + eyeCenter.x,
            y: windowFrame.minY + (windowFrame.height - eyeCenter.y) // Adjust for SwiftUI's top-down space
        )
        
        let dx = mouseLocation.x - eyeScreenPosition.x
        let dy = mouseLocation.y - eyeScreenPosition.y
        let distance = sqrt(dx*dx + dy*dy)
        
        guard distance > 0 else { return .zero }
        
        // Dynamic pupil tracking scaling
        let maxOffset: CGFloat = 1.6
        let scale = min(distance / 200.0, 1.0) * maxOffset
        
        return CGSize(
            width: (dx / distance) * scale,
            height: -(dy / distance) * scale // Flip y-axis to match SwiftUI's top-down layout coordinate space
        )
    }
}
