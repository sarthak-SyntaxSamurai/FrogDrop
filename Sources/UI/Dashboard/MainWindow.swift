import AppKit
import SwiftUI

class MainWindow: NSWindow {
    static var shared: MainWindow?
    private let windowDelegate = MainWindowDelegate()
    
    init() {
        let width: CGFloat = 800
        let height: CGFloat = 520
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(
            x: screenRect.midX - (width / 2),
            y: screenRect.midY - (height / 2),
            width: width,
            height: height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = "FrogDrop"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 720, height: 500)
        self.hasShadow = true
        self.delegate = windowDelegate
        
        let hostingView = NSHostingView(rootView: MainSidebarView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let contentView = NSView()
        self.contentView = contentView
        
        let effectView = NSVisualEffectView()
        effectView.material = .underWindowBackground
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        
        contentView.addSubview(effectView)
        contentView.addSubview(hostingView)
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

class MainWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false // Just hide, don't close/deallocate
    }
}
