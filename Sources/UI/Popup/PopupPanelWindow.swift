import AppKit
import SwiftUI

class PopupPanelWindow: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.frame = container.bounds
        effectView.autoresizingMask = [.width, .height]
        
        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        
        container.addSubview(effectView)
        container.addSubview(contentView)
        self.contentView = container
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    func updatePosition(relativeTo buttonFrame: NSRect) {
        let width: CGFloat = 340
        let height: CGFloat = 460
        
        // Position directly below status item button, centered horizontally, with a 4pt gap
        let rect = NSRect(
            x: buttonFrame.midX - (width / 2),
            y: buttonFrame.minY - height - 4,
            width: width,
            height: height
        )
        self.setFrame(rect, display: true)
    }
}
