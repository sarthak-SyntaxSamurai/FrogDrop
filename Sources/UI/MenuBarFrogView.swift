import SwiftUI
import AppKit

struct MenuBarFrogView: View {
    @ObservedObject var tracker = CursorTracker.shared
    @ObservedObject var timerManager = TimerManager.shared
    @State private var isBlinking = false
    
    @AppStorage("menuBarIconStyle") var menuBarIconStyle: String = "frog"
    @AppStorage("menuBarCustomImagePath") var menuBarCustomImagePath: String = ""
    
    // Tug Brand Colors
    private let frogGreen = Color(red: 14/255, green: 127/255, blue: 69/255) // #0E7F45
    private let tonguePink = Color(red: 250/255, green: 103/255, blue: 146/255) // #FA6792
    private let eyebrowColor = Color(red: 10/255, green: 90/255, blue: 45/255) // Darker green #0A5A2D
    
    private var isFocusMode: Bool {
        if let timer = timerManager.getFirstActiveTimer() {
            return timer.state == .running && !timer.isBreakActive
        }
        return false
    }
    
    private var isBreakMode: Bool {
        if let timer = timerManager.getFirstActiveTimer() {
            return timer.state == .running && timer.isBreakActive
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                if menuBarIconStyle == "minimal" {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                } else if menuBarIconStyle == "custom" {
                    if !menuBarCustomImagePath.isEmpty, let nsImage = NSImage(contentsOfFile: menuBarCustomImagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                } else {
                    // Wide Head Body (Ellipse for perfect Tug style round/chubby head)
                    Ellipse()
                        .fill(frogGreen)
                        .frame(width: 19, height: 15)
                        .position(x: 12, y: 12 + 2.0)
                    
                    // Left Eyebrow
                Path { path in
                    if isFocusMode {
                        path.move(to: CGPoint(x: 12 - 6.0, y: 12 - 9.8))
                        path.addLine(to: CGPoint(x: 12 - 1.0, y: 12 - 8.0))
                    } else {
                        path.move(to: CGPoint(x: 12 - 6.5, y: 12 - 9.0))
                        path.addQuadCurve(to: CGPoint(x: 12 - 1.0, y: 12 - 9.0), control: CGPoint(x: 12 - 3.75, y: 12 - 10.8))
                    }
                }
                .stroke(eyebrowColor, lineWidth: 1.2)
                
                // Right Eyebrow
                Path { path in
                    if isFocusMode {
                        path.move(to: CGPoint(x: 12 + 1.0, y: 12 - 8.0))
                        path.addLine(to: CGPoint(x: 12 + 6.0, y: 12 - 9.8))
                    } else {
                        path.move(to: CGPoint(x: 12 + 1.0, y: 12 - 9.0))
                        path.addQuadCurve(to: CGPoint(x: 12 + 6.5, y: 12 - 9.0), control: CGPoint(x: 12 + 3.75, y: 12 - 10.8))
                    }
                }
                .stroke(eyebrowColor, lineWidth: 1.2)
                
                // Left Eye (drawn first, under the right eye)
                EyeView(
                    mouseLocation: tracker.mouseLocation,
                    eyeCenter: CGPoint(x: 12 - 3.4, y: 12 - 4.5),
                    isClosed: isBlinking,
                    eyeSize: 8.5
                )
                .position(x: 12 - 3.4, y: 12 - 4.5)
                
                // Right Eye (drawn second, on top of the left eye for 2.5D overlap)
                EyeView(
                    mouseLocation: tracker.mouseLocation,
                    eyeCenter: CGPoint(x: 12 + 3.4, y: 12 - 4.5),
                    isClosed: isBlinking,
                    eyeSize: 8.5
                )
                .position(x: 12 + 3.4, y: 12 - 4.5)
                
                // Focus Mode Red Headband
                if isFocusMode {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 17, height: 2.2)
                        .position(x: 12, y: 12 - 7.2)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 12 - 8.5, y: 12 - 7.2))
                        path.addLine(to: CGPoint(x: 12 - 11.5, y: 12 - 5.5))
                        path.move(to: CGPoint(x: 12 - 8.5, y: 12 - 7.2))
                        path.addLine(to: CGPoint(x: 12 - 10.5, y: 12 - 9.0))
                    }
                    .stroke(Color.red, lineWidth: 1.5)
                }
                
