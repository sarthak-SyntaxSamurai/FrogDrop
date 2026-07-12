import AppKit
import SwiftUI

class BoundsReadingView: NSView {
    var onBoundsUpdate: ((NSRect) -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBounds()
        
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
        if let window = window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }
    }
    
    @objc private func windowDidResize() {
        updateBounds()
    }
    
    private func updateBounds() {
        guard let window = window else { return }
        let bounds = window.contentView?.bounds ?? window.frame
        onBoundsUpdate?(bounds)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct WindowBoundsReader: NSViewRepresentable {
    @Binding var bounds: NSRect?
    
    func makeNSView(context: Context) -> BoundsReadingView {
        let view = BoundsReadingView()
        view.onBoundsUpdate = { newBounds in
            self.bounds = newBounds
        }
        return view
    }
    
    func updateNSView(_ nsView: BoundsReadingView, context: Context) {}
}

struct FrameRegistrationHelper: View {
    let key: String
    @State private var windowBounds: NSRect?
    
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .background(WindowBoundsReader(bounds: $windowBounds))
                .onAppear {
                    register(geo: geo)
                }
                .onChange(of: geo.frame(in: .global)) {
                    register(geo: geo)
                }
                .onChange(of: windowBounds) {
                    register(geo: geo)
                }
        }
    }
    
    private func register(geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let nsRect = NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
        
        // Use actual window content height for accurate coordinate conversion
        let contentHeight = windowBounds?.height ?? 380
        
        let appKitRect = NSRect(
            x: nsRect.origin.x,
            y: contentHeight - nsRect.origin.y - nsRect.size.height,
            width: nsRect.size.width,
            height: nsRect.size.height
        )
        
        DispatchQueue.main.async {
            DropzoneManager.shared.registerFrame(appKitRect, for: key)
        }
    }
}

class DropzonePanelContentView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point) {
            return hit
        }
        return self
    }
}

class DropzoneHostingView<Content: View>: NSHostingView<Content> {
}

struct CollapsedPanelView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.green)
            Text("DROP")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(0.5)
        }
        .frame(width: 70, height: 20)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.22, green: 0.72, blue: 0.42).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: Color(red: 0.22, green: 0.72, blue: 0.42).opacity(0.2), radius: 3)
        .frame(width: 80, height: 28)
    }
}
