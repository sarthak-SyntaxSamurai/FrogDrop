import AppKit
import SwiftUI

struct ClipboardPreviewView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .regular))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(minWidth: 150, maxWidth: 280, alignment: .topLeading)
    }
}

class ClipboardPreviewWindow: NSWindow {
    let hostingView: NSHostingView<ClipboardPreviewView>
    
    init(text: String) {
        let view = NSHostingView(rootView: ClipboardPreviewView(text: text))
        self.hostingView = view
        
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .floating
        self.ignoresMouseEvents = true
        
        let nsView = NSView()
        nsView.wantsLayer = true
        
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        
        self.contentView = nsView
        nsView.addSubview(effectView)
        nsView.addSubview(view)
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: nsView.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor),
            
            view.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
            view.topAnchor.constraint(equalTo: nsView.topAnchor),
            view.bottomAnchor.constraint(equalTo: nsView.bottomAnchor)
        ])
    }
}

@MainActor
class ClipboardPreviewManager {
    static let shared = ClipboardPreviewManager()
    
    private var previewWindow: ClipboardPreviewWindow?
    
    func showPreview(for item: ClipboardItem, atRowFrame frame: CGRect) {
        guard let delegate = NSApp.delegate as? AppDelegate,
              let popoverWindow = delegate.activePopupWindow else {
            return
        }
        
        if let oldWindow = previewWindow {
            popoverWindow.removeChildWindow(oldWindow)
            oldWindow.orderOut(nil)
        }
        
        let preview = ClipboardPreviewWindow(text: item.text)
        self.previewWindow = preview
        
        let hostingView = preview.hostingView
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        
        let width = min(max(fittingSize.width, 150), 280)
        let height = min(max(fittingSize.height, 20), 400)
        
        let windowFrame = popoverWindow.frame
        let screenX = windowFrame.minX - width - 8
        let rowCenterY = windowFrame.maxY - frame.minY - (frame.height / 2)
        let screenY = rowCenterY - (height / 2)
        
        let rect = NSRect(x: screenX, y: screenY, width: width, height: height)
        preview.setFrame(rect, display: true, animate: false)
        
        popoverWindow.addChildWindow(preview, ordered: .above)
    }
    
    func hidePreview() {
        if let preview = previewWindow {
            if let delegate = NSApp.delegate as? AppDelegate,
               let popoverWindow = delegate.activePopupWindow {
                popoverWindow.removeChildWindow(preview)
            }
            preview.orderOut(nil)
            previewWindow = nil
        }
    }
}