                // Break Mode Cool Sunglasses
                if isBreakMode {
                    // Left Lens
                    Circle()
                        .fill(Color.black)
                        .frame(width: 9.5, height: 9.5)
                        .position(x: 12 - 3.4, y: 12 - 4.5)
                    
                    // Right Lens
                    Circle()
                        .fill(Color.black)
                        .frame(width: 9.5, height: 9.5)
                        .position(x: 12 + 3.4, y: 12 - 4.5)
                    
                    // Sunglasses Bridge
                    Path { path in
                        path.move(to: CGPoint(x: 12 - 3.4, y: 12 - 5.5))
                        path.addQuadCurve(to: CGPoint(x: 12 + 3.4, y: 12 - 5.5), control: CGPoint(x: 12, y: 12 - 6.5))
                    }
                    .stroke(Color.black, lineWidth: 1.5)
                    
                    // Glossy highlights
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2.0, height: 2.0)
                        .position(x: 12 - 4.5, y: 12 - 5.5)
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 2.0, height: 2.0)
                        .position(x: 12 + 2.3, y: 12 - 5.5)
                }
                
                // Smile Mouth
                Path { path in
                    path.move(to: CGPoint(x: 12 - 5.0, y: 12 + 2.5))
                    path.addQuadCurve(
                        to: CGPoint(x: 12 + 5.0, y: 12 + 2.5),
                        control: CGPoint(x: 12, y: 12 + 5.2)
                    )
                }
                .stroke(Color.black, lineWidth: 1.2)
                
                    // Pink tongue sticking out a tiny bit (Chibi cleft style)
                    ZStack {
                        Capsule()
                            .fill(tonguePink)
                            .frame(width: 1.2, height: 3.2)
                            .offset(x: -0.5)
                        Capsule()
                            .fill(tonguePink)
                            .frame(width: 1.2, height: 3.2)
                            .offset(x: 0.5)
                    }
                    .frame(width: 3.0, height: 3.0)
                    .position(x: 12, y: 12 + 4.2)
                }
            }
            .frame(width: 24, height: 24)
            
            let activeTime = timerManager.getFormattedMenuBarTime()
            if !activeTime.isEmpty {
                Text(activeTime)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(timerManager.getFirstActiveTimer()?.isBreakActive == true ? .orange : .primary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 2)
        .onAppear {
            if menuBarIconStyle == "frog" { scheduleBlink() }
        }
        .onChange(of: menuBarIconStyle) { _, newStyle in
            if newStyle == "frog" { scheduleBlink() }
        }
    }
    
    private func scheduleBlink() {
        let delay = Double.random(in: 8.0...18.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
                scheduleBlink()
            }
        }
    }
}

struct EyeView: View {
    let mouseLocation: NSPoint
    let eyeCenter: CGPoint
    let isClosed: Bool
    let eyeSize: CGFloat
    
    var body: some View {
        ZStack {
            if isClosed {
                // Closed eye curved line
                Path { path in
                    path.move(to: CGPoint(x: 1.0, y: eyeSize * 0.5))
                    path.addQuadCurve(
                        to: CGPoint(x: eyeSize - 1.0, y: eyeSize * 0.5),
                        control: CGPoint(x: eyeSize * 0.5, y: eyeSize * 0.8)
                    )
                }
                .stroke(Color.black, lineWidth: 1.5)
                .frame(width: eyeSize, height: eyeSize)
            } else {
                // Open tracking eye with clean black border
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(white: 0.9)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: eyeSize * 0.6
                        )
                    )
                    .frame(width: eyeSize, height: eyeSize)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 0.8)
                    )
                
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeSize * 0.48, height: eyeSize * 0.48)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: eyeSize * 0.12, height: eyeSize * 0.12)
                            .offset(x: -eyeSize * 0.08, y: -eyeSize * 0.08)
                    )
                    .offset(pupilOffset())
            }
        }
        .frame(width: eyeSize, height: eyeSize)
    }
    
    private func pupilOffset() -> CGSize {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
              let statusItem = appDelegate.statusItem,
              let window = statusItem.button?.window else {
            return .zero
        }
        
        let windowFrame = window.frame
        let eyeScreenPosition = NSPoint(
            x: windowFrame.minX + eyeCenter.x,
            y: windowFrame.minY + (windowFrame.height - eyeCenter.y)
        )
        
        let dx = mouseLocation.x - eyeScreenPosition.x
        let dy = mouseLocation.y - eyeScreenPosition.y
        let distance = sqrt(dx*dx + dy*dy)
        
        guard distance > 0 else { return .zero }
        
        let maxOffset: CGFloat = eyeSize * 0.22
        let scale = min(distance / 200.0, 1.0) * maxOffset
        
        return CGSize(
            width: (dx / distance) * scale,
            height: -(dy / distance) * scale
        )
    }
}
