import SwiftUI
import AppKit

struct MenuBarFrogView: View {
    @ObservedObject var tracker = CursorTracker.shared
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            ZStack {
                // Frog Green Head
                Circle()
                    .fill(Color.green)
                    .frame(width: 18, height: 18)
                    .position(center)
                
                // Big Eyes Structure (Moved to top of face)
                HStack(spacing: 2) {
                    EyeView(mouseLocation: tracker.mouseLocation, eyeCenter: CGPoint(x: center.x - 3.5, y: center.y - 3.5))
                    EyeView(mouseLocation: tracker.mouseLocation, eyeCenter: CGPoint(x: center.x + 3.5, y: center.y - 3.5))
                }
                .position(x: center.x, y: center.y - 4.5)
                
                // Smile (Curving down, moved to bottom of face)
                Path { path in
                    path.move(to: CGPoint(x: center.x - 4, y: center.y + 1.5))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + 4, y: center.y + 1.5),
                        control: CGPoint(x: center.x, y: center.y + 3.5)
                    )
                }
                .stroke(Color.black, lineWidth: 1.2)
                
                // Pink tongue sticking out a tiny bit (chibi style, moved to bottom)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.pink)
                    .frame(width: 3, height: 4)
                    .position(x: center.x, y: center.y + 4.5)
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
                .fill(Color.white)
                .frame(width: 6.5, height: 6.5)
            
            Circle()
                .fill(Color.black)
                .frame(width: 3.2, height: 3.2)
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
